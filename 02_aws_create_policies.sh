#!/bin/bash 
 if ! [ -z ${DEV_CLI+x} ]
then
    shopt -s expand_aliases
    alias cdp="cdp 2>/dev/null"
fi 
set -o nounset
BASE_DIR=$(cd $(dirname $0); pwd -L)

display_usage() { 
    echo "
Usage:
    $(basename "$0") [--help or -h] <prefix> 

Description:
    Creates minimal set of policies for CDP env

Arguments:
    prefix:   prefix for your policies
    --help or -h:   displays this help"

}

# check whether user had supplied -h or --help . If yes display usage 
if [[ ( ${1:-x} == "--help") ||  ${1:-x} == "-h" ]] 
then 
    display_usage
    exit 0
fi 


# Check the numbers of arguments
if [  $# -lt 1 ] 
then 
    echo "Not enough arguments!"  >&2
    display_usage
    exit 1
fi 

if [  $# -gt 1 ] 
then 
    echo "Too many arguments!"  >&2
    display_usage
    exit 1
fi 

prefix=$1
bucket=${prefix}-cdp-bucket


AWS_ACCOUNT_ID=$(aws sts get-caller-identity | jq .Account -r)
DATALAKE_BUCKET=${bucket}
# STORAGE_LOCATION_BASE=${bucket}'\/'${prefix}'\-dl'
LOGS_BUCKET=${bucket}
STORAGE_LOCATION_BASE=${bucket}
# LOGS_LOCATION_BASE=${bucket}
LOGS_LOCATION_BASE=${bucket}'\/'${prefix}'\-dl\/logs'
BACKUP_LOCATION_BASE=${STORAGE_LOCATION_BASE}
echo "BACKUP_LOCATION_BASE"
echo $BACKUP_LOCATION_BASE
RESTORE_LOCATION_BASE=${STORAGE_LOCATION_BASE}
echo "RESTORE_LOCATION_BASE"
echo $RESTORE_LOCATION_BASE
sleep_duration=3


# Creating policies (and sleeping in between)

###### IDBROKER_ROLE
# aws-cdp-idbroker-assume-role-policy
aws iam create-policy --policy-name ${prefix}-idbroker-assume-role-policy --policy-document file://${BASE_DIR}/access-policies/aws-cdp-idbroker-assume-role-policy.json 
sleep $sleep_duration 

# aws-cdp-log-policy
cat ${BASE_DIR}/access-policies/aws-cdp-log-policy.json | sed s/\${LOGS_BUCKET}/"${LOGS_BUCKET}"/g| sed s/\${LOGS_LOCATION_BASE}/"${LOGS_LOCATION_BASE}"/g > ${BASE_DIR}/${prefix}_tmp
aws iam create-policy --policy-name ${prefix}-log-policy --policy-document file://${BASE_DIR}/${prefix}_tmp
sleep $sleep_duration 

###### RANGER_AUDIT_ROLE
cat ${BASE_DIR}/access-policies/aws-cdp-ranger-audit-s3-policy.json | sed s/\${STORAGE_LOCATION_BASE}/"${STORAGE_LOCATION_BASE}"/g | sed s/\${DATALAKE_BUCKET}/"${DATALAKE_BUCKET}"/g > ${BASE_DIR}/${prefix}_tmp
aws iam create-policy --policy-name ${prefix}-ranger-audit-s3-policy --policy-document file://${BASE_DIR}/${prefix}_tmp
sleep $sleep_duration 

cat ${BASE_DIR}/access-policies/aws-cdp-bucket-access-policy.json  | sed s/\${DATALAKE_BUCKET}/"${DATALAKE_BUCKET}"/g > ${BASE_DIR}/${prefix}_tmp
aws iam create-policy --policy-name ${prefix}-bucket-access-policy --policy-document file://${BASE_DIR}/${prefix}_tmp
sleep $sleep_duration  

# Might get errors here
cat ${BASE_DIR}/access-policies/aws-datalake-backup-policy.json  | sed s/\${BACKUP_LOCATION_BASE}/"${BACKUP_LOCATION_BASE}"/g > ${BASE_DIR}/${prefix}_tmp
aws iam create-policy --policy-name ${prefix}-datalake-backup-policy --policy-document file://${BASE_DIR}/${prefix}_tmp
sleep $sleep_duration  

cat ${BASE_DIR}/access-policies/aws-datalake-restore-policy.json  | sed s/\${RESTORE_LOCATION_BASE}/"${RESTORE_LOCATION_BASE}"/g > ${BASE_DIR}/${prefix}_tmp
aws iam create-policy --policy-name ${prefix}-datalake-restore-policy --policy-document file://${BASE_DIR}/${prefix}_tmp
sleep $sleep_duration  


###### LOG_ROLE
# aws-cdp-log-policy already created above
# aws-datalake-restore-policy already created above
# aws-cdp-backup-policy (Optional)
cat  ${BASE_DIR}/access-policies/aws-cdp-backup-policy.json | sed s/\${BACKUP_LOCATION_BASE}/"${BACKUP_LOCATION_BASE}"/g  > ${BASE_DIR}/${prefix}_tmp
aws iam create-policy --policy-name ${prefix}-backup-policy --policy-document file://${BASE_DIR}/${prefix}_tmp
sleep $sleep_duration 


###### DATALAKE_ADMIN_ROLE

cat  ${BASE_DIR}/access-policies/aws-cdp-datalake-admin-s3-policy.json | sed s/\${STORAGE_LOCATION_BASE}/"${STORAGE_LOCATION_BASE}"/g  > ${BASE_DIR}/${prefix}_tmp
aws iam create-policy --policy-name ${prefix}-datalake-admin-s3-policy --policy-document file://${BASE_DIR}/${prefix}_tmp
sleep $sleep_duration 

# aws-cdp-bucket-access-policy created above
# aws-datalake-backup-policy created above
# aws-datalake-restore-policy created above

rm ${BASE_DIR}/${prefix}_tmp

echo "Policies created!"
