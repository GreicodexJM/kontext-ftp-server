
To Generate:

Single file
terracognita_aws --hcl /app/outputs/resources.tf --aws-default-region $AWS_REGION  --tfstate /app/outputs/terraform.tfstate 

Modules
for res in $(terracognita aws resources); do echo $res; terracognita_aws --hcl /app/outputs/modules/$res.tf --aws-default-region $AWS_REGION --module $res -i $res --tfstate terraform.tfstate  ; done






To test

To speed up the testing, you can write a small provider.tf file within the same folder you imported your resources & tfstate:

terraform {
 backend "local" {
   path = "./$TFSTATE_PATH"
 }
}

provider "aws" {
 access_key = "${var.access_key}"
 secret_key = "${var.secret_key}"
 region     = "${var.region}"
 version    = "2.12.0"
}

variable "access_key" {}
variable "secret_key" {}
variable "region" {}

Then run the terraform init & plan commands:

$ terraform init
$ terraform plan -var access_key=$AWS_ACCESS_KEY_ID -var secret_key=$AWS_SECRET_ACCESS_KEY -var region=$AWS_DEFAULT_REGION
