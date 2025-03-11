#!/usr/bin/env bash
set -e

. ../env
#echo $env_name
#exit

artifact_version=$(cat ../artifact_version.txt)
base64_flink_key_and_secret=$(echo -n "${flink_key}:${flink_secret}" | base64)
#echo $base64_flink_key_and_secret

create_statement(){
  sql_code=$1
  json="{
          \"name\": \"cli-$(uuidgen | tr "[:upper:]" "[:lower:]")\",
          \"organization_id\": \"${org_id}\",
          \"environment_id\": \"${env}\",
          \"spec\": {
            \"statement\": \"${sql_code}\",
            \"compute_pool_id\": \"${compute_pool}\",
            \"stopped\": false
          }
        }"

  echo $json
  curl --request POST -L --fail-with-body \
    --url "https://flink.${region}.${cloud}.confluent.cloud/sql/v1/organizations/${org_id}/environments/${env}/statements" \
    --header "Authorization: Basic ${base64_flink_key_and_secret}" \
    --header 'content-type: application/json' \
    --data "${json}" -ksv
}


create_statement "drop function \`$env_name\`.flights.testme;"
create_statement "drop function \`$env_name\`.flights.xml_to_key;"
create_statement "drop function \`$env_name\`.flights.xml_to_info;"

set +e
artifact_id=$(confluent  flink artifact list  --cloud $cloud --region $region -ojson| \
  jq --raw-output '.[] | select(.name == "xml2json")|.id')

confluent  flink artifact delete  --cloud $cloud --region $region $artifact_id --force
set -e
mvn clean package

response=$(confluent  flink artifact --cloud $cloud --region $region --environment $env create xml2json \
  --artifact-file  target/xml-to-row-udf-1.0.jar -o json  )
artifact_id=$(echo $response | jq --raw-output '.id')
artifact_version=$(echo $response | jq --raw-output '.version')


create_statement "create function \`$env_name\`.flights.testme as 'io.confluent.ek.TestUDF' using jar 'confluent-artifact://$artifact_id/$artifact_version';"
create_statement "create function \`$env_name\`.flights.xml_to_key as 'io.confluent.ek.XmlToFlightinformationKeyUDF' using jar 'confluent-artifact://$artifact_id/$artifact_version';"
create_statement "create function \`$env_name\`.flights.xml_to_info as 'io.confluent.ek.XmlToFlightInformationUDF' using jar 'confluent-artifact://$artifact_id/$artifact_version';"

echo ""

#echo "create function emirates.dcs.xml_to_info as 'io.confluent.ek.XmlToFlightinformationUDF' using jar 'confluent-artifact://$artifact_id/$artifact_version';"
#echo "create function emirates.dcs.xml_to_info as 'io.confluent.ek.XmlToFlightinformationUDF' using jar 'confluent-artifact://$artifact_id/$artifact_version';" |pbc