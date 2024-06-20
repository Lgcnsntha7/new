#!/bin/bash


compose="$1"

TOP_PID=$$

declare -gA url_list=(["yq"]="https://github.com/mikefarah/yq/releases/download/v4.44.2/yq_linux_amd64" ["docker-compose"]="https://github.com/docker/compose/releases/download/v2.27.1/docker-compose-linux-x86_64")

declare -gA version_list=(["yq"]="yq -V" ["docker-compose"]="docker-compose -v" ["docker"]="docker -v" ["jq"]="jq --version")

declare -ga requirements=("yq" "docker-compose" "docker" "jq")

declare -ga containers_list

declare -ga images_list=("gitlab-ce" "gitlab-runner")

logger() {
  local level
  if [ $# -gt 1 ]; then
    level=$1
    shift
  fi
  local message=$@

  case $level in
    info)
      echo -e "\033[1;32m $message\033[0m"
      ;;
    error)
      echo -e "\033[1;31m[ERROR] $message\033[0m"
      ;;
    *)
      echo -e "$message"
      ;;
  esac
}

kill_script() {
    logger "error" "Killing script with unmet condition"
    kill -9 $TOP_PID
}

check_requirements() {
    logger "Check required packages"
    local breaker=false
    for pkg in "${requirements[@]}"; do
        local cmd=${version_list["$pkg"]}
        local missing_pkg=()
        eval "$cmd"
        if [ $? -ne 0 ]; then
            logger "info" "Missing package download:"
            missing_pkg+=("")
            if [[ -z "${url_list[$pkg]}" ]]; then
                logger "error" "Install $pkg using for package manager"
            else
                logger "error" "Install $pkg by \033[1;33msudo wget -qO /usr/local/bin/$pkg ${url_list[$pkg]}\033[0m"
            fi
            breaker=true
        fi
    done

    if $breaker; then
        kill_script
    fi
}

check_config() {
    local breaker=false
    logger "Check config file $compose"
    local gitlab_url=$(yq '.. | select(has("image")) | select(.image == "*gitlab-ce*") | .environment.GITLAB_OMNIBUS_CONFIG' $compose | grep external_url | awk -F"'" '{print $2}')

    if [[ "$gitlab_url" == *"localhost"* ]]; then
        logger "error" "Do not leave url as localhost please leave it as http://<domain name>"
        breaker=true
    fi

    if $breaker; then
        kill_script
    fi
}

check_container() {
  # Check if the container is running
  logger "Check container..."
  local breaker=false

  if [ -z "$compose" ]; then
    logger "error" "No compose file provied for the script"
    kill_script
  fi

  for image in "${images_list[@]}"; do
        echo "check image $image"
        local tmp=$(get_CONT $image)
        containers_list+=($tmp)
  done

  echo "${containers_list[@]}"

  for container in "${containers_list[@]}"; do
    if docker inspect --format '{{.State.Running}}' "$container_name" &> /dev/null; then
        logger "info" "$container_name is up and running."

    else
        logger "error" "$container_name is not running."
        breaker=true
    fi
  done

  if $breaker; then
    logger "error" "Make sure you have the correct docker-compose file with container gilab-ce and gitlab-runner\n\trun \033[1;33mdocker-compose up -d $compose\033[0m to start gitlab environment"
    kill_script
  fi
}


 get_random_TOKEN() {
    if [[ "$1" == *"default"* ]]; then
        echo "25502e3103cdc4e1cf92616def0c9d"
        return
    fi
    shasum &> /dev/null
    if [ $? -eq 0 ]; then
        echo $RANDOM | shasum | head -c 30
        return
    fi
    sha256sum &> /dev/null
    if [ $? -eq 0 ]; then
        echo $RANDOM | sha256sum | head -c 30
        return
    fi
}

get_CONT() {
    local container_name="$1"
    yq ".. | select(has(\"image\")) | select(.image == \"*$container_name*\") | .container_name" $compose

    echo "full cmd yq \".. | select(has(\"image\")) | select(.image == \"*$container_name*\") | .container_name\" $compose"


}

set_runner_TOKEN() {
    #Return token string as json
    local gitlab="$1"
    local token="$2"

    local gitlab_url=$(yq '.. | select(has("image")) | select(.image == "*gitlab-ce*") | .environment.GITLAB_OMNIBUS_CONFIG' $compose | grep external_url | awk -F"'" '{print $2}')

    result=$(curl --request POST --header "PRIVATE-TOKEN: 25502e3103cdc4e1cf92616def0c9d" --data "runner_type=instance_type" \
     "$gitlab_url/api/v4/user/runners")

    echo $result | jq -r '.token'
}


set_PAT() {
    #Create token authentication for Gitlab
    local container="$1"
    local token="$2"
    
    set +H
    docker exec -it $container gitlab-rails runner "token = User.find_by_username('root').personal_access_tokens.create(scopes: ['create_runner'], name: 'create_runner_pat', expires_at: 1.days.from_now); token.set_token('$token'); token.save!"
    return $?
}

register_RUNNER() {
   local container="$1"
   local token="$1"

   docker exec $container gitlab-runner register --non-interactive \
  --url "http://gitlab:10001" \
  --token "$token" \
  --executor "docker" \
  --docker-image alpine:latest \
  --description "docker-runner" 
}


main() {
    #Check packages
    check_requirements
    check_config
    check_container

    #Order based on the order of images_list
    gitlab_ce_container=${containers_list[0]}
    gitlab_runner_container=${containers_list[1]}

    logger "info" "step 1: set PAT token for gitlab"
    random_token=$(get_random_TOKEN)
    set_PAT "$gitlab_ce_container" "$random_token"

    logger "info" "step 2: request Token"
    token=$(set_runner_TOKEN "$gitlab_ce_container" "$random_token")

    if [ "$token" == *"glrt"* ]; then
        logger "error" "Please check token: $token again a normal token look like \033[1;33mglrt-gxqs_P3RxvBCkXeY-jjz\033[0m"
        kill_script
    fi

    logger "info" "step 3: register Token"
    register_RUNNER "$gitlab_runner_container" "$token"
}

main



