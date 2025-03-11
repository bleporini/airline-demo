terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "2.13.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
data "confluent_organization" "main" {}

resource "random_id" "id" {
  byte_length = 4
}

provider "confluent" {
  cloud_api_key       = var.confluent_cloud_api_key
  cloud_api_secret    = var.confluent_cloud_api_secret
}

resource "confluent_environment" "carrier" {
  display_name = "carrier_${random_id.id.id}"

  stream_governance {
    package = "ESSENTIALS"
  }
}

resource "confluent_kafka_cluster" "basic" {
  display_name = "flights"
  availability = "SINGLE_ZONE"
  cloud        = var.cloud
  region       = var.region
  basic {}

  environment {
    id = confluent_environment.carrier.id
  }
}

resource "confluent_flink_compute_pool" "main" {
  display_name     = "standard_compute_pool"
  cloud            = var.cloud
  region           = var.region
  max_cfu          = 20
  environment {
    id = confluent_environment.carrier.id
  }
/*
  provisioner "local-exec" {
    command = "confluent flink artifact create xml-to-json --artifact-file ${path.module}/xml-to-row-udf/target/xml-to-row-udf-1.0.jar --cloud ${var.cloud} --region ${var.region} --environment ${confluent_environment.carrier.id}"
  }
*/
}

data "confluent_flink_region" "carrier" {
  cloud   = confluent_flink_compute_pool.main.cloud
  region  = confluent_flink_compute_pool.main.region
}

resource "confluent_service_account" "app-manager" {
  display_name = "app-manager-${random_id.id.id}"
  description  = "Service account to manage Carrier demo resources"

}


resource "confluent_role_binding" "app-manager-flink-developer" {
  principal   = "User:${confluent_service_account.app-manager.id}"
  role_name   = "FlinkDeveloper"
  crn_pattern = confluent_environment.carrier.resource_name
}

resource "confluent_service_account" "statements-runner" {
  display_name = "statements-runner-${random_id.id.id}"
  description  = "Service account for running Flink Statements in Carrier cluster"
}
resource "confluent_role_binding" "statements-runner-env-admin" {
  principal   = "User:${confluent_service_account.statements-runner.id}"
  role_name   = "EnvironmentAdmin"
  crn_pattern = confluent_environment.carrier.resource_name
}
resource "confluent_role_binding" "app-manager-assigner" {
  principal   = "User:${confluent_service_account.app-manager.id}"
  role_name   = "Assigner"
  crn_pattern = "${data.confluent_organization.main.resource_name}/service-account=${confluent_service_account.statements-runner.id}"
}

resource "confluent_role_binding" "app-manager-kafka-cluster-admin" {
  principal   = "User:${confluent_service_account.app-manager.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.basic.rbac_crn
}

resource "confluent_role_binding" "app-manager-sr-manage" {
  principal   = "User:${confluent_service_account.app-manager.id}"
  role_name   = "ResourceOwner"
  crn_pattern = "${data.confluent_schema_registry_cluster.sr.resource_name}/subject=*"
}


resource "confluent_api_key" "app-manager-flink-api-key" {
  display_name = "app-manager-kafka-api-key"
  description  = "Kafka API Key that is owned by 'app-manager' service account"
  owner {
    id          = confluent_service_account.app-manager.id
    api_version = confluent_service_account.app-manager.api_version
    kind        = confluent_service_account.app-manager.kind
  }

  managed_resource {
    id          = data.confluent_flink_region.carrier.id
    api_version = data.confluent_flink_region.carrier.api_version
    kind        = data.confluent_flink_region.carrier.kind

    environment {
      id = confluent_environment.carrier.id
    }
  }
}

resource "confluent_api_key" "app-manager-kafka-api-key" {
  display_name = "app-manager-kafka-api-key"
  description  = "Kafka API Key that is owned by 'app-manager' service account"
  owner {
    id          = confluent_service_account.app-manager.id
    api_version = confluent_service_account.app-manager.api_version
    kind        = confluent_service_account.app-manager.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.basic.id
    api_version = confluent_kafka_cluster.basic.api_version
    kind        = confluent_kafka_cluster.basic.kind

    environment {
      id = confluent_environment.carrier.id
    }
  }
}


