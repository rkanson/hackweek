require 'fileutils'
require 'yaml'

class String
  def green;
    "\e[32m#{self}\e[0m"
  end
end

def cleanup
  if File.exists?("tmp")
    FileUtils.remove_dir("tmp")
  end
end

puts "What type of site are you trying to deploy?".green
supported = [
  "0: Gatsby JS",
  "1: NextJS",
  "2: Hugo",
]
supported.each do |tool|
  puts tool.green
end
template = gets.chomp
recipe = "./recipes"

case template
when "0"
  puts "Selected GatsbyJS".green
  recipe += "/node/gatsby/gatsby.yaml"
  copyCmd = "cp ./recipes/node/gatsby/* ./tmp"
  PORT = 80
when "1"
  puts "Selected NextJS".green
  recipe += "/node/next/next.yaml"
  copyCmd = "cp ./recipes/node/next/* ./tmp"
  PORT = 3000
when "2"
  puts "Selected Hugo".green
  recipe += "/go/hugo/hugo.yaml"
  copyCmd = "cp ./recipes/go/hugo/* ./tmp"
  PORT = 1313
else
  abort("Please enter a number from the provided list to select your framework.").green
end

puts "Please enter the GitHub URL for the repo.".green
repo = gets.chomp
repo += ".git" unless repo.end_with?(".git")

cleanup()

system "git clone #{repo} ./tmp"
system copyCmd

yaml = YAML.load_file(recipe)
PROJECT_NAME = yaml["PROJECT_NAME"]
RUN_COMMAND = yaml["RUN_COMMAND"]
PORTS = yaml["PORTS"]

# puts "Combining Docker files".green
# system "cat $(find . -type f -name Dockerfile) > Dockerfile"

puts "Starting Docker build...".green
rmCmd = %Q[docker rm -f #{PROJECT_NAME} || true]
buildCmd = %Q[docker build -t #{PROJECT_NAME} ./tmp  --build-arg RUNCOMMAND="#{RUN_COMMAND}"]
# buildCmd = %Q[docker build -t #{PROJECT_NAME} . --build-arg RUNCOMMAND="#{RUN_COMMAND}"]
runCmd = %Q[docker run --name #{PROJECT_NAME} -p #{PORTS} -d #{PROJECT_NAME}]
if defined? rmCmd
    finalCmd = "#{rmCmd} && #{buildCmd} && #{runCmd}"
else
    finalCmd = "#{buildCmd} && #{runCmd}"
end
system finalCmd

puts "Docker build completed -- push to Quay/Kubernetes? (y/n)".green
continue = gets.chomp

if continue != "y"
  cleanup()
  abort("Stopping here.").green
end

puts "Committing to quay.io".green
dockCommit = %Q[docker commit $(docker ps -aqf "name=#{PROJECT_NAME}") quay.io/rkanson/#{PROJECT_NAME}]
dockPush = %Q[docker push quay.io/rkanson/#{PROJECT_NAME}]
# dockCommit = %Q[docker commit $(docker ps -aqf "name=hackweek") quay.io/rkanson/hackweek]
# dockPush = %Q[docker push quay.io/rkanson/hackweek]
dockFinal = "#{dockCommit} && #{dockPush}"
system dockFinal

puts "Quay.io build updated - deploying to Kubernetes".green
PROJECT_PORTS = {
    "protocol" => "TCP", 
    "containerPort" => PORT
}
HACKWEEK_DEPLOY = {
    "apiVersion" => "apps/v1",
    "kind" => "Deployment",
    "metadata" => {
        "labels" => {
            "app" => PROJECT_NAME,
        },
        "name" => PROJECT_NAME,
    },
    "spec" => {
        "replicas" => 1, 
        "selector" => {
            "matchLabels" => {
                "app" => PROJECT_NAME,
            },
        },  
        "strategy" => {
            "rollingUpdate" => {
                "maxSurge" => 1, 
                "maxUnavailable" => 1,
            }, 
            "type" => "RollingUpdate",
        },
        "template" => {
            "metadata" => {
                "creationTimestamp" => nil,
                "labels" => {
                    "app" => PROJECT_NAME,
                }, 
            },
            "spec" => {
                "containers" => [
                    {
                        "image" => "quay.io/rkanson/#{PROJECT_NAME}:latest",
                        "imagePullPolicy" => "Always",
                        "name" => PROJECT_NAME,
                        "ports" => [
                            "containerPort" => PORT,
                            "protocol" => "TCP",
                        ],
                    },
                ],
                "restartPolicy" => "Always",
            },
        },
    },
}
HACKWEEK_SERVICE = {
    "apiVersion" => "v1",
    "kind" => "Service",
    "metadata" => {
        "labels" => {
            "app" => PROJECT_NAME,
        },
        "name" => PROJECT_NAME,
    },
    "spec" => {
        "type" => "LoadBalancer", 
        "ports" => [
            {
                "targetPort" => PORT, 
                "port" => 80
            }
        ], 
        "selector" => {
            "app" => PROJECT_NAME
        }
    }
}
f = File.new("hackweek-deploy.yaml", "w+")
f.write(HACKWEEK_DEPLOY.to_yaml)
f.close
f = File.new("hackweek-service.yaml", "w+")
f.write(HACKWEEK_SERVICE.to_yaml)
f.close
kubeDeploy = %Q[kubectl apply -f hackweek-deploy.yaml]
kubeService = %Q[kubectl apply -f hackweek-service.yaml]
kubeCmd = "#{kubeDeploy} && #{kubeService}"
system kubeCmd

File.delete("hackweek-deploy.yaml") if File.exists? "hackweek-deploy.yaml"
File.delete("hackweek-service.yaml") if File.exists? "hackweek-service.yaml"

puts "Restarting pod to deploy latest changes...".green

podName = %Q[kubectl get pods --no-headers -o custom-columns=":metadata.name" | grep '#{PROJECT_NAME}']
if podName.length > 1
  kubeRestart = %Q[kubectl delete pod $(#{podName})]
  system kubeRestart
end

puts "Cleaning up ./tmp folder...".green
cleanup

puts "Your project should be live shortly at http://#{PROJECT_NAME}.sandbox-rkanson.sbx04.pantheon.io".green
