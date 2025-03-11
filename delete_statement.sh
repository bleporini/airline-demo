#!/usr/bin/env bash

confluent flink statement delete $1 --environment env-dvnvyd --cloud aws --region eu-west-1 --force
