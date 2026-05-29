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

dnf install maven -y
VALIDATE $? "Installing the Maven"

id roboshop
if [ $? -ne 0 ]; then
    useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop
    VALIDATE $? "Creating the user for the application"
else
    echo "User roboshop already exists"
fi

rm -rf /app
VALIDATE $? "Removing existing code"

mkdir -p /app 
curl -L -o /tmp/shipping.zip https://roboshop-artifacts.s3.amazonaws.com/shipping-v3.zip 
cd /app 
unzip /tmp/shipping.zip
VALIDATE $? "Downloading the packaging for the App"

mvn clean package
mv target/shipping-1.0.jar shipping.jar
VALIDATE $? "Building the dependencies and packaging the App"

cp "$SCRIPTDIR"/configs/shipping.service /etc/systemd/system/
VALIDATE $? "Creating the shipping service for the App"

systemctl daemon-reload
systemctl enable shipping 
systemctl start shipping
VALIDATE $? "Enabling and starting the shipping services"

dnf install mysql -y 
VALIDATE $? "Installing mysql-client"

mysql -h mysql.mrmotam.online -uroot -pRoboShop@1 < /app/db/schema.sql
mysql -h mysql.mrmotam.online -uroot -pRoboShop@1 < /app/db/app-user.sql 
mysql -h mysql.mrmotam.online -uroot -pRoboShop@1 < /app/db/master-data.sql
VALIDATE $? "Loading the Schema, App and Master date "

systemctl start shipping
VALIDATE $? "Retarting the shipping services"