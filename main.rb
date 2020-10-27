require 'yaml'

if ARGV[0].to_s.include?(".yaml")
    yaml = YAML.load_file("./recipes/" + ARGV[0].to_s)
    PROJECT_NAME = yaml["PROJECT_NAME"]
    DOCKER_PATH = yaml["DOCKER_PATH"]
    RUN_COMMAND = yaml["RUN_COMMAND"]
    PORTS = yaml["PORTS"]

    # puts "Combining Docker files"
    # system "cat $(find . -type f -name Dockerfile) > Dockerfile"

    puts "Starting Docker build..."
    rmCmd = %Q[docker rm -f #{PROJECT_NAME} || true]
    buildCmd = %Q[docker build -t #{PROJECT_NAME} #{DOCKER_PATH} --build-arg RUNCOMMAND="#{RUN_COMMAND}"]
    # buildCmd = %Q[docker build -t #{PROJECT_NAME} . --build-arg RUNCOMMAND="#{RUN_COMMAND}"]
    runCmd = %Q[docker run --name #{PROJECT_NAME} -p #{PORTS} -d #{PROJECT_NAME}]
    if defined? rmCmd
        finalCmd = "#{rmCmd} && #{buildCmd} && #{runCmd}"
    else
        finalCmd = "#{buildCmd} && #{runCmd}"
    end
    system finalCmd

    puts "Docker build success - committing to quay.io"
    dockCommit = %Q[docker commit $(docker ps -aqf "name=#{PROJECT_NAME}") quay.io/rkanson/#{PROJECT_NAME}]
    dockPush = %Q[docker push quay.io/rkanson/#{PROJECT_NAME}]
    # dockCommit = %Q[docker commit $(docker ps -aqf "name=hackweek") quay.io/rkanson/hackweek]
    # dockPush = %Q[docker push quay.io/rkanson/hackweek]
    dockFinal = "#{dockCommit} && #{dockPush}"
    system dockFinal

    puts "Quay.io build updated - deploying to Kubernetes"
    if PROJECT_NAME.include? "gatsby"
        PORT = 80
    elsif PROJECT_NAME.include? "next"
        PORT = 3000
    end
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

    puts "Restarting pod to deploy latest changes..."

    podName = %Q[kubectl get pods --no-headers -o custom-columns=":metadata.name" | grep '#{PROJECT_NAME}']
    kubeRestart = %Q[kubectl delete pod $(#{podName})]
    system kubeRestart

    puts "Your project should be live shortly at http://#{PROJECT_NAME}.sandbox-rkanson.sbx04.pantheon.io/"
else
	puts "Please pass a recipe from the /recipes folder."
end

