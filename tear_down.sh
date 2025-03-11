#!/usr/bin/env bash

terraform destroy -auto-approve
rm -f artifact.json artifact_version.txt artifact_id.txt

