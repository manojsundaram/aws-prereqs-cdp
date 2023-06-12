#!/bin/bash 
 if ! [ -z ${DEV_CLI+x} ]
then
    shopt -s expand_aliases
    alias cdp="cdp 2>/dev/null"
fi 


 display_usage() { 
	echo "
Usage:
    $(basename "$0") <prefix> <AWS_ACCOUNT_ID> [--help or -h]

Description:
    Creates the appropriate groups for recently create env

Arguments:
    prefix:         prefix for your assets
    --help or -h:   displays this help"

}

# check whether user had supplied -h or --help . If yes display usage 
if [[ ( $1 == "--help") ||  $1 == "-h" ]] 
then 
    display_usage
    exit 0
fi 


# Check the numbers of arguments
if [  $# -lt 1 ] 
then 
    echo "Not enough arguments!" >&2
    display_usage
    exit 1
fi 

if [  $# -gt 1 ] 
then 
    echo "Too many arguments!" >&2
    display_usage
    exit 1
fi 
sleep_duration=3 

prefix=$1
AWS_ACCOUNT_ID=`aws sts get-caller-identity --query "Account" --output text`

env_crn=$(cdp environments describe-environment --environment-name $2-cdp-env | jq -r .environment.crn)
user_crn=$(cdp iam get-user | jq -r .user.crn)

# Create IDBroker mappings
cdp environments set-id-broker-mappings \
    --environment-name "${prefix}-cdp-env" \
    --data-access-role "arn:aws:iam::$AWS_ACCOUNT_ID:role/${prefix}-datalake-admin-role" \
    --ranger-audit-role "arn:aws:iam::$AWS_ACCOUNT_ID:role/${prefix}-ranger-audit-role" \
    --ranger-cloud-access-authorizer-role "arn:aws:iam::$AWS_ACCOUNT_ID:role/${prefix}-datalake-admin-role" \
    --mappings accessorCrn=$user_crn,role="arn:aws:iam::$AWS_ACCOUNT_ID:role/${prefix}-datalake-admin-role"