resource "confluent_flink_artifact" "xml2json" {
  class          = "io.confluent.ek.vanilla.XmlToFlightInformation2UDF"
  artifact_file  = "${path.module}/xml-to-row-udf-vanilla/target/xml-to-row-udf-vanilla-1.0.jar"
  region         = var.region
  cloud          = var.cloud
  display_name   = "xml-to-json"
  content_format = "JAR"
  environment {
    id = confluent_environment.carrier.id
  }
}

/*
resource "local_file" "get-artifact-version" {
  filename = "artifact-version.sh"
  content = <<-EOF
#!/usr/bin/env bash
set -e
confluent flink artifact list --cloud ${var.cloud} --region ${var.region} --environment ${confluent_environment.carrier.id} -o json | jq '"confluent flink artifact describe --cloud ${var.cloud} --region ${var.region} --environment ${confluent_environment.carrier.id} -o json " + .[0].id' --raw-output | sh > artifact.json
cat artifact.json | jq --raw-output '.version' > artifact_version.txt
cat artifact.json | jq --raw-output '.id' > artifact_id.txt
EOF
  file_permission = "700"

  depends_on = [
//    confluent_flink_artifact.xml2json
    confluent_flink_compute_pool.main
  ]
}
*/
resource "local_file" "get-artifact-version" {
  filename = "artifact-version.sh"
  content = <<-EOF
#!/usr/bin/env bash
set -e
confluent flink artifact describe --environment ${confluent_environment.carrier.id}  --cloud ${var.cloud} --region ${var.region} ${confluent_flink_artifact.xml2json.id} -o json > artifact.json
file_content=$(cat artifact.json)

if [ -z "$file_content" ]; then
  echo "Error: artifact.json is empty"
  exit -1
fi

cat artifact.json | jq --raw-output '.version' > artifact_version.txt
EOF
  file_permission = "700"

  depends_on = [
    confluent_flink_artifact.xml2json,
    confluent_environment.carrier
  ]
}

/*
resource "confluent_custom_connector_plugin" "http" {
  # https://docs.confluent.io/cloud/current/connectors/bring-your-connector/custom-connector-qs.html#custom-connector-quick-start
  display_name                = "HTTP request processor"
  connector_class             = "io.confluent.ek.RestApiSinkConnector"
  connector_type              = "SINK"
  sensitive_config_properties = []
  filename                    = "${path.module}/request-processor-sink/target/kafka-connect-request-processor-sink-1.0.jar"
}
*/

/*
resource "confluent_kafka_topic" "dlq" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  topic_name         = "dlq"
  rest_endpoint      = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-kafka-api-key.id
    secret = confluent_api_key.app-manager-kafka-api-key.secret
  }
  depends_on = [
    confluent_role_binding.app-manager-kafka-cluster-admin
  ]
}
*/

