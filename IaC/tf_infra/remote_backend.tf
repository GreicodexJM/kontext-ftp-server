resource "digitalocean_spaces_bucket" "tf-state-storage" {
    name = "${var.project}-devops-tfstate-b842"
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
#  name = "${var.project}-devops-tf-state-lock"
#  billing_mode = "PAY_PER_REQUEST"
#  hash_key = "LockID" 
#  attribute {
#    name = "LockID"
#    type = "S"
#  }
# }

