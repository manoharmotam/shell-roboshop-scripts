#!/bin/bash

shopt -s nocasematch

PROJECT_NAME=robo
VPCID=vpc-01a1d11626ea0045f
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
NOCOLOR='\e[0m'
LOG_FILE=sg.log
MYIP=$(curl -s checkip.amazonaws.com)/32

if [ $# -lt 2 ]; then
    echo -e "$RED Provide 2 Arguments to Create or Delete a security group(s). $NOCOLOR"
    echo -e "$YELLOW USAGE: $0 [Create/Delete] [Name] $NOCOLOR"
    exit 1
fi

#get sg id if exists
check_sg(){
    NAME=$1
    aws ec2 describe-security-groups --group-names "$PROJECT_NAME-$NAME" --query 'SecurityGroups[*].GroupId' --output text 2>> $LOG_FILE
}

for sgr in "$@"
do
    SGID=$(check_sg "$sgr")
    if [ $? -ne 0 ]; then
        echo "The security group does not exist. You need to create one."
    else
        echo "Adding the security rule"
        aws ec2 authorize-security-group-ingress \
        --group-id "$SGID" \
        --protocol tcp \
        --port 22 \
        --cidr $MYIP
    fi
done