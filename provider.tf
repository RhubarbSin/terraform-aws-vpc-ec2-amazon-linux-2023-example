provider "aws" {
  region = var.region

  default_tags {
    tags = { Name = var.name }
  }
}
