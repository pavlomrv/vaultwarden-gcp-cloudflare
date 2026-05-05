# AWS Member Account Terraform

This creates a new AWS member account under AWS Organizations.

It does not create another root user inside your existing AWS account. Every AWS account has exactly one root user, identified by the account email. Use the generated `OrganizationAccountAccessRole` for normal admin access.

## Prerequisites

- Run this from the AWS Organizations management account, or from a delegated identity with permission to create accounts.
- AWS Organizations must be enabled.
- The `account_email` must be unique across AWS and reachable by you.
- Configure AWS credentials before running Terraform, for example with `AWS_PROFILE`.

## Usage

Copy the example variables file:

```sh
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with the new account name and email.

Then run:

```sh
terraform init
terraform plan
terraform apply
```

After apply, use the `admin_role_arn` output to assume the admin role in the new account.

## Important

The resource has `prevent_destroy = true` because AWS account closure is high-risk and should not happen accidentally through Terraform.
