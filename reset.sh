#!/usr/bin/env bash

. config.sh

set -x
set +x
#confluent flink statement list  --compute-pool $COMPUTE_POOL --environment $ENVIRONMENT --cloud $CLOUD --region $REGION -o json | \
#  jq --raw-output ".[] | select(.statement | test(\"^create function\") | not) | \"confluent flink statement delete \" + .name +\" --environment $ENVIRONMENT --cloud $CLOUD --region $REGION --force &\""  | sh

#  -var artifact_id=$(cat artifact_id.txt) \
terraform destroy -auto-approve -var artifact_version=$(cat artifact_version.txt) \
   -target confluent_flink_statement.ddls1st \
   -target confluent_flink_statement.ddls \
   -target confluent_flink_statement.dmls \
   -target confluent_flink_artifact.xml2json \
   -target confluent_flink_statement.create-xml-to-info \
   -target confluent_flink_statement.create-xml-to-key

terraform apply -var drop_functions=true -auto-approve \
   -target confluent_flink_statement.drop-xml-to-info \
   -target confluent_flink_statement.drop-xml-to-key

curl -u "$SCHEMA_REGISTRY_USER:$SCHEMA_REGISTRY_PASSWORD" \
    $SCHEMA_REGISTRY_URL/subjects | \
    jq --raw-output ".[] |  \"curl -ksv -XDELETE -u '$SCHEMA_REGISTRY_USER:$SCHEMA_REGISTRY_PASSWORD' $SCHEMA_REGISTRY_URL/subjects/\"  + ." | sh

confluent connect cluster list --environment $ENVIRONMENT --cluster $KAFKA_CLUSTER -o json | \
  jq --raw-output ".[].id| \"confluent connect cluster pause --environment $ENVIRONMENT --cluster $KAFKA_CLUSTER \" + . " | sh

confluent kafka topic --environment $ENVIRONMENT --cluster $KAFKA_CLUSTER list -o json | \
  jq --raw-output ".[].name | select ((startswith(\"clcc\") or startswith(\"success\") or startswith(\"dlq\") or startswith(\"error-\"))| not) | \"confluent kafka topic delete --force --environment $ENVIRONMENT --cluster $KAFKA_CLUSTER \"  + ."  | sh


confluent connect cluster list --environment $ENVIRONMENT --cluster $KAFKA_CLUSTER -o json | \
  jq --raw-output ".[].id| \"confluent connect cluster resume --environment $ENVIRONMENT --cluster $KAFKA_CLUSTER \" + . " | sh

terraform apply -target=local_file.get-artifact-version -auto-approve
sleep 5
./artifact-version.sh

terraform apply -auto-approve -var artifact_version=$(cat artifact_version.txt)


