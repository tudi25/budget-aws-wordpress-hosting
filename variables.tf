variable "aws_region" {}
data "aws_availability_zones" "available" {
  state = "available"
}
variable "vpc_cidr" {}
variable "cidrs" {
  type = map
}
variable "key_name" {}
variable "public_key_path" {}
variable "haproxy_instance_type" {}
variable "haproxy_ami" {}
variable "nat_instance_type" {}
variable "nat_ami" {}
variable "wp_instance_type" {}
variable "wp_ami" {}
