variable "instance_type" {
  default = "t2.micro"
}
variable "hosted_zone_id" {
  description = "Route 53 Hosted Zone ID"
}

variable "domain_name" {
  description = "Domain name for the Route 53 record"
}

variable "aws_region" {
  default = "us-east-1"
}