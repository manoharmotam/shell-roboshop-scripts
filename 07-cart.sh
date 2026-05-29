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
SCRIPTDIR=$PWD

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

dnf module disable nodejs -y &>> $LOGS_FILE
dnf module enable nodejs:20 -y &>> $LOGS_FILE
dnf install nodejs -y &>> $LOGS_FILE
VALIDATE $? "Enabling and installing the NodeJS 20"

id roboshop &>> $LOGS_FILE
if [ $? -ne 0 ]; then
    useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop
    VALIDATE $? "Creating the user for the application"
else
    echo "User roboshop already exists"
fi

rm -rf /app
VALIDATE $? "Removing existing code"

mkdir -p /app 
curl -o /tmp/cart.zip https://roboshop-artifacts.s3.amazonaws.com/cart-v3.zip &>> $LOGS_FILE
cd /app 
unzip /tmp/cart.zip &>> $LOGS_FILE
npm install &>> $LOGS_FILE
VALIDATE $? "Downloading the dependencies and packaging the App"

cp "$SCRIPTDIR"/configs/cart.service /etc/systemd/system/
VALIDATE $? "Creating the cart service for the App"


systemctl daemon-reload
systemctl enable cart &>> $LOGS_FILE
systemctl start cart
VALIDATE $? "Enabling and starting the cart services"