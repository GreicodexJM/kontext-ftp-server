#!/bin/bash
SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
#dotenv
if [ -f .env ]; then
  set -a
  source .env
  set +a
fi

CUSTOMER_AWS_ACCOUNT="${CUSTOMER_AWS_ACCOUNT:-0000000000000000}"
CUSTOMER_ROLE="${CUSTOMER_ROLE:-greicodex-service-provider-role}"
CUSTOMER_PROJECT="${CUSTOMER_NAME:-customer}"
CUSTOMER_WORKSPACE="${CUSTOMER_WORKSPACE:-tf_infra}"
export AWS_REGION="${AWS_REGION:-us-west-2}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-west-2}"

cat <<EOT > $SCRIPTPATH/credentials.tfvars
do_access_key="${AWS_ACCESS_KEY_ID}"
do_secret_key="${AWS_SECRET_ACCESS_KEY}"
do_token="${AWS_SESSION_TOKEN}"
do_region="${AWS_REGION}"
project="${CUSTOMER_PROJECT}"
workspace="${CUSTOMER_WORKSPACE}"

EOT

alias aws='docker run --rm -it -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY -e AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN -v ~/.aws:/root/.aws  -v $PWD:/host amazon/aws-cli $@'
alias awscmd='docker run --rm -i -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY -e AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN -v ~/.aws:/root/.aws  -v $PWD:/host amazon/aws-cli $@'
alias terracognita='docker run -it --rm   -v ~/.aws:/root/.aws  -v "${PWD}"/outputs:/app/outputs  cycloid/terracognita $@'
alias terracognita_aws='terracognita aws  --aws-access-key="${AWS_ACCESS_KEY_ID}" --aws-secret-access-key="${AWS_SECRET_ACCESS_KEY}" --aws-session-token "${AWS_SESSION_TOKEN}" $@'
alias terraform='docker run -it --rm -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY -e AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN -v ~/.aws:/root/.aws -v "${PWD}":/app hashicorp/terraform'