/*
resource "confluent_connector" "passport" {
  environment {
    id = confluent_environment.carrier.id
  }
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }

  config_sensitive = {
    "kafka.api.key"    = confluent_api_key.app-manager-kafka-api-key.id
    "kafka.api.secret" = confluent_api_key.app-manager-kafka-api-key.secret
  }

  config_nonsensitive = {
    "connector.class"          = confluent_custom_connector_plugin.http.connector_class
    "name"                     = "Passports request connector"
    "kafka.auth.mode"          = "KAFKA_API_KEY"
    "kafka.service.account.id" = confluent_service_account.app-manager.id
    "bootstrap.servers"        = replace(confluent_kafka_cluster.basic.bootstrap_endpoint, "SASL_SSL://", "")
    "errors.deadletterqueue.topic.name" = confluent_kafka_topic.dlq.topic_name
    "errors.tolerance"                  = "all"
    "key.converter"                     = "org.apache.kafka.connect.converters.ByteArrayConverter"
    "key.serializer"                    = "org.apache.kafka.common.serialization.ByteArraySerializer"
    "responseTopic"                     = "responseTopic"
    "sasl.jaas.config"                  = "org.apache.kafka.common.security.plain.PlainLoginModule required username='${confluent_api_key.app-manager-kafka-api-key.id}' password='${confluent_api_key.app-manager-kafka-api-key.secret}';"
    "sasl.mechanism"                    = "PLAIN"
    "security.protocol"                 = "SASL_SSL"
    "topics"                            = "requestTopic"
    "value.converter"                   = "org.apache.kafka.connect.converters.ByteArrayConverter"
    "value.serializer"                  = "org.apache.kafka.common.serialization.StringSerializer"
    "confluent.custom.plugin.id"        = confluent_custom_connector_plugin.http.id
    "confluent.resource.connector.tier" = "2GB"
    "confluent.custom.plugin.type"      = "SINK"
    "confluent.custom.connection.endpoints" = "${aws_lambda_function_url.carrier-api-url.url_id}.lambda-url.${var.region}.on.aws:443:TCP"
    "tasks.max"                = "1"
  }

  depends_on = [
    confluent_custom_connector_plugin.http,
    confluent_service_account.app-manager,
    confluent_api_key.app-manager-flink-api-key,
    confluent_kafka_topic.dlq,
    aws_lambda_function_url.carrier-api-url
  ]

}
*/
resource "confluent_connector" "passportv2" {
  environment {
    id = confluent_environment.carrier.id
  }
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }

  config_sensitive = {
    "kafka.api.key"    = confluent_api_key.app-manager-kafka-api-key.id
    "kafka.api.secret" = confluent_api_key.app-manager-kafka-api-key.secret
  }

  config_nonsensitive = {
    "name"                              = "Passport API"
    "connector.class"                   = "HttpSinkV2"
    "input.data.format"                 = "JSON_SR"
    "topics"                            = "passport_requests"
    "kafka.auth.mode"                    = "KAFKA_API_KEY"
    "http.api.base.url"                  = aws_lambda_function_url.carrier-api-url.function_url
    "https.ssl.enabled"                  = "false"
    "apis.num"                          = "1"
    "api1.http.api.path"                 = "/passport"
    "api1.http.request.method"           = "POST"
    "api1.topics"                        = "passport_requests"
    "api1.http.request.headers"          = "content-type:application/json"
    "api1.http.request.sensitive.headers" = ""
    "api1.http.request.parameters"       = ""
    "api1.http.path.parameters"          = ""
    "api1.http.request.body"             = ""
    "api1.http.connect.timeout.ms"       = "30000"
    "api1.http.request.timeout.ms"       = "30000"
    "api1.retry.backoff.ms"              = "3000"
    "api1.max.retries"                   = "5"
    "api1.retry.on.status.codes"        = "400-"
    "api1.retry.backoff.policy"         = "EXPONENTIAL_WITH_JITTER"
    "api1.test.api"                     = "false"
    "api1.behavior.on.null.values"      = "ignore"
    "api1.request.body.format"           = "json"
    "api1.batch.key.pattern"            = ""
    "api1.max.batch.size"                = "1"
    "api1.batch.json.as.array"           = "false"
    "api1.batch.separator"              = ""
    "schema.context.name"                = "default"
    "behavior.on.error"                  = "FAIL"
    "report.errors.as"                   = "ERROR_STRING"
    "max.poll.interval.ms"              = "300000"
    "max.poll.records"                  = "500"
    "value.subject.name.strategy"        = "TopicNameStrategy"
    "csfle.enabled"                      = "false"
    "tasks.max"                          = "1"
  }
  depends_on = [
    confluent_flink_statement.ddls1st,
    confluent_service_account.app-manager,
    confluent_api_key.app-manager-flink-api-key,
    aws_lambda_function_url.carrier-api-url
  ]

}

