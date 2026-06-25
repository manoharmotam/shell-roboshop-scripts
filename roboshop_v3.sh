#!/bin/bash

# shopt -s nocasematch

PROJECT_NAME=robo
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
NOCOLOR='\e[0m'
LOG_FILE=instance.log
AMIID="ami-0220d79f3f480ecf5"
INSTANCE_SIZE="t3.micro"
DOMAIN_NAME="mrmotam.online"
ZONEID=Z00263282318BT9FBW1XK
ALL_INSTANCES="mongodb redis mysql rabbitMQ catalogue user cart shipping payment frontend"

#Validate if the correct arguments are provided
if [ $# -lt 2 ]; then
    echo -e "$RED No arguments provided. Provide either Create or Delete action $NOCOLOR"
    echo -e "$YELLOW USAGE:: $0 <CREATE/DELETE> <Instance name1> [Instance Name2] or [all]... $NOCOLOR"
    exit 1
fi

ACTION=$1
shift

#Ensuring only Delete/Create paramters are provided
if [ "$ACTION" != "create" ] && [ "$ACTION" != "delete" ]; then
    echo -e "$RED Valid arguments not provided. Provide either Create or Delete action $NOCOLOR"
    echo -e "$YELLOW USAGE:: $0 <CREATE/DELETE> <Instance name1> [Instance Name2] or [all]... $NOCOLOR"
    exit 1
fi

if [ "$1" == "all" ]; then
    if [ "$ACTION" == "create" ]; then
        INSTANCES=$ALL_INSTANCES
    else
        INSTANCES=$(echo $ALL_INSTANCES | tr ' ' '\n' | tac | tr '\n' ' ')
    fi
else
    INSTANCES="$@"
fi

get_instance_id(){
    NAME=$1
    aws ec2 describe-instances --filters "Name=tag:Name,Values=$PROJECT_NAME-$NAME" "Name=instance-state-name,Values=running" \
        --query "Reservations[0].Instances[0].InstanceId" --output text
}

r53_record_update(){
    method=$1

    if [ "$method" == "UPSERT" ]; then
        aws --no-cli-pager route53 change-resource-record-sets --hosted-zone-id $ZONEID \
            --change-batch '
                {
                    "Comment": "Creating an A record for '$R53_RECORD'",
                    "Changes": [
                            {
                            "Action": "'$method'",
                            "ResourceRecordSet": {
                                "Name": "'$R53_RECORD'",
                                "Type": "A",
                                "TTL": 1,
                                "ResourceRecords": [{ "Value": "'$IP'" }]
                            }
                        }
                    ]
                }
            '
    elif [ "$method" == "DELETE" ]; then
        aws --no-cli-pager route53 change-resource-record-sets --hosted-zone-id $ZONEID \
            --change-batch '
                {
                    "Comment": "Deleting an A record for '$R53_RECORD'",
                    "Changes": [
                            {
                            "Action": "'$method'",
                            "ResourceRecordSet": {
                                "Name": "'$R53_RECORD'",
                                "Type": "A",
                                "TTL": 1,
                                "ResourceRecords": [{ "Value": "'$IP'" }]
                            }
                        }
                    ]
                }
            '
    else
        echo -e "Enter a proper method for R53 records"
    fi         
}

get_instance_ip(){
    IP=$1

    if [ "$IP" == "PublicIpAddress" ]; then
        aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
            --query "Reservations[0].Instances[0].$IP" \
            --output text
    elif [ "$IP" == "PrivateIpAddress" ]; then
        aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
            --query "Reservations[0].Instances[0].$IP" \
            --output text
    fi    
}


for instance in $INSTANCES
do
    INSTANCE_ID=$(get_instance_id "$instance")
    if [ "$ACTION" == "create" ]; then
        if [ "$INSTANCE_ID" == "None" ]; then
            INSTANCE_ID=$(aws ec2 run-instances \
                --image-id "$AMIID" \
                --instance-type "$INSTANCE_SIZE" \
                --security-groups "$PROJECT_NAME-$instance" \
                --tag-specification "ResourceType=instance,Tags=[{Key=Name,Value=$PROJECT_NAME-$instance}]" \
                --query "Instances[0].InstanceId" \
                --output text)
            aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
            echo -e "Instance is created and running: $GREEN $INSTANCE_ID $NOCOLOR"
        else
            echo -e "$RED Instance $INSTANCE_ID is already running $NOCOLOR"
        fi

        if [ "$instance" == "frontend" ]; then
            IP=$(get_instance_ip "PublicIpAddress")
            R53_RECORD="$DOMAIN_NAME"
        else
            IP=$(get_instance_ip "PrivateIpAddress")
            R53_RECORD="$instance.$DOMAIN_NAME"
        fi
    #updating the AWS record

        r53_record_update "UPSERT"
        echo -e "$YELLOW Updated the R53 Record for $instance $NOCOLOR"
    
    elif [ "$ACTION" == "delete" ]; then
        if [ "$INSTANCE_ID" == "None" ]; then
            echo -e "There are no instances to delete/destroy."
        else
            echo "Found $INSTANCE_ID. Proceeding to delete"
            INSTANCE_ID=$(aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" \
                --query "TerminatingInstances[*].InstanceId" \
                --output text)
            echo -e "$INSTANCE_ID is now deleted"
        if [ "$instance" == "frontend" ]; then
            IP=$(get_instance_ip "PublicIpAddress")
            R53_RECORD="$DOMAIN_NAME"
        else
            IP=$(get_instance_ip "PrivateIpAddress")
            R53_RECORD="$instance.$DOMAIN_NAME"
        fi
            echo -e "Proceeding to delete associated R53 records"
            r53_record_update "DELETE"
            echo "R53 $R53_RECORD deleted"
        fi
    fi
done
