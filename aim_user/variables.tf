variable "aws_region" {
  description = "AWS region used by the provider. AWS Organizations is global, but the provider still requires a region."
  type        = string
  default     = "us-east-1"
}

variable "account_name" {
  description = "Display name for the new AWS member account."
  type        = string
}

variable "account_email" {
  description = "Unique email address for the new AWS account root user."
  type        = string
}

variable "organization_account_access_role_name" {
  description = "Admin role AWS Organizations creates in the new member account."
  type        = string
  default     = "OrganizationAccountAccessRole"
}

variable "iam_user_access_to_billing" {
  description = "Whether IAM users in the new member account can access billing. Use ALLOW or DENY."
  type        = string
  default     = "DENY"

  validation {
    condition     = contains(["ALLOW", "DENY"], var.iam_user_access_to_billing)
    error_message = "iam_user_access_to_billing must be ALLOW or DENY."
  }
}
