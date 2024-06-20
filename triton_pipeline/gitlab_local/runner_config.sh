#!/bin/bash


compose="$1"


check_requirements() {
    yq -V
    echo "Check requirements"
    if [$(uname -m) -eq "amd64"]; then
        echo "Download from https://github.com/mikefarah/yq/releases/download/v4.44.2/yq_linux_amd64"
        sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/download/v4.44.2/yq_linux_amd64
    elif [$(uname -m) -eq "aarch64"]; then
        sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/download/v4.44.2/yq_linux_arm64
    fi
}


get_random() {
    shasum &> /dev/null
    if [$? -eq 0]; then
        echo $RANDOM | shasum | head -c 30
        return
    fi
    sha256sum &> /dev/null
    if [$? -eq 0]; then
        echo $RANDOM | sha256sum | head -c 30
        return
    fi
}

get_CONT() {
    yq '.. | select(has("image")) | select(.image == "*gitlab-ce*") | .container_name' $compose
    yq '.. | select(has("image")) | select(.image == "*gitlab-runner*") | .container_name' $compose
}

get_TOKEN() {
    local container="$1"
    
}


set_PAT() {
    local container="$1"
    set +H
    docker exec -it $container gitlab-rails runner "token = User.find_by_username('root').personal_access_tokens.create(scopes: ['create_runner'], name: 'create_runner_pat', expires_at: 1.days.from_now); token.set_token('25502e3103cdc4e1cf92616def0c9d'); token.save!"
    return $?
}





