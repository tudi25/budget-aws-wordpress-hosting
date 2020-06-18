variable "aws_region" {}
data "aws_availability_zones" "available" {
  state = "available"
}
variable "vpc_cidr" {}
variable "cidrs" {
  type = map
}
