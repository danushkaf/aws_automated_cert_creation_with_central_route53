#!/bin/bash
export AWS_ACCESS_KEY_ID=
export AWS_SECRET_ACCESS_KEY=
export AWS_SESSION_TOKEN=
ACC=$1
temp_role=$(aws sts assume-role --role-arn "arn:aws:iam::$ACC:role/AWSControlTowerExecution" --role-session-name "userAct-$ACC")
export AWS_ACCESS_KEY_ID=$(echo $temp_role | jq .Credentials.AccessKeyId | xargs)
export AWS_SECRET_ACCESS_KEY=$(echo $temp_role | jq .Credentials.SecretAccessKey | xargs)
export AWS_SESSION_TOKEN=$(echo $temp_role | jq .Credentials.SessionToken | xargs)
