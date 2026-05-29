#!/bin/bash

shopt -s nocasematch

PROJECT_NAME=robo
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
NOCOLOR='\e[0m'
LOGS_FOLDER="/var/log/roboshop"
sudo mkdir -p $LOGS_FOLDER
sudo chown -R ec2-user:ec2-user $LOGS_FOLDER
sudo chmod -R 755 $LOGS_FOLDER
LOGS_FILE="$LOGS_FOLDER/$0.log"
TIMESTAMP=$(date '+%Y-%m-%d %T')

#user validation
if [ $(id -u) -ne 0 ]; then
    echo -e "$RED Please run this script as Root User $NOCOLOR" | tee -a $LOGS_FILE
    exit 1
fi


VALIDATE(){
    if [ $1 -ne 0 ]; then
        echo -e "$TIMESTAMP $RED [ERROR] $NOCOLOR -- $2 Failed" | tee -a $LOGS_FILE
        exit 1
    else
        echo -e "$TIMESTAMP $GREEN [SUCCESS] $NOCOLOR -- $2 Success" | tee -a $LOGS_FILE
    fi
}

cp configs/rabbitmq.repo /etc/yum.repos.d/
VALIDATE $? "Copy RabbitMQ repo file to repo list"

dnf install rabbitmq-server -y &>> $LOGS_FILE
VALIDATE $? "Installation is complete"

systemctl enable rabbitmq-server &>> $LOGS_FILE
systemctl restart rabbitmq-server
VALIDATE $? "RabbitMQ Services restarted"

rabbitmqctl add_user roboshop roboshop123
rabbitmqctl set_permissions -p / roboshop ".*" ".*" ".*"
VALIDATE $? "Setting up RabbitMQ user"