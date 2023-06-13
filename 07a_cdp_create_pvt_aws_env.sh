#!/bin/bash 
 if ! [ -z ${DEV_CLI+x} ]
then
    shopt -s expand_aliases
    alias cdp="cdp 2>/dev/null"
fi 
#source $(cd $(dirname $0); pwd -L)/common.sh
set -o nounset

display_usage() { 
    echo "
Usage:
    $(basename "$0") [--help or -h] <prefix> <credential> <region> <key> <sg_cidr> <AWS_ACCOUNT_ID> <wxm-yes-no> [<subnet1>] [<subnet2>] [<subnet3>] [<vpc_id>] [<knox_sg_id>] [<default_sg_id>]

Description:
    Launches a CDP environment

Arguments:
    prefix:         prefix for your assets
    region:         region for your env
    sg_cidr:        CIDR to open in your security group (your VPN CIDR)
    subnet1:        (optional) subnetId to be used for your environment (must be in different AZ than other subnets)
    subnet2:        (optional) subnetId to be used for your environment (must be in different AZ than other subnets)
    subnet3:        (optional) subnetId to be used for your environment (must be in different AZ than other subnets)
    vpc:            (optional) vpcId associated with subnets
    knox_sg_id:     (optional) knox security GroupId
    default_sg_id:  (optional) default security GroupId
    --help or -h:   displays this help"

}

# check whether user had supplied -h or --help . If yes display usage 
if [[ ( ${1:-x} == "--help") ||  ${1:-x} == "-h" ]] 
then 
    display_usage
    exit 0
fi 


# Check the numbers of arguments
if [  $# -lt 3 ] 
then 
    echo "Not enough arguments!" >&2
    display_usage
    exit 1
fi 

if [  $# -gt 9 ] 
then 
    echo "Too many arguments!" >&2
    display_usage
    exit 1
fi 

if [[ $# -gt 3 && $# -ne 9 ]] 
then 
    echo "Wrong number of arguments!" >&2
    display_usage
    exit 1
fi 
owner=$(cdp iam get-user | jq -r .user.email)

# Mandatory arguments
prefix=$1
region=$2
sg_cidr=$3
AWS_ACCOUNT_ID=`aws sts get-caller-identity --query "Account" --output text`

mkdir -p ssh-key
aws ec2 create-key-pair --key-name ${prefix}-key > ssh-key/id_rsa_${prefix}
keyId=`cat ssh-key/id_rsa_${prefix} | jq .KeyName`

echo "Cloudbreak user ssh key generated & stored to `pwd`/ssh-key"

if [  $# -gt 4 ]
then
    # Optional arguments parsing
    subnet1=$4
    subnet2=$5
    subnet3=$6
    vpc=$7
    knox_sg_id=$8
    default_sg_id=$9

    cdp environments create-aws-environment --environment-name ${prefix}-cdp-env \
        --credential-name ${prefix}-cred \
        --region ${region} \
        --security-access securityGroupIdForKnox="${knox_sg_id}",defaultSecurityGroupId="${default_sg_id}"  \
        --authentication publicKeyId="${keyId}" \
        --log-storage storageLocationBase="${prefix}-cdp-bucket",instanceProfile="arn:aws:iam::$AWS_ACCOUNT_ID:instance-profile/${prefix}-log-role" \
        --subnet-ids "${subnet1}" "${subnet2}" "${subnet3}" \
        --vpc-id "${vpc}" \
        --enable-tunnel

else 
    cdp environments create-aws-environment --environment-name ${prefix}-cdp-env \
        --credential-name ${prefix}-cred  \
        --region ${region} \
        --security-access cidr="${sg_cidr}"  \
        --authentication publicKeyId="${keyId}" \
        --log-storage storageLocationBase="${prefix}-cdp-bucket",instanceProfile="arn:aws:iam::$AWS_ACCOUNT_ID:instance-profile/${prefix}-log-role" \
        --network-cidr "10.0.0.0/16" \
        --enable-tunnel
fi