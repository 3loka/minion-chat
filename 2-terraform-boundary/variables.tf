variable "aws_region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t2.medium"
}

variable "boundary_cluster_id" {
  description = "Your boundary cluster id"
  nullable = false
  default = "555c2085-9f56-478c-9196-7da82effec92"
}

variable "dockerhub_id" {
  default = "srahul3"
}