resource "confluent_flink_statement" "ddls1st" {
  for_each = var.ddls1st

  compute_pool {
    id = confluent_flink_compute_pool.main.id
  }
  principal {
    id = confluent_service_account.statements-runner.id
  }
  organization {
    id = data.confluent_organization.main.id
  }
  environment {
    id = confluent_environment.carrier.id
  }
  statement  = each.value
  statement_name = each.key

  properties = {
    "sql.current-catalog"  = confluent_environment.carrier.display_name
    "sql.current-database" = confluent_kafka_cluster.basic.display_name
  }
  rest_endpoint   = data.confluent_flink_region.carrier.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-flink-api-key.id
    secret = confluent_api_key.app-manager-flink-api-key.secret
  }

  depends_on = [
    confluent_role_binding.app-manager-flink-developer
  ]
}
resource "confluent_flink_statement" "ddls" {
  for_each = var.ddls

  compute_pool {
    id = confluent_flink_compute_pool.main.id
  }
  principal {
    id = confluent_service_account.statements-runner.id
  }
  organization {
    id = data.confluent_organization.main.id
  }
  environment {
    id = confluent_environment.carrier.id
  }
  statement  = each.value
  statement_name = each.key

  properties = {
    "sql.current-catalog"  = confluent_environment.carrier.display_name
    "sql.current-database" = confluent_kafka_cluster.basic.display_name
  }
  rest_endpoint   = data.confluent_flink_region.carrier.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-flink-api-key.id
    secret = confluent_api_key.app-manager-flink-api-key.secret
  }

  depends_on = [
    confluent_flink_statement.ddls1st,
    confluent_role_binding.app-manager-flink-developer
  ]
}
resource "confluent_flink_statement" "dmls" {
  for_each = var.dmls

  compute_pool {
    id = confluent_flink_compute_pool.main.id
  }
  principal {
    id = confluent_service_account.statements-runner.id
  }
  organization {
    id = data.confluent_organization.main.id
  }
  environment {
    id = confluent_environment.carrier.id
  }
  statement  = each.value

  properties = {
    "sql.current-catalog"  = confluent_environment.carrier.display_name
    "sql.current-database" = confluent_kafka_cluster.basic.display_name
  }
  rest_endpoint   = data.confluent_flink_region.carrier.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-flink-api-key.id
    secret = confluent_api_key.app-manager-flink-api-key.secret
  }

  depends_on = [
    confluent_role_binding.app-manager-flink-developer,
    confluent_flink_statement.ddls1st,
    confluent_flink_statement.ddls,
    confluent_flink_statement.create-xml-to-info,
    confluent_flink_statement.create-xml-to-key
  ]
}
resource "confluent_flink_statement" "generate-passport-requests" {

  statement= <<-EOT
insert into passport_requests
select
    p.*
from checkin_open_events c join passengers p on c.key = p.flight_id
where p.deleted <> true and p.details_completed <> true;
EOT
/*
  statement= <<-EOT
insert into requestTopic
select
    row(p.flight_id,p.key),
    cast (
        json_object(
            'url' value '${aws_lambda_function_url.carrier-api-url.function_url}?reference=' || p.key,
            'value' value json_object(
                'name' value p.name ,
                'date_of_birth' value p.date_of_birth ,
                'passport_number' value p.passport_number ,
                'seat_number' value p.seat_number ,
                'class' value p.class,
                'deleted' value p.deleted
            )
        )as bytes),
    map[
      'origin', 'genereate request query',
      'ts_from_checkin_open_events', cast(c.ts as string)
    ] as `headers`
from checkin_open_events c join passengers p on c.key = p.flight_id
where p.deleted <> true and p.details_completed <> true;
EOT
*/
  compute_pool {
    id = confluent_flink_compute_pool.main.id
  }
  principal {
    id = confluent_service_account.statements-runner.id
  }
  organization {
    id = data.confluent_organization.main.id
  }
  environment {
    id = confluent_environment.carrier.id
  }

  properties = {
    "sql.current-catalog"  = confluent_environment.carrier.display_name
    "sql.current-database" = confluent_kafka_cluster.basic.display_name
  }
  rest_endpoint   = data.confluent_flink_region.carrier.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-flink-api-key.id
    secret = confluent_api_key.app-manager-flink-api-key.secret
  }

  depends_on = [
    confluent_role_binding.app-manager-flink-developer,
    confluent_flink_statement.ddls1st,
    confluent_flink_statement.ddls
  ]
}

