#!/bin/bash

primary_account_id=$1
shared_account_id=$2
domain_name=$3
cert_exists=false
existing_cert_arn=""


creteDNSRecord() {
  cert_arn=$1
  sleep 5s && cert_details=$(aws acm describe-certificate --certificate-arn $cert_arn)
  dns_record_name=$(echo $cert_details | jq '.Certificate.DomainValidationOptions[0].ResourceRecord.Name' | xargs)
  dns_record_type=$(echo $cert_details | jq '.Certificate.DomainValidationOptions[0].ResourceRecord.Type' | xargs)
  dns_record_value=$(echo $cert_details | jq '.Certificate.DomainValidationOptions[0].ResourceRecord.Value' | xargs)
  . ./aws_config.sh $shared_account_id
  current_hosted_zones=$(aws route53 list-hosted-zones)
  for k in $(jq '.HostedZones | keys | .[]' <<< "$current_hosted_zones"); do
    hosted_zone=$(jq -r ".HostedZones[$k]" <<< "$current_hosted_zones");
    hosted_zone_id=$(jq -r '.Id' <<< "$hosted_zone");
    hosted_zone_name=$(jq -r '.Name' <<< "$hosted_zone");
    if [[ "$hosted_zone_name" == "${domain_name}." ]]; then
      resource_record_set=$(aws route53 list-resource-record-sets --hosted-zone-id $hosted_zone_id)
      record_set_exists=false
      for j in $(jq '.ResourceRecordSets | keys | .[]' <<< "$resource_record_set"); do
        record_set=$(jq -r ".ResourceRecordSets[$j]" <<< "$resource_record_set");
        record_set_name=$(jq -r '.Name' <<< "$record_set");
        if [[ "$record_set_name" == "$dns_record_name" ]]; then
          record_set_exists=true
          break
        fi
      done
      if [ "$record_set_exists" = true ]; then
        echo "Recordset already created."
      else
        echo "Recordset not created. Creating Recordset."
        cat > record_set_json.json <<EOF
{
  "Changes": [
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "$dns_record_name",
        "Type": "$dns_record_type",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "$dns_record_value"
          }
        ]
      }
    }
  ]
}
EOF
        create_record_set_result=$(aws route53 change-resource-record-sets --hosted-zone-id $hosted_zone_id --change-batch file://record_set_json.json)
      fi
      break
    fi
  done
}

#current_certs=$(aws --profile jenkins acm list-certificates)
. ./aws_config.sh $primary_account_id
current_certs=$(aws acm list-certificates)

for k in $(jq '.CertificateSummaryList | keys | .[]' <<< "$current_certs"); do
  cert=$(jq -r ".CertificateSummaryList[$k]" <<< "$current_certs")
  domain=$(jq -r '.DomainName' <<< "$cert")
  if [[ "$domain" == "$domain_name" ]]; then
    existing_cert_arn=$(jq -r '.CertificateArn' <<< "$cert")
    cert_exists=true
    break
  fi
done
if [ "$cert_exists" = true ]; then
  echo "Cert already created."
  creteDNSRecord $existing_cert_arn
  echo $existing_cert_arn
else
  echo "Cert not created. Creating."
  new_cert=$(aws acm request-certificate --domain-name $domain_name --validation-method DNS --subject-alternative-names *.$domain_name)
  cert_arn=$(echo $new_cert | jq '.CertificateArn' | xargs)
  creteDNSRecord $cert_arn
  echo $cert_arn
fi
