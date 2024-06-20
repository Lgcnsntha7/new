#!/bin/bash

TOP_PID=$$

declare -gA url_list=(["yq"]="https://github.com/mikefarah/yq/releases/download/v4.44.2/yq_linux_amd64" ["docker-compose"]="https://github.com/docker/compose/releases/download/v2.27.1/docker-compose-linux-x86_64")

declare -gA version_list=(["yq"]="yq -V" ["docker-compose"]="docker-compose -v" ["docker"]="docker -v" ["jq"]="jq --version")

declare -ga requirements=("yq" "docker-compose" "docker" "jq")

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

check_compose_file() {
    if [ ! -f ./docker-compose.yaml ] || [ ! -f ./docker-compose.yml ]; then
        logger "error" "docker-compose file not found!"
    fi

check_docker() {
    docker-compose up -d
    if [ $? -eq 1 ]; then
        logger "Checking user config..."
        local status=$(systemctl status docker | grep "Active:" | awk '{print $2}')
        if ! grep -q "^docker:" /etc/group || ! groups | grep -q "docker"; then
            logger "error" "group or user does not exist"
            logger "Make sure you do these steps:\n\tCreate group docker: \033[1;33msudo groupadd docker\033[0m\n\tMake sure to add user to group: \033[1;33msudo usermod -aG docker $(whoami)\033[0m\n\tLog out and log in and start service"
        fi

        if [[ "$status" = *"inactive"* ]]; then
            logger "error" "docker service is inactive"
            echo -e "\033[1;33m"
            systemctl status docker
            echo -e "\033[0m"
        fi
    fi
}