#!/bin/bash
SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
shopt -s expand_aliases
source assume.sh
UNIQ=$( date | md5 | cut -b-4 )

if [ ! -d $SCRIPTPATH/$CUSTOMER_WORKSPACE ]; then
    mkdir $SCRIPTPATH/$CUSTOMER_WORKSPACE;
fi
if [ -f $SCRIPTPATH/$CUSTOMER_WORKSPACE/backend.tf ]; then
  echo "Bootstrap process already ran. Please review configuration values. You do not want to overrite your backend.tf file"
fi
if [ ! -f $SCRIPTPATH/$CUSTOMER_WORKSPACE/provider.tf ]; then
cat <<EOT > $SCRIPTPATH/$CUSTOMER_WORKSPACE/provider.tf
terraform {
    required_providers {
      digitalocean={
        source = "digitalocean/digitalocean"
        version = "2.29"
      }
    }
}

provider "digitalocean" {
    token = "\${var.do_token}"
    spaces_access_id  = var.do_access_key
    spaces_secret_key = var.do_secret_key
}
EOT

echo "Adding S3 Bucket: $CUSTOMER_PROJECT-devops-tfstate-$UNIQ"
cat <<EOT > $SCRIPTPATH/$CUSTOMER_WORKSPACE/remote_backend.tf
resource "digitalocean_spaces_bucket" "tf-state-storage" {
    bucket = "\${var.project}-devops-tfstate-$UNIQ"
#    force_destroy = true
    versioning {
      enabled = true
    }
    lifecycle {
      prevent_destroy = true
    }    
}
# create a dynamodb table for locking the state file
# resource "aws_dynamodb_table" "dynamodb-tf-state-lock" {
#  name = "\${var.project}-devops-tf-state-lock"
#  billing_mode = "PAY_PER_REQUEST"
#  hash_key = "LockID" 
#  attribute {
#    name = "LockID"
#    type = "S"
#  }
# }

EOT
fi

cat <<EOF > $SCRIPTPATH/$CUSTOMER_WORKSPACE/output.tf
output "remote_backend" {
    value = <<EOT
terraform {
  backend "s3" {
    endpoint = "nyc3.digitaloceanspaces.com/"
    region = "\${var.region}"
    key    = "\${var.workspace}/terraform.tfstate"
    bucket = "\${digitalocean_spaces_bucket.tf-state-storage.name}"
    skip_requesting_account_id = true
    skip_credentials_validation = true
    skip_get_ec2_platforms = true
    skip_metadata_api_check = true


#    
#    dynamodb_table = "\${aws_dynamodb_table.dynamodb-tf-state-lock.name}"
    
    
  }
}
EOT
}
EOF

if [ ! -f $SCRIPTPATH/$CUSTOMER_WORKSPACE/variables.tf ]; then
cat <<EOT > $SCRIPTPATH/$CUSTOMER_WORKSPACE/variables.tf

variable "do_token" {
  description = "Assumed Session Token for Customer Account"
  sensitive = true
  type = string
}

variable "do_access_key" {
    description = "Access Key ID for AWS"
    sensitive = true
    type = string
}

variable "do_region" {
    description = "Default AWS Region"
    type = string
}

variable "do_secret_key" {
    description = "Secret Access Key for AWS"
    sensitive = true
    type = string
}

#variable "customer" {
#    description = "Customer name for this infrastructure"
#    type = string
#}

variable "workspace" { 
    description = "Workspace name for this infrastructure"
    type = string
    default = "tf_infra"
}

variable "project" {
    description = "Project name for this customer"
    type = string
}
variable "do_nyc1" {
  description = "Digital Ocean New York Data Center 1"
  default     = "nyc1"
}

variable "do_nyc2" {
  description = "Digital Ocean New York Data Center 2"
  default     = "nyc2"
}

variable "do_nyc3" {
  description = "Digital Ocean New York Data Center 3"
  default     = "nyc3"
}

variable "ubuntu" {
  description = "Default Ubuntu LTS"
  default     = "ubuntu-18-04-x64"
}
EOT
fi

echo "Adding S3 TF Backed" 
terraform -chdir=/app/$CUSTOMER_WORKSPACE init && \
terraform -chdir=/app/$CUSTOMER_WORKSPACE plan -var-file=/app/credentials.tfvars  && \
terraform -chdir=/app/$CUSTOMER_WORKSPACE apply -var-file=/app/credentials.tfvars -auto-approve && \
terraform -chdir=/app/$CUSTOMER_WORKSPACE output -raw remote_backend > $SCRIPTPATH/$CUSTOMER_WORKSPACE/backend.tf
if [ -f $SCRIPTPATH/$CUSTOMER_WORKSPACE/output.tf ]; then
  rm $SCRIPTPATH/$CUSTOMER_WORKSPACE/output.tf
fi
echo "Re-running Terraform to migrate State"
terraform -chdir=/app/$CUSTOMER_WORKSPACE init && \
terraform -chdir=/app/$CUSTOMER_WORKSPACE plan -var-file=/app/credentials.tfvars  && \
terraform -chdir=/app/$CUSTOMER_WORKSPACE apply -var-file=/app/credentials.tfvars -auto-approve

echo "Completed Terraform Bootstrap"