resource "confluent_flink_statement" "passport-responses" {

  statement= <<-EOT
insert into passengers
with r as (
    select
        replace(cast (key as string), '"', '') as key,
        json_value(cast (val as string), '$') as json
    from `success-${confluent_connector.passportv2.id}`
)
select
    key,
    json_value(json, '$.flight_id') as flight_id,
    json_value(json, '$.name') as name,
    json_value(json, '$.date_of_birth') as date_of_birth ,
    json_value(json, '$.passport_number') as passport_number ,
    json_value(json, '$.seat_number') as seat_number ,
    json_value(json, '$.class') as class ,
    lower(json_value(json, '$.deleted')) = 'true' as deleted,
    true as details_completed,
    map[
      'origin', 'passport query2'

    ] as `headers`
from r;
EOT
  compute_pool {
    id = confluent_flink_compute_pool.main.id
  }
  principal {
    id = confluent_service_account.statements-runner.id
  }
  organization {
    id = data.confluent_organization.main.id
  }
  environment {
    id = confluent_environment.carrier.id
  }

  properties = {
    "sql.current-catalog"  = confluent_environment.carrier.display_name
    "sql.current-database" = confluent_kafka_cluster.basic.display_name
  }
  rest_endpoint   = data.confluent_flink_region.carrier.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-flink-api-key.id
    secret = confluent_api_key.app-manager-flink-api-key.secret
  }

  depends_on = [
    confluent_role_binding.app-manager-flink-developer,
    confluent_flink_statement.ddls1st,
    confluent_flink_statement.ddls,
    confluent_connector.passportv2
  ]
}


resource "confluent_flink_statement" "generate-sufficient-meals" {

  statement=templatefile("${path.module}/generate-sufficient-meals.tfpl",
    {
      meal_economy_threshold = var.meal_economy_threshold,
      meal_first_threshold = var.meal_first_threshold,
      meal_business_threshold = var.meal_business_threshold,
      meal_premium_threshold = var.meal_premium_threshold
    }
  )

  compute_pool {
    id = confluent_flink_compute_pool.main.id
  }
  principal {
    id = confluent_service_account.statements-runner.id
  }
  organization {
    id = data.confluent_organization.main.id
  }
  environment {
    id = confluent_environment.carrier.id
  }

  properties = {
    "sql.current-catalog"  = confluent_environment.carrier.display_name
    "sql.current-database" = confluent_kafka_cluster.basic.display_name
  }
  rest_endpoint   = data.confluent_flink_region.carrier.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-flink-api-key.id
    secret = confluent_api_key.app-manager-flink-api-key.secret
  }

  depends_on = [
    confluent_role_binding.app-manager-flink-developer,
    confluent_flink_statement.ddls1st,
    confluent_flink_statement.ddls
  ]
}

resource "confluent_flink_statement" "create-xml-to-key"{
  statement=    "create or replace function `${confluent_environment.carrier.display_name}`.${confluent_kafka_cluster.basic.display_name}.xml_to_key as 'io.confluent.ek.vanilla.XmlToFlightinformationKeyUDF2' using jar 'confluent-artifact://${confluent_flink_artifact.xml2json.id}/${var.artifact_version}';"
//  statement=    "create function `${confluent_environment.carrier.display_name}`.${confluent_kafka_cluster.basic.display_name}.xml_to_key as 'io.confluent.ek.vanilla.XmlToFlightinformationKeyUDF2' using jar 'confluent-artifact://${var.artifact_id}/${var.artifact_version}';"

  compute_pool {
    id = confluent_flink_compute_pool.main.id
  }
  principal {
    id = confluent_service_account.statements-runner.id
  }
  organization {
    id = data.confluent_organization.main.id
  }
  environment {
    id = confluent_environment.carrier.id
  }

  properties = {
    "sql.current-catalog"  = confluent_environment.carrier.display_name
    "sql.current-database" = confluent_kafka_cluster.basic.display_name
  }
  rest_endpoint   = data.confluent_flink_region.carrier.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-flink-api-key.id
    secret = confluent_api_key.app-manager-flink-api-key.secret
  }

  depends_on = [
    confluent_flink_artifact.xml2json,
    confluent_role_binding.app-manager-flink-developer /*,
    confluent_flink_statement.ddls1st,
    confluent_flink_statement.ddls*/
  ]


}
resource "confluent_flink_statement" "drop-xml-to-key"{
  statement=    "drop function `${confluent_environment.carrier.display_name}`.${confluent_kafka_cluster.basic.display_name}.xml_to_key;"

  count = var.drop_functions ? 1: 0
  compute_pool {
    id = confluent_flink_compute_pool.main.id
  }
  principal {
    id = confluent_service_account.statements-runner.id
  }
  organization {
    id = data.confluent_organization.main.id
  }
  environment {
    id = confluent_environment.carrier.id
  }

  properties = {
    "sql.current-catalog"  = confluent_environment.carrier.display_name
    "sql.current-database" = confluent_kafka_cluster.basic.display_name
  }
  rest_endpoint   = data.confluent_flink_region.carrier.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-flink-api-key.id
    secret = confluent_api_key.app-manager-flink-api-key.secret
  }

  depends_on = [
    confluent_role_binding.app-manager-flink-developer
  ]


}

