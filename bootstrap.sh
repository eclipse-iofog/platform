#!/bin/bash
#
# *******************************************************************************
#  * Copyright (c) 2019 Edgeworx, Inc.
#  *
#  * This program and the accompanying materials are made available under the
#  * terms of the Eclipse Public License v. 2.0 which is available at
#  * http://www.eclipse.org/legal/epl-2.0
#  *
#  * SPDX-License-Identifier: EPL-2.0
#  *******************************************************************************
#
. ./scripts/utils.sh

usage() {
    prettyTitle "iofog Platform Bootstrap"
    echo
    echoInfo "Usage: `basename $0` [-h, --help] [-v, --verify] [--gcloud-service-account KEY_FILE] [--no-auth]"
    echoInfo "  --verify will only check for dependencies"
    echoInfo "  --no-auth will not perform gcloud authentication"
    echoInfo "  --gcloud-service-account KEY_FILE will only perform gcloud authentication using the KEY_FILE as service account"
    echo
    echoInfo "$0 will install all dependencies"
    exit 0
}
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
  usage
fi

POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]
do
key="$1"
case $key in
    -h|--help)
    usage
    ;;
    -v|--verify)
    VERIFY=1
    shift # past argument
    ;;
    --gcloud-service-account)
    GCLOUD_KEY_FILE="$2"
    shift # past argument
    shift # past value
    ;;
    --no-auth)
    NO_AUTH=1
    shift # past argument
    ;;
    *)
    POSITIONAL_ARGS+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done


OS=$(uname -s | tr A-Z a-z)
GCLOUD_VERSION=253.0.0
GCP_SDK_PACKAGE_URL="https://console.cloud.google.com/storage/browser/cloud-sdk-release?authuser=0&prefix=google-cloud-sdk-${GCLOUD_VERSION}"
GCP_SDK_INSTRUCTION_URL="https://cloud.google.com/sdk/docs/downloads-versioned-archives"
LIB_LOCATION=/usr/local/lib

TERRAFORM_VERSION=0.12.8
TERRAFORM_PACKAGE_URL="https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/"
TERRAFORM_INSTRUCTION_URL="https://cloud.google.com/sdk/docs/downloads-versioned-archives"

KUBECTL_INSTRUCTION_URL="https://kubernetes.io/docs/tasks/tools/install-kubectl/"

JQ_INSTRUCTION_URL="https://github.com/stedolan/jq/wiki/Installation"

help_install_gcp_sdk() {
    echoError "We could not automatically install gcloud sdk"
    echoInfo "Please follow the installation instructions from here: ${GCP_SDK_INSTRUCTION_URL}"
}

install_gcp() {
    if [[ "$1" == "windows" ]]; then
        help_install_gcp_sdk
        return 1
    fi
    curl -Lo gcloud.tar.gz https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-"$GCLOUD_VERSION"-"$1"-x86_64.tar.gz
    sudo mkdir -p "$LIB_LOCATION"/
    tar -xf gcloud.tar.gz -C "$LIB_LOCATION"
    rm gcloud.tar.gz
    "$LIB_LOCATION"/google-cloud-sdk/install.sh -q
    source "$LIB_LOCATION"/google-cloud-sdk/completion.bash.inc
    source "$LIB_LOCATION"/google-cloud-sdk/path.bash.inc
    if [[ -z $(command -v gcloud) ]]; then
        help_install_gcp_sdk
        return 1
    else
        echoSuccess "gcloud installed"
        GCLOUD_INSTALLED=true
        gcloud --version
        echo ""
        return 0
    fi
}

check_gcp() {
    { # Try
        if [[ -z $(command -v gcloud) ]]; then
            echoError "gcloud not found!"
            if [[ "${VERIFY}" -eq 1 ]]; then
                return 1
            else
                echoInfo "====> Installing gcloud sdk..."
                if [[ "$OSTYPE" == "linux-gnu" ]]; then
                    install_gcp "linux"
                elif [[ "$OSTYPE" == "darwin"* ]]; then
                    # Mac OSX
                    install_gcp "darwin"
                elif [[ "$OSTYPE" == "cygwin" ]]; then
                    # POSIX compatibility layer and Linux environment emulation for Windows
                    install_gcp "windows"
                elif [[ "$OSTYPE" == "msys" ]]; then
                    # Lightweight shell and GNU utilities compiled for Windows (part of MinGW)
                    install_gcp "windows"
                elif [[ "$OSTYPE" == "win32" ]]; then
                    # I'm not sure this can happen.
                    install_gcp "windows"
                elif [[ "$OSTYPE" == "freebsd"* ]]; then
                    install_gcp "linux"
                else
                    help_install_gcp_sdk
                    return 1
                fi
            fi
        else
            echoSuccess "gcloud found in path!"
            gcloud --version    
            echo ""
            return 0
        fi
        return $?
    } || { # Catch
        help_install_gcp_sdk
        return 1
    }
}

