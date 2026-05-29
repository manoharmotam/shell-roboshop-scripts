#!/bin/bash

shopt -s nocasematch

PROJECT_NAME=robo
VPCID=vpc-01a1d11626ea0045f
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
NOCOLOR='\e[0m'
LOG_FILE=sample.log
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

ACTION=$1
shift

if [ "$ACTION" != create ] && [ "$ACTION" != delete ]; then
    echo -e "$RED Invalid Argument. Provide either Create or Delete operation for a security group(s). $NOCOLOR"
    echo -e "$YELLOW USAGE: $0 [Create/Delete] [Name] $NOCOLOR"
    exit 0
fi

create_security_group_rule(){
        ID=$1
        aws ec2 authorize-security-group-ingress \
        --group-id "$ID" \
        --protocol tcp \
        --port 22 \
        --cidr "$MYIP"    
}

for sg in "$@"
do
    SGID=$(check_sg "$sg")
    if [ $? -ne 0 ]; then
        echo -e "$RED The security group '$PROJECT_NAME-$sg' does not exist. Creating now!! $NOCOLOR"
        aws --no-cli-pager ec2 create-security-group \
        --group-name "$PROJECT_NAME-$sg" \
        --description "$PROJECT_NAME-$sg" \
        --vpc-id $VPCID &>> $LOG_FILE
        SGID=$(check_sg "$sg")        
        echo -e "$GREEN [SUCCESS] $NOCOLOR The security group $PROJECT_NAME-$sg created with $SGID."
        echo -e "$YELLOW [INFO] $NOCOLOR Creating the SG-Rule for $PROJECT_NAME-$sg with $SGID."
        create_security_group_rule "$SGID"
        echo -e "$GREEN [SUCCESS] $NOCOLOR The security group rule $PROJECT_NAME-$sg with $SGID."
    else
        echo -e "$YELLOW [INFO] $NOCOLOR The security group $PROJECT_NAME-$sg already exists with $SGID."
    fi
    
done