resource "confluent_flink_statement" "create-xml-to-info"{
  statement="create or replace function `${confluent_environment.carrier.display_name}`.${confluent_kafka_cluster.basic.display_name}.xml_to_info as 'io.confluent.ek.vanilla.XmlToFlightInformation2UDF' using jar 'confluent-artifact://${confluent_flink_artifact.xml2json.id}/${var.artifact_version}';"
//  statement="create function `${confluent_environment.carrier.display_name}`.${confluent_kafka_cluster.basic.display_name}.xml_to_info as 'io.confluent.ek.vanilla.XmlToFlightInformation2UDF' using jar 'confluent-artifact://${var.artifact_id}/${var.artifact_version}';"

  compute_pool {
    id = confluent_flink_compute_pool.main.id
  }
  principal {
    id = confluent_service_account.statements-runner.id
  }
  organization {
    id = data.confluent_organization.main.id
  }
  environment {
    id = confluent_environment.carrier.id
  }

  properties = {
    "sql.current-catalog"  = confluent_environment.carrier.display_name
    "sql.current-database" = confluent_kafka_cluster.basic.display_name
  }
  rest_endpoint   = data.confluent_flink_region.carrier.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-flink-api-key.id
    secret = confluent_api_key.app-manager-flink-api-key.secret
  }

  depends_on = [
    confluent_flink_artifact.xml2json,
    confluent_role_binding.app-manager-flink-developer
  ]


}
resource "confluent_flink_statement" "drop-xml-to-info"{
  statement="drop function `${confluent_environment.carrier.display_name}`.${confluent_kafka_cluster.basic.display_name}.xml_to_info;"
  count = var.drop_functions ? 1: 0

  compute_pool {
    id = confluent_flink_compute_pool.main.id
  }
  principal {
    id = confluent_service_account.statements-runner.id
  }
  organization {
    id = data.confluent_organization.main.id
  }
  environment {
    id = confluent_environment.carrier.id
  }

  properties = {
    "sql.current-catalog"  = confluent_environment.carrier.display_name
    "sql.current-database" = confluent_kafka_cluster.basic.display_name
  }
  rest_endpoint   = data.confluent_flink_region.carrier.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-flink-api-key.id
    secret = confluent_api_key.app-manager-flink-api-key.secret
  }

  depends_on = [
    confluent_flink_artifact.xml2json,
    confluent_role_binding.app-manager-flink-developer
  ]


}

resource "confluent_flink_statement" "generate-alert-attempts" {
  statement=templatefile("${path.module}/generate-alert-attempts.tfpl",
    {
      meal_economy_threshold = var.meal_economy_threshold,
      meal_first_threshold = var.meal_first_threshold,
      meal_business_threshold = var.meal_business_threshold,
      meal_premium_threshold = var.meal_premium_threshold
    }
  )


  compute_pool {
    id = confluent_flink_compute_pool.main.id
  }
  principal {
    id = confluent_service_account.statements-runner.id
  }
  organization {
    id = data.confluent_organization.main.id
  }
  environment {
    id = confluent_environment.carrier.id
  }

  properties = {
    "sql.current-catalog"  = confluent_environment.carrier.display_name
    "sql.current-database" = confluent_kafka_cluster.basic.display_name
  }
  rest_endpoint   = data.confluent_flink_region.carrier.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-flink-api-key.id
    secret = confluent_api_key.app-manager-flink-api-key.secret
  }

  depends_on = [
    confluent_role_binding.app-manager-flink-developer,
    confluent_flink_statement.ddls1st,
    confluent_flink_statement.ddls
  ]
}


