#!/usr/bin/env bash
set -x
awslocal s3 mb s3://$S3_BUCKET
set +x