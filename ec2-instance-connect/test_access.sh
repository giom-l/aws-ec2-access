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
AWS_REGION="${AWS_REGION:-eu-west-3}"
NAME="${1:-instance-connect}"
SSH_PUB_KEY_FILE="${SSH_PUB_KEY_FILE:-$HOME/.ssh/id_rsa.pub}"

# Ugly export, but this is just for test. Don't output your credentials...
export AWS_ACCESS_KEY_ID=$(terraform output aws_access_key_id)
export AWS_SECRET_ACCESS_KEY=$(terraform output aws_secret_access_key)
export AWS_REGION="eu-west-3"


display "Lets use \"instance-connect\" instance name"
display "First we need to gather informations about the instance we want to connect (instance connect use only instance id...)\n aws ec2 describe-instances --filters Name=tag:Name,Values=$NAME Name=instance-state-name,Values=running --query \"Reservations[*].Instances[*].[PublicIpAddress,InstanceId,Placement.AvailabilityZone]\" --output text"

# Get informations about instance
read -r ip id az <<< $(aws ec2 describe-instances --filters Name=tag:Name,Values=$NAME Name=instance-state-name,Values=running --query "Reservations[*].Instances[*].[PublicIpAddress,InstanceId,Placement.AvailabilityZone]" --output text)

display "It allows to get instance id, ip and availability zone\n instance id : ${id}\n instance ip: ${ip}\n Availability zone : ${az}"

display "Then we use aws-cli to send our public key to the instance metadata. This allow us to connect to the instance within 60s.\n aws ec2-instance-connect send-ssh-public-key --availability-zone $az --instance-id $id --instance-os-user ec2-user --ssh-public-key file://$SSH_PUB_KEY_FILE"
# Then send desired public key
aws ec2-instance-connect send-ssh-public-key --availability-zone $az --instance-id $id --instance-os-user ec2-user --ssh-public-key file://$SSH_PUB_KEY_FILE

display "Now we can connect to the instance with ssh \n Connecting to instance... \n ssh -i $SSH_PUB_KEY_FILE ec2-user@$ip"

# then connect to the instance
ssh -i $SSH_PUB_KEY_FILE ec2-user@$ip