resource "local_file" "config" {
  filename = "env"
  content = <<-EOF
region=${var.region}
cloud=${var.cloud}
org_id=${data.confluent_organization.main.id}
env=${confluent_environment.carrier.id}
env_name=${confluent_environment.carrier.display_name}
compute_pool=${confluent_flink_compute_pool.main.id}
flink_key=${confluent_api_key.app-manager-flink-api-key.id}
flink_secret=${confluent_api_key.app-manager-flink-api-key.secret}
EOF
  /*
artifact_id=${confluent_flink_artifact.xml2json.id}
*/
}

data "confluent_schema_registry_cluster" "sr" {
  environment {
    id = confluent_environment.carrier.id
  }
  depends_on = [
    confluent_kafka_cluster.basic
  ]
}

resource "confluent_api_key" "app-manager-schema-registry-api-key" {
  display_name = "app-manager-schema-registry-api-key"
  description  = "Schema Registry API Key that is owned by 'app-manager' service account"
  owner {
    id          = confluent_service_account.app-manager.id
    api_version = confluent_service_account.app-manager.api_version
    kind        = confluent_service_account.app-manager.kind
  }

  managed_resource {
    id          = data.confluent_schema_registry_cluster.sr.id
    api_version = data.confluent_schema_registry_cluster.sr.api_version
    kind        = data.confluent_schema_registry_cluster.sr.kind

    environment {
      id = confluent_environment.carrier.id
    }
  }
}


resource "local_file" "web-config"{
  filename = "${path.cwd}/web-ui/src/main/resources/cc.properties"
  content = <<-EOT
# Kafka
bootstrap.servers=${replace(confluent_kafka_cluster.basic.bootstrap_endpoint, "SASL_SSL://", "")}
security.protocol=SASL_SSL
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="${confluent_api_key.app-manager-kafka-api-key.id}" password="${confluent_api_key.app-manager-kafka-api-key.secret}";
ssl.endpoint.identification.algorithm=https
sasl.mechanism=PLAIN
num.partitions=6
replication.factor=3

# Schema Registry
schema.registry.url=${data.confluent_schema_registry_cluster.sr.rest_endpoint}
schema.registry.basic.auth.user.info=${confluent_api_key.app-manager-schema-registry-api-key.id}:${confluent_api_key.app-manager-schema-registry-api-key.secret}

basic.auth.credentials.source=USER_INFO

group.id=web-ui-consumer

# Topics names
passport_responses.topic=success-${confluent_connector.passportv2.id}

  EOT
}

resource "local_file" "shell-props"{
  filename = "config.sh"
  content= <<-EOT
COMPUTE_POOL=${confluent_flink_compute_pool.main.id}
ENVIRONMENT=${confluent_environment.carrier.id}
CLOUD=${var.cloud}
REGION=${var.region}
SCHEMA_REGISTRY_URL=${data.confluent_schema_registry_cluster.sr.rest_endpoint}
SCHEMA_REGISTRY_USER=${confluent_api_key.app-manager-schema-registry-api-key.id}
SCHEMA_REGISTRY_PASSWORD=${confluent_api_key.app-manager-schema-registry-api-key.secret}
KAFKA_CLUSTER=${confluent_kafka_cluster.basic.id}
EOT
}

resource "local_file" "flink-shell"{
  filename = "flink-shell.sh"
  file_permission = "777"
  depends_on = [
    confluent_flink_compute_pool.main
  ]
  content= <<-EOT
confluent flink shell --compute-pool ${confluent_flink_compute_pool.main.id} --environment ${confluent_environment.carrier.id}
EOT
}


