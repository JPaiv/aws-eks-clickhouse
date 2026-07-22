variable "name" {
  description = "Name prefix for every resource in the VPC"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name, used for the subnet discovery tags"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones to spread the subnets across"
  type        = number
  default     = 3
}

variable "nat_gateway_per_az" {
  description = "One NAT gateway per AZ (HA) instead of a single shared one (cheap). Flipping this only rewrites private routes."
  type        = bool
  default     = false
}

variable "flow_log_retention_days" {
  description = "CloudWatch retention for VPC flow logs"
  type        = number
  default     = 14
}

variable "tags" {
  description = "Extra tags for every resource, merged over the provider default_tags"
  type        = map(string)
  default     = {}
}
