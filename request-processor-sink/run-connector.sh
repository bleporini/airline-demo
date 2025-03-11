#!/usr/bin/env bash

set -e

./mvnw clean package

docker run -ti --rm \
  -v $(pwd)/target/kafka-connect-request-processor-sink-0.7.0-SNAPSHOT.jar:/jars/kafka-connect-request-processor-sink-0.7.0-SNAPSHOT.jar \
    -v $(pwd):/config \
    -p8083:8083 \
    confluentinc/cp-kafka-connect /usr/bin/connect-standalone /config/worker.properties /config/connector.properties