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

dnf module disable nodejs -y
dnf module enable nodejs:20 -y
dnf install nodejs -y
VALIDATE $? "Enabling and installing the NodeJS 20"

useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop
VALIDATE $? "Creating the user for the application"

mkdir /app 
curl -o /tmp/catalogue.zip https://roboshop-artifacts.s3.amazonaws.com/catalogue-v3.zip 
cd /app 
unzip /tmp/catalogue.zip
npm install 
VALIDATE $? "Downloading the dependencies and packaging the App"

cp ./configs/catalogue.service /etc/systemd/system/
VALIDATE $? "Creating the Catalogue service for the App"


systemctl daemon-reload
systemctl enable catalogue 
systemctl start catalogue
VALIDATE $? "Enabling and starting the cataloge services"

cp configs/mongo.repo /etc/yum.repos.d/
VALIDATE $? "Copy Mongo repo file to repo list"

dnf install mongodb-mongosh -y 
VALIDATE $? "Installing the monogosh cli"

mongosh --host mongodb.mrmotam.online </app/db/master-data.js
VALIDATE $? "Setting the catalogue database"

