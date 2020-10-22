variable "vpc_id" {
  type = string
}

variable "tags" {
  type = map(string)
  default = {
    Project        = "ec2-access"
    TeamName       = "myself"
    Env            = "test"
    CreationMethod = "terraform"
    Owner          = "myself"
  }
}

variable "key_path" {
  type = string
}

locals {
  name = "ec2-simple"
  tags = merge(map("Name", local.name), var.tags)
}


