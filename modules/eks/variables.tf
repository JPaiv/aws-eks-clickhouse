variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version of the control plane"
  type        = string
  default     = "1.34"
}

variable "subnet_ids" {
  description = "Private subnet IDs the control plane ENIs and nodes attach to"
  type        = list(string)
}

variable "endpoint_public_access" {
  description = "Expose the API server endpoint publicly (IAM-authenticated). The private endpoint is always on."
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint; tighten when you have a stable egress CIDR"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enabled_log_types" {
  description = "Control plane log types shipped to CloudWatch"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "log_retention_days" {
  description = "CloudWatch retention for control plane logs"
  type        = number
  default     = 14
}

variable "instance_types" {
  description = "Instance types of the bootstrap node group"
  type        = list(string)
  default     = ["m7i-flex.large"]
}

variable "desired_size" {
  description = "Desired node count of the bootstrap node group"
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Minimum node count of the bootstrap node group"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum node count of the bootstrap node group"
  type        = number
  default     = 3
}

variable "disk_size" {
  description = "Node root volume size in GiB"
  type        = number
  default     = 50
}

variable "capacity_type" {
  description = "Capacity type of the bootstrap node group: ON_DEMAND or SPOT"
  type        = string
  default     = "ON_DEMAND"
}

variable "tags" {
  description = "Extra tags for every resource, merged over the provider default_tags"
  type        = map(string)
  default     = {}
}
