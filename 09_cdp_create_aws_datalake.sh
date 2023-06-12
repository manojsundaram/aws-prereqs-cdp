#!/bin/bash 
 if ! [ -z ${DEV_CLI+x} ]
then
    shopt -s expand_aliases
    alias cdp="cdp 2>/dev/null"
fi 
#source $(cd $(dirname $0); pwd -L)/common.sh

 display_usage() { 
	echo "
Usage:
    $(basename "$0") <basedir> <prefix> <scale> [--help or -h]

Description:
    Creates a data lake post environment creation

Arguments:
    prefix:         prefix for your assets
    scale:          scale of the datalake (LIGHT_DUTY or MEDIUM_DUTY)
    --help or -h:   displays this help"
}

# check whether user had supplied -h or --help . If yes display usage 
if [[ ( $1 == "--help") ||  $1 == "-h" ]] 
then 
    display_usage
    exit 0
fi 


# Check the numbers of arguments
if [  $# -lt 2 ] 
then 
    echo "Not enough arguments!"  >&2
    display_usage
    exit 1
fi 

if [  $# -gt 2 ] 
then 
    echo "Too many arguments!"  >&2
    display_usage
    exit 1
fi 
sleep_duration=3

AWS_ACCOUNT_ID=`aws sts get-caller-identity --query "Account" --output text`
prefix=$1
DL_SCALE=$2

owner=$(cdp iam get-user | jq -r .user.email)

cdp datalake create-aws-datalake \
    --datalake-name ${prefix}-cdp-dl \
    --environment-name $2-cdp-env \
    --cloud-provider-configuration instanceProfile="arn:aws:iam::${AWS_ACCOUNT_ID}:instance-profile/${prefix}-idbroker-role",storageBucketLocation="s3a://${prefix}-cdp-bucket"  \
    --scale $DL_SCALE \
    --enable-ranger-raz