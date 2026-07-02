# Bootstrap Module

The `bootstrap/` module creates the Terraform state storage used by the root deployment.

It is intentionally separate from the main module because the root module cannot use a remote GCS backend until the GCS bucket and impersonation service account already exist.

## Table Of Contents

- [What Bootstrap Creates](#what-bootstrap-creates)
- [Separate Bootstrap State](#separate-bootstrap-state)
- [Prerequisites](#prerequisites)
- [Configure](#configure)
- [Apply](#apply)
- [Use Outputs In The Root Backend](#use-outputs-in-the-root-backend)
- [If Bootstrap State Is Lost](#if-bootstrap-state-is-lost)
- [Security Notes](#security-notes)
- [Cleanup](#cleanup)

## What Bootstrap Creates

- A GCS bucket for root Terraform state.
- Uniform bucket-level access on the state bucket.
- Public access prevention on the state bucket.
- Object versioning for state recovery.
- A lifecycle rule that deletes archived object versions after 90 days.
- A `terraform-state` service account.
- `roles/storage.objectAdmin` for that service account on the state bucket.
- `roles/iam.serviceAccountTokenCreator` on the state service account for configured impersonators.
- Required Google APIs:
 - Compute Engine
 - Secret Manager
 - IAM Credentials
 - IAM
 - Cloud Resource Manager

## Separate Bootstrap State

Bootstrap has its own local state file:

```text
bootstrap/terraform.tfstate
```

That local state is not the same as the root remote state.

This is expected. Bootstrap creates the remote state bucket; the root module then uses that bucket through `backend.config`.

Keep the bootstrap state private. It contains IAM and bucket metadata and is needed for clean future bootstrap changes. If you lose it, use `recover-state.sh`.

## Prerequisites

- Terraform `~> 1.15.1`.
- Google Cloud credentials with permission to create buckets, service accounts, IAM bindings, and enable project APIs.
- A GCP project with billing enabled.
- A globally unique state bucket name.

Authenticate before running:

```bash
gcloud auth application-default login
gcloud config set project my-gcp-project
```

## Configure

Copy the example:

```bash
cd bootstrap
cp terraform.tfvars.example terraform.tfvars
```

Example `terraform.tfvars`:

```hcl
gcp_project_id = "my-gcp-project"

region = "us-east1"

tfstate_bucket_name = "my-vaultwarden-tfstate-12345"

terraform_state_impersonators = [
 "user:me@example.com"
]
```

`terraform_state_impersonators` should contain the identities allowed to impersonate the state service account. Use fully qualified IAM members:

```hcl
terraform_state_impersonators = [
 "user:me@example.com",
 "serviceAccount:ci@my-gcp-project.iam.gserviceaccount.com"
]
```

## Apply

```bash
terraform init
terraform plan
terraform apply
```

Print outputs:

```bash
terraform output
```

Important outputs:

- `backend_bucket_name`
- `backend_impersonate_service_account`
- `authorized_impersonators`

## Use Outputs In The Root Backend

In the repository root, create `backend.config`:

```bash
cp backend.config.example backend.config
```

Example:

```hcl
impersonate_service_account = "terraform-state@my-gcp-project.iam.gserviceaccount.com"
bucket                      = "my-vaultwarden-tfstate-12345"
prefix                      = "vaultwarden/prod"
```

Then initialize the root module:

```bash
cd ..
terraform init -backend-config=backend.config
```

The root module stores its state in the GCS bucket created by bootstrap.

## If Bootstrap State Is Lost

If `bootstrap/terraform.tfstate` is lost, do not recreate resources blindly. Use the recovery script to import the existing bootstrap resources into a fresh local state.

Run from the `bootstrap/` directory:

```bash
bash recover-state.sh user:me@example.com
```

You can also pass environment variables:

```bash
PROJECT_ID=my-gcp-project TFSTATE_BUCKET=my-vaultwarden-tfstate-12345 \
 bash recover-state.sh user:me@example.com
```

`recover-state.sh`:

- Reads project and bucket settings from environment variables, `terraform.tfvars`, or prompts.
- Imports the state bucket.
- Imports the `terraform-state` service account.
- Imports bucket IAM.
- Imports impersonator IAM bindings passed as arguments.
- Imports enabled project services.
- Runs `terraform plan` so you can verify alignment.

The recovery script uses `terraform init -backend=false`. It does not touch root remote state.

## Security Notes

- Do not commit `terraform.tfvars` or `terraform.tfstate`.
- Keep state bucket access narrow.
- Prefer user or CI identities that can impersonate the state service account instead of granting broad direct bucket access.
- Keep object versioning enabled on the state bucket.
- The bucket uses `force_destroy = false`, so Terraform should not delete non-empty state storage by accident.

## Cleanup

Destroying bootstrap infrastructure can remove the bucket used by root Terraform state. Do not run `terraform destroy` in `bootstrap/` unless the root deployment is already destroyed or you have intentionally migrated state elsewhere.

If you intentionally decommission everything:

1. Destroy or migrate the root deployment first.
2. Confirm state backups are no longer needed.
3. Empty or archive the state bucket intentionally.
4. Destroy bootstrap resources last.
