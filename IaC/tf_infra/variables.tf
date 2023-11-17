
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
  default     = "ubuntu-22-04-x64"
}
