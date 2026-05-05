output "account_id" {
  description = "ID of the created AWS member account."
  value       = aws_organizations_account.member.id
}

output "account_arn" {
  description = "ARN of the created AWS member account."
  value       = aws_organizations_account.member.arn
}

output "admin_role_name" {
  description = "Role to assume from the management account for admin access to the new account."
  value       = var.organization_account_access_role_name
}

output "admin_role_arn" {
  description = "ARN of the organization access role in the new account."
  value       = "arn:aws:iam::${aws_organizations_account.member.id}:role/${var.organization_account_access_role_name}"
}
