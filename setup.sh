#!/usr/bin/env bash
set -e
cd xml-to-row-udf-vanilla
mvn clean package
cd ../request-processor-sink
mvn clean package
cd ..
terraform init
terraform apply -target=local_file.get-artifact-version -auto-approve
sleep 5
set -e
./artifact-version.sh
#terraform apply -auto-approve -var artifact_version=$(cat artifact_version.txt) -var artifact_id=$(cat artifact_id.txt)
terraform apply -auto-approve -var artifact_version=$(cat artifact_version.txt)
