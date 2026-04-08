variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  default     = "10.0.0.0/16"
}

variable "instance_type_web" {
  description = "Instance type for web servers"
  default     = "t3.micro"
}

variable "instance_type_db" {
  description = "Instance type for database server"
  default     = "t3.small"
}

variable "instance_type_bastion" {
  description = "Instance type for bastion host"
  default     = "t3.micro"
}

variable "my_ip" {
  description = "Your current IP address for bastion SSH access"
  type        = string
}

variable "key_pair_name" {
  description = "Name of the AWS key pair"
  type        = string
  default     = "techcorp-key"
}