help_install_tf() {
    echoError "We could not automatically install terraform"
    echoInfo "Please download the relevant zip package according to your operating system from here: ${TERRAFORM_PACKAGE_URL}"
    echoInfo "Terraform is distributed as a single binary. Install Terraform by unzipping it and moving it to a directory included in your system's PATH ."
}

install_tf() {
    echoInfo "====> Installing terraform..."
    if [[ "$1" == "windows" ]]; then
        help_install_tf
        return 1
    fi
    if [[ -z "$(command -v unzip)" ]]; then
        {
            sudo apt-get update -qy && sudo apt-get install -qy unzip > /dev/null
        } || {
            sudo apt update -qy && sudo apt install -qy unzip > /dev/null
        } || {
            sudo yum update -qy && sudo yum install -qy unzip > /dev/null
        } || {
            brew tap homebrew/dupes && brew install unzip > /dev/null
        } || {
            echoError "Could not install unzip"
            help_install_tf
            return 1
        }
        
    fi

    curl -fSL -o terraform.zip https://releases.hashicorp.com/terraform/"$TERRAFORM_VERSION"/terraform_"$TERRAFORM_VERSION"_"$1"_amd64.zip
    sudo mkdir -p "$LIB_LOCATION"/
    sudo unzip -oq terraform.zip -d "$LIB_LOCATION"/terraform
    rm -f terraform.zip
    sudo ln -Ffs "$LIB_LOCATION"/terraform/terraform /usr/local/bin/terraform
    if [[ -z $(command -v terraform) ]]; then
        help_install_tf
        return 1
    else
        echoSuccess "terraform installed"
        terraform --version
        echo ""
        return 0
    fi
}

install_tf_by_os() {
    if [[ "$OSTYPE" == "linux-gnu" ]]; then
        install_tf "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # Mac OSX
        install_tf "darwin"
    elif [[ "$OSTYPE" == "cygwin" ]]; then
        # POSIX compatibility layer and Linux environment emulation for Windows
        install_tf "windows"
    elif [[ "$OSTYPE" == "msys" ]]; then
        # Lightweight shell and GNU utilities compiled for Windows (part of MinGW)
        install_tf "windows"
    elif [[ "$OSTYPE" == "win32" ]]; then
        # I'm not sure this can happen.
        install_tf "windows"
    elif [[ "$OSTYPE" == "freebsd"* ]]; then
        install_tf "freebsd"
    else
        help_install_tf
        return 1
    fi
    return $?
}

check_tf() {
    { # Try
        if [[ -z $(command -v terraform) ]]; then
            echoError "Terraform not found!"
            if [[ "${VERIFY}" -eq 1 ]]; then
                return 1
            else
                echoInfo "Installing Terraform version: ${TERRAFORM_VERSION}"
                install_tf_by_os
                return $?
            fi
        fi
        local CURRENT_TERRAFORM_VERSION=$(terraform --version | sed -n 's/.* v\([0-9.]*\)$/\1/p')
        echoInfo "Found Terraform version: ${CURRENT_TERRAFORM_VERSION}"
        if versionCompare $TERRAFORM_VERSION $CURRENT_TERRAFORM_VERSION; then
            if [[ "${VERIFY}" -eq 1 ]]; then
                echoError "Terraform version insufficient! Expected at least ${TERRAFORM_VERSION}!"
                return 1
            else
                echoInfo "Terraform version insufficient! Expected at least ${TERRAFORM_VERSION}!"
                echoInfo "Installing Terraform version: v${TERRAFORM_VERSION}"
                install_tf_by_os
                return $?
            fi
        else
            echoSuccess "Terraform version ${CURRENT_TERRAFORM_VERSION} found in path! Required ${TERRAFORM_VERSION}."
            terraform --version
            echo ""
            return 0
        fi
    } || { # Catch
        help_install_tf
        return 1
    }
}

