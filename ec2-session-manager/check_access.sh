#!/usr/bin/env bash

set -euo pipefail

cyn=$'\e[1;36m'
color=$'\e[1;35m'
end=$'\e[0m'

function display (){
  if [ "$PRESMODE" = true ] ; then
    printf "${cyn}$1${end}\n\n\n"
    read -n 1 -s -r -p "---"
    printf "\n\n\n"
  fi
}

PRESMODE="${PRESMODE:-true}"
PROFILE="${PROFILE:-session-manager}"

# Ugly export, but this is just for test. Don't output your credentials...
export AWS_ACCESS_KEY_ID=$(terraform output aws_access_key_id)
export AWS_SECRET_ACCESS_KEY=$(terraform output aws_secret_access_key)
export AWS_REGION="eu-west-3"

display "Retrieve latest sessions from ssm sessions history\n aws ssm describe-sessions --state History --filter \"key=Owner,value=$(terraform output session_manager_user_arn)\""
aws ssm describe-sessions --state History --filter "key=Owner,value=$(terraform output session_manager_user_arn)"


