terraform {
    required_providers {
      digitalocean={
        source = "digitalocean/digitalocean"
        version = "2.29"
      }
    }
}

provider "digitalocean" {
    token = "${var.do_token}"
    spaces_access_id  = var.do_access_key
    spaces_secret_key = var.do_secret_key
}
