#!/usr/bin/env bash

set -euo pipefail

cyn=$'\e[1;36m'
color=$'\e[1;35m'
end=$'\e[0m'

usage(){
    echo "Usage: ./test_access.sh instance_name document_name"
    echo "Positional arguments : "
    echo "  INSTANCE_NAME : value to look for in tag:Name instances fields. Defaults to session-manager"
    echo "  DOCUMENT_NAME : SSM document name your aws user is granted to. Defaults to SSM-SessionManagerRunShell-session-manager"
}

function display (){
  if [ "$PRESMODE" = true ] ; then
    printf "${cyn}$1${end}\n\n\n"
    read -n 1 -s -r -p "---"
    printf "\n\n\n"
  fi
}

PRESMODE="${PRESMODE:-true}"
INSTANCE_NAME="${1:-session-manager}"
DOCUMENT_NAME="${2:-SSM-SessionManagerRunShell}"

# Ugly export, but this is just for test. Don't output your credentials...
export AWS_ACCESS_KEY_ID=$(terraform output aws_access_key_id)
export AWS_SECRET_ACCESS_KEY=$(terraform output aws_secret_access_key)

display "Retrieve instance id from aws-cli using tag Name\n aws ec2 describe-instances --filter \"Name=tag:Name,Values=$INSTANCE_NAME\" \"Name=instance-state-name,Values=running\" --query \"Reservations[*].Instances[*].{Instance:InstanceId}\" --output=text | head -n1"
instance_id=$(aws ec2 describe-instances --filter "Name=tag:Name,Values=$INSTANCE_NAME" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].{Instance:InstanceId}" --output=text | head -n1);

if [ -z "${instance_id}" ];
  then
    echo "Instance with name \"${INSTANCE_NAME}\" not found"
    exit 1;
fi;


display "Then launch a new session\n aws ssm start-session --target=$instance_id --document-name $DOCUMENT_NAME\n and run some commands"
aws ssm start-session --target=$instance_id --document-name $DOCUMENT_NAME