check_go() {
    if [[ -z $(command -v go) ]]; then
        echoError "go not found!"
        if [[ "${VERIFY}" -eq 1 ]]; then
            return 1
        else
            install_go
        fi
    else
        echoSuccess "go found in path!"
        go version    
        echo ""
        return 0
    fi
    return $?
}

install_go() {
    if [[ -z "$(command -v go)" ]]; then
        echoInfo "Installing golang as its a requirement for Terraform"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            curl -O https://dl.google.com/go/go1.12.7.darwin-amd64.tar.gz
            sudo tar -xvf go1.12.7.darwin-amd64.tar.gz
        else
            curl -O https://dl.google.com/go/go1.12.7.linux-amd64.tar.gz
            sudo tar -xvf go1.12.7.linux-amd64.tar.gz
        fi
        
        sudo chown -R root:root ./go
        sudo cp -r go /usr/local

        export GOPATH="$HOME/go"
        grep -qxF "export GOPATH=\"$HOME/go\"" ~/.profile
        if [[ $? -ne 0 ]]; then
            echo "export GOPATH=\"$HOME/go\"" >> ~/.profile
        fi

        export PATH="$PATH:/usr/local/go/bin:$GOPATH/bin"
        grep -qxF "export PATH=\"$PATH:/usr/local/go/bin:$GOPATH/bin\"" ~/.profile
        if [[ $? -ne 0 ]]; then
            echo "export PATH=\"$PATH:/usr/local/go/bin:$GOPATH/bin\"" >> ~/.profile
        fi
    else
        echoSuccess "go installed"
        go version
        echo ""
        return 0   
    fi
}

help_install_go() {
    echoError "We could not automatically install go"
    echoInfo "Please download the relevant zip package according to your operating system."
}


#
# Check between apt or yum
#
install_iofogctl_linux() {
    if [[ -x "$(command -v apt-get)" ]]; then
        curl -s https://packagecloud.io/install/repositories/iofog/iofogctl/script.deb.sh | sudo bash
        sudo apt-get install iofogctl -y
    elif [[ -x "$(command -v apt)" ]]; then
        curl -s https://packagecloud.io/install/repositories/iofog/iofogctl/script.deb.sh | sudo bash
        sudo apt install iofogctl -y
    elif [[ -x "$(command -v yum)" ]]; then
        curl -s https://packagecloud.io/install/repositories/iofog/iofogctl/script.rpm.sh | sudo bash
        sudo yum install iofogctl -y
    else
        iofogctl_install_exit
        return 1
    fi
    iofogctl_install_success
    return $?
}

install_iofogctl_win() {
    echoError "We do not currently support Windows for iofgoctl"
    return 1
}

install_iofogctl_darwin() {
    if [[ -z "$(command -v brew)" ]]; then
        echoInfo "Brew not found"
        iofogctl_install_exit
        return 1
    else
        brew tap eclipse-iofog/iofogctl
        brew install iofogctl
        iofogctl_install_success
        return $?
    fi
}


iofogctl_install_success() {
    if [[ -z "$(command -v iofogctl)" ]]; then
        iofogctl_install_exit
        return 1
    else
        echoSuccess "iofogctl installed!"
        iofogctl version
        echo ""
        return 0
    fi
}

iofogctl_install_exit() {
    echoInfo "Could not detect package installation system"
    echoInfo "Please follow github instructions to install iofogctl: https://github.com/eclipse-iofog/iofogctl"
}

#
# Install iofogctl
#
install_iofogctl() {
    echoInfo "====> Installing iofogctl..."
    if [[ "$OSTYPE" == "linux-gnu" ]]; then
        install_iofogctl_linux
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # Mac OSX
        install_iofogctl_darwin
    elif [[ "$OSTYPE" == "cygwin" ]]; then
        # POSIX compatibility layer and Linux environment emulation for Windows
        install_iofogctl_win
    elif [[ "$OSTYPE" == "msys" ]]; then
        # Lightweight shell and GNU utilities compiled for Windows (part of MinGW)
        install_iofogctl_win
    elif [[ "$OSTYPE" == "win32" ]]; then
        # I'm not sure this can happen.
        install_iofogctl_win
    elif [[ "$OSTYPE" == "freebsd"* ]]; then
        install_iofogctl_linux
    else
        iofogctl_install_exit
        return 1
    fi
    return $?
}

