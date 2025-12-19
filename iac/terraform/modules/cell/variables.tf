variable "region" {
  type = string
}

variable "cell_name" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.medium"
}

variable "db_allocated_storage_gb" {
  type    = number
  default = 50
}

variable "api_image" { type = string }
variable "orchestrator_image" { type = string }
variable "connector_gateway_image" { type = string }
variable "approval_image" { type = string }

variable "desired_count_api" { type = number default = 2 }
variable "desired_count_orchestrator" { type = number default = 2 }
variable "desired_count_connector_gateway" { type = number default = 2 }
variable "desired_count_approval" { type = number default = 2 }

# Optional: set to restrict webhook ingress (e.g. to known ServiceNow IP ranges) – MVP can be open + auth + WAF later.
variable "webhook_ingress_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}
