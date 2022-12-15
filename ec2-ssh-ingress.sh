#!/bin/bash

# Dirk van der Laarse
# 2022-12-06
# A script to to add or remove a public IP from a Security Group's inbound rules, for port 22

instance=""
aws_cli_profile="default"
HORIZONTALLINE="------------------------------------------------------"
clear
echo $HORIZONTALLINE
echo -e "This script will add or remove a public IP from a Security Group"

# Load list of AWS CLI Named Profiles
echo $HORIZONTALLINE
echo "Loading list of aws-cli profiles from ~/.aws/credentials ....."

aws_cli_profiles=($(grep '\[.*\]' ~/.aws/credentials))
profile_index=0
for each in "${aws_cli_profiles[@]}"
do
    count=$(($profile_index + 1))
    aws_cli_profile=$(echo "${aws_cli_profiles[profile_choice_index]}" | tr -d [])
    echo "$count: $each "
    (( profile_index++ ))
done
echo ""


# Get selected AWS Profile from user input
read -p "PLEASE SELECT AN AWS CLI PROFILE: " profile_choice

if [ "$profile_choice" -eq "$profile_choice" 2> /dev/null ]; then
    if [ $profile_choice -lt 1 -o $profile_choice -gt ${#aws_cli_profiles[@]} ]; then
        echo -e "\n==> Enter a number between 1 and ${#aws_cli_profiles[@]} <==";
    else
        profile_choice_index=$(($profile_choice - 1))
        aws_cli_profile=$(echo "${aws_cli_profiles[profile_choice_index]}" | tr -d [])
        echo "Selected: $aws_cli_profile"
    fi
else
    echo -e "\n==> This is not a number. Exiting. <=="
    exit 1
fi

# Load list of EC2 Security Groups using selected profile
echo $HORIZONTALLINE
echo "Loading list of EC2 Security Groups....."

secgroups=$(aws ec2 describe-security-groups --profile $aws_cli_profile)

echo -e "$HORIZONTALLINE\n"

SECGROUP_IDS=($(echo $secgroups | jq -r '.SecurityGroups[] | .GroupId' | tr -d '[]," '))
SECGROUP_NAMES=($(echo $secgroups | jq -r '.SecurityGroups[] | .GroupName' | tr -d '[]," '))

index=0
for each in "${SECGROUP_IDS[@]}"
do
    count=$(($index + 1))
    echo "$count: $each (${SECGROUP_NAMES[index]}) "
    (( index++ ))
done

echo -e "$HORIZONTALLINE\n"

# Get selected EC2 security group from user input
read -p "PLEASE SELECT THE AWS EC2 Security Group: " choice

if [ "$choice" -eq "$choice" 2> /dev/null ]; then
    if [ $choice -lt 1 -o $choice -gt ${#SECGROUP_IDS[@]} ]; then
        echo -e "\n==> Enter a number between 1 and ${#SECGROUP_IDS[@]} <==";
    else
        choice_index=$(($choice - 1))
        echo "Selected: ${SECGROUP_IDS[choice_index]} (${SECGROUP_NAMES[choice_index]})"
    fi
else
    echo -e "\n==> This is not a number. Exiting. <=="
    exit 1
fi

# Get required action from user input
echo $HORIZONTALLINE
echo -e "Possible Actions for ${SECGROUP_NAMES[choice_index]}:"
echo "1. GET DETAILS"
echo "2. ADD MY IP for SSH"
echo "3. REMOVE MY IP for SSH"
echo "4. REMOVE ALL IP's for SSH"
echo -e "$HORIZONTALLINE\n"

read -p "PLEASE CHOOSE AN ACTION: " action

if [ "$action" -eq "$action" 2> /dev/null ]; then
    echo "Getting external IP..."
    ip=$(dig @resolver4.opendns.com myip.opendns.com +short)
    echo $ip

    if [ $action -lt 1 -o $action -gt 4 ]; then
        echo -e "\n==> Enter a number between 1 and 3 <=="
    elif [ $action -eq 1 ]; then
        aws ec2 describe-security-group-rules --filters Name=group-id,Values=${SECGROUP_IDS[choice_index]} --profile $aws_cli_profile
    elif [ $action -eq 2 ]; then
        aws ec2 authorize-security-group-ingress --group-id ${SECGROUP_IDS[choice_index]} --protocol tcp --port 22 --cidr $ip/32 --profile $aws_cli_profile
    elif [ $action -eq 3 ]; then
        aws ec2 revoke-security-group-ingress --group-id ${SECGROUP_IDS[choice_index]} --protocol tcp --port 22 --cidr $ip/32 --profile $aws_cli_profile
    elif [ $action -eq 4 ]; then
        # Get all SSh rules and pass these rules as a parameter to revoke-security-group-ingress
        inbound_rules=$(aws ec2 describe-security-groups --output json --group-ids ${SECGROUP_IDS[choice_index]} --filters 'Name=ip-permission.from-port,Values=22' --filters 'Name=ip-permission.to-port,Values=22' --query 'SecurityGroups[0].IpPermissions[?ToPort == `22`]' --profile $aws_cli_profile)
        echo "The following rules will be removed:"
        echo $inbound_rules
        inbound_rules_json=$(echo $inbound_rules | jq)
        aws ec2 revoke-security-group-ingress --cli-input-json "{\"GroupId\": \"${SECGROUP_IDS[choice_index]}\", \"IpPermissions\": $inbound_rules_json}"  --profile $aws_cli_profile
    fi
else
    echo -e "\n==> This is not a number. Exiting. <=="
    exit 1
fi