#
# Check if iofogctl exists
#
check_iofogctl() {
    {
        if [[ -z "$(command -v iofogctl)" ]]; then
            echoError "iofogctl not found!"
            if [[ "${VERIFY}" -eq 1 ]]; then
                return 1
            else
                install_iofogctl
                return $?
            fi
        else
            echoSuccess "iofogctl found in path!"
            iofogctl version    
            echo ""
            return 0
        fi
    } || {
        iofogctl_install_exit
        return 1
    }
}

help_install_kubectl() {
    echoError "We could not automatically install kubectl"
    echoInfo "Please follow the installation instructions from here: ${KUBECTL_INSTRUCTION_URL}"
}

install_kubectl_success() {
    if [[ -z "$(command -v kubectl)" ]]; then
        help_install_kubectl
        return 1
    else
        echoSuccess "kubectl installed!"
        kubectl version
        echo ""
        return 0
    fi
}

install_kubectl() {
    echoInfo "====> Installing kubectl..."
    if [[ "$1" == "windows" ]]; then
        help_install_kubectl
        false
        return
    fi
    curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/$1/amd64/kubectl"
    chmod +x ./kubectl
    sudo mv ./kubectl /usr/local/bin/kubectl
    install_kubectl_success
    return $?
}

check_kubectl() {
    {
        if ! [[ -x "$(command -v kubectl)" ]]; then
            echoError "Kubectl not found"
            if [[ "${VERIFY}" -eq 1 ]]; then
                return 1
            else
                if [[ "$OSTYPE" == "linux-gnu" ]]; then
                    install_kubectl "linux"
                elif [[ "$OSTYPE" == "darwin"* ]]; then
                    # Mac OSX
                    install_kubectl "darwin"
                elif [[ "$OSTYPE" == "cygwin" ]]; then
                    # POSIX compatibility layer and Linux environment emulation for Windows
                    install_kubectl "windows"
                elif [[ "$OSTYPE" == "msys" ]]; then
                    # Lightweight shell and GNU utilities compiled for Windows (part of MinGW)
                    install_kubectl "windows"
                elif [[ "$OSTYPE" == "win32" ]]; then
                    # I'm not sure this can happen.
                    install_kubectl "windows"
                elif [[ "$OSTYPE" == "freebsd"* ]]; then
                    install_kubectl "linux"
                else
                    help_install_kubectl
                    false
                fi
            fi
        else
            echoSuccess "kubectl found in path!"
            kubectl version    
            echo ""
            return 0
        fi
        return $?
    } || {
        help_install_kubectl
        return 1
    }
    
}

# JQ

help_install_jq() {
    echoError "We could not automatically install jq"
    echoInfo "Please follow the installation instructions from here: ${JQ_INSTRUCTION_URL}"
}

install_jq_success() {
    if [[ -z "$(command -v jq)" ]]; then
        help_install_jq
        return 1
    else
        echoSuccess "jq installed!"
        jq --version
        echo "" 
        return 0
    fi
}

install_jq() {
    echoInfo "====> Installing jq..."
    if [[ "$1" == "windows" ]]; then
        help_install_jq
        return 1
    fi
    {
        sudo apt-get update -qy && sudo apt-get install -qy jq
    } || {
        sudo apt update -qy && sudo apt install -qy jq
    } || {
        sudo yum update -qy && sudo yum install -qy jq
    } || {
        brew install jq
    } || {
        echoError "Could not install jq"
        help_install_jq
        return 1
    }
        
    if [[ -z "$(command -v jq)" ]]; then
        help_install_jq
        return 1
    else
        echoSuccess "jq installed!"
        jq --version
        echo "" 
        return 0
    fi
}

