
variable region {}
variable vpc-primary-cidr {}
variable vpc-name {}
variable cluster_name {}
variable cluster_version {}
variable cluster_service_ipv4_cidr {}
variable cluster_endpoint_public_access_cidrs {}

variable public_worker {
    description = "if public workers are required, set this to true"
    type        = bool
    default     = false
}

variable private_worker {
    description = "if private workers are required, set this variable to true"
    type        = bool
    default     = true
}

variable single_az {
    description = "If you desire to use multiple AZs, then set this variable to false"
    type        = bool
    default     = false
}


variable dns_support {
    description = "A variable to enable/disable DNS support in the VPC"
    type        = bool
    default     = true
}

variable dns_hostnames {
    description = "A variable to receive a private DNS for instances"
    type        = bool
    default     = true
}

variable "instance_type" {
  description = "EC2 bastion host type"
  type = string
  default = "t3.micro"  
}