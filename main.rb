require 'yaml'


if ARGV[0].to_s.include?(".yaml")
    yaml = YAML.load_file(ARGV[0].to_s)
else
    yaml = YAML.load_file("pantheon-sites.yaml")
end

PROJECT_NAME = yaml["PROJECT_NAME"]
DOCKER_PATH = yaml["DOCKER_PATH"]
RUN_COMMAND = yaml["RUN_COMMAND"]
PORTS = yaml["PORTS"]

rmCmd = %Q[docker rm -f #{PROJECT_NAME} || true]
buildCmd = %Q[docker build -t #{PROJECT_NAME} #{DOCKER_PATH} --build-arg RUNCOMMAND="#{RUN_COMMAND}"]
runCmd = %Q[docker run --name #{PROJECT_NAME} -p #{PORTS} -d #{PROJECT_NAME}]
if defined? rmCmd
    finalCmd = "#{rmCmd} && #{buildCmd} && #{runCmd}"
else
    finalCmd = "#{buildCmd} && #{runCmd}"
end
exec(finalCmd)