check_jq() {
    {
        if ! [[ -x "$(command -v jq)" ]]; then
            echoError "jq not found!"
            if [[ "${VERIFY}" -eq 1 ]]; then
                return 1
            else
                if [[ "$OSTYPE" == "linux-gnu" ]]; then
                    install_jq "linux"
                elif [[ "$OSTYPE" == "darwin"* ]]; then
                    # Mac OSX
                    install_jq "darwin"
                elif [[ "$OSTYPE" == "cygwin" ]]; then
                    # POSIX compatibility layer and Linux environment emulation for Windows
                    install_jq "windows"
                elif [[ "$OSTYPE" == "msys" ]]; then
                    # Lightweight shell and GNU utilities compiled for Windows (part of MinGW)
                    install_jq "windows"
                elif [[ "$OSTYPE" == "win32" ]]; then
                    # I'm not sure this can happen.
                    install_jq "windows"
                elif [[ "$OSTYPE" == "freebsd"* ]]; then
                    install_jq "linux"
                else
                    help_install_jq
                    return 1
                fi
                return $?
            fi
        else
            echoSuccess "jq found in path!"
            jq --version
            return 0
        fi
    } || {
        help_install_jq
        return 1
    }
}

authenticate_gcp() {
    if [[ "${NO_AUTH}" -eq 1 || "${VERIFY}" -eq 1 ]]; then return; fi

    prettyTitle "Gcloud authentication:"
    if [[ -f "$GCLOUD_KEY_FILE" ]]; then
        echo "Activating service account from file: ${GCLOUD_KEY_FILE}..."
        gcloud auth activate-service-account --key-file "${GCLOUD_KEY_FILE}"
    else
        echo "Activating service account using interactive login..."
        gcloud auth login
    fi
    echo
}

display_gcp_final_instructions() {
    if ! [[ ${GCLOUD_INSTALLED} = true ]]; then return; fi

    prettyTitle "Next Steps"
    echo "Please run the following commands and add them in your shell profile file to make gcloud available in the PATH:"
    if [[ -n "`$SHELL -c 'echo $ZSH_VERSION'`" ]]; then
    # assume Zsh
        echo "source $LIB_LOCATION/google-cloud-sdk/completion.zsh.inc"
        echo "source $LIB_LOCATION/google-cloud-sdk/path.zsh.inc"
    elif [[ -n "`$SHELL -c 'echo $FISH_VERSION'`" ]]; then
    # assume Fish
        echo "source $LIB_LOCATION/google-cloud-sdk/path.fish.inc"
    else
    # default to Bash
        echo "source $LIB_LOCATION/google-cloud-sdk/completion.bash.inc"
        echo "source $LIB_LOCATION/google-cloud-sdk/path.bash.inc"
    fi
}

prettyHeader "Bootstrapping ioFog platform dependencies"

if ! [[ -x "$(command -v curl)" ]]; then
    echoError "curl not found"
    exit 1
fi


if [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    echoError "We do not currently support Windows"
    exit 1
fi

check_gcp
authenticate_gcp
gcp_success=$?
check_go
go_success=$?
check_tf
tf_success=$?
check_kubectl
kubectl_success=$?
check_iofogctl
iofogctl_success=$?
check_jq
jq_success=$?

success=0
echo ""
prettyTitle "Bootstrap Summary:"
if [[ $go_success -ne 0 ]]; then
    echoError " ✖️ go" 
    help_install_go
    success=1
else
    echoSuccess " ✔️  go"
fi
if [[ $tf_success -ne 0 ]]; then
    echoError " ✖️ Terraform" 
    help_install_tf
    success=1
else
    echoSuccess " ✔️  Terraform"
fi
if [[ $kubectl_success -ne 0  ]]; then
    echoError " ✖️ Kubectl" 
    help_install_kubectl
    success=1
else
    echoSuccess " ✔️  Kubectl"
fi
if [[ $iofogctl_success -ne 0  ]]; then
    echoError " ✖️ Iofogctl" 
    iofogctl_install_exit
    success=1
else
    echoSuccess " ✔️  Iofogctl"
fi
if [[ $jq_success -ne 0  ]]; then
    echoError " ✖️ jq" 
    iofogctl_install_exit
    success=1
else
    echoSuccess " ✔️  jq"
fi
if [[ $gcp_success -ne 0  ]]; then
    echoError " ✖️ Gcloud" 
    help_install_gcp_sdk
    success=1
else
    echoSuccess " ✔️  Gcloud"
    display_gcp_final_instructions
    echoSuccess "Bootstrap completed!"
fi
exit $success
