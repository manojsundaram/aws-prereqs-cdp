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
    credentials:    CDP credential name
    region:         region for your env
    key:            name of the AWS key to re-use
    sg_cidr:        CIDR to open in your security group
    workload_analytics  enable workload analytics?
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
if [  $# -lt 6 ] 
then 
    echo "Not enough arguments!" >&2
    display_usage
    exit 1
fi 

if [  $# -gt 13 ] 
then 
    echo "Too many arguments!" >&2
    display_usage
    exit 1
fi 

if [[ $# -gt 6 && $# -ne 13 ]] 
then 
    echo "Wrong number of arguments!" >&2
    display_usage
    exit 1
fi 
flatten_tags() {
    tags=$1
    flattened_tags=""
    for item in $(echo ${tags} | jq -r '.[] | @base64'); do
        _jq() {
            echo ${item} | base64 --decode | jq -r ${1}
        }
        #echo ${item} | base64 --decode
        key=$(_jq '.key')
        value=$(_jq '.value')
        flattened_tags=$flattened_tags" key=\"$key\",value=\"$value\""
    done
    echo $flattened_tags
}

prefix=$1
credential=$2
region=$3
key=$4
sg_cidr=$5
AWS_ACCOUNT_ID=$6
workload_analytics=$7
owner=$(cdp iam get-user | jq -r .user.email)
if [  $# -gt 6 ]
then
    subnet1=$8
    subnet2=$9
    subnet3=${10}
    vpc=${11}
    knox_sg_id=${12}
    default_sg_id=${13}

#    cdp iam add-ssh-public-key --public-key $key --description ${prefix}-key
    mkdir -p ssh-key
    aws ec2 create-key-pair --key-name ${prefix}-key > ssh-key/id_rsa_${prefix}
    keyId=`cat ssh-key/id_rsa_${prefix} | jq .KeyName`

    cdp environments create-aws-environment --environment-name ${prefix}-cdp-env \
        --credential-name ${credential} \
        --region ${region} \
        --security-access securityGroupIdForKnox="${knox_sg_id}",defaultSecurityGroupId="${default_sg_id}"  \
        --authentication publicKeyId="${keyId}" \
        --log-storage storageLocationBase="${prefix}-cdp-bucket",instanceProfile="arn:aws:iam::$AWS_ACCOUNT_ID:instance-profile/${prefix}-log-role" \
        --subnet-ids "${subnet1}" "${subnet2}" "${subnet3}" \
        --vpc-id "${vpc}" \
        --enable-tunnel

else 
    cdp environments create-aws-environment --environment-name ${prefix}-cdp-env \
        --credential-name ${credential}  \
        --region ${region} \
        --security-access cidr="${sg_cidr}"  \
        --authentication publicKeyId="${keyId}" \
        --log-storage storageLocationBase="${prefix}-cdp-bucket",instanceProfile="arn:aws:iam::$AWS_ACCOUNT_ID:instance-profile/${prefix}-log-role" \
        --network-cidr "10.0.0.0/16" \
        --enable-tunnel
fi