---
name: Bug report
about: Report a bug or issue with the Elastic CI Stack for GCP
title: ''
labels: 'bug'
assignees: ''
---

## Describe the bug

A clear and concise description of what the bug is.

## To Reproduce

Steps to reproduce the behavior:

1. Configure Terraform with '...'
2. Run command '...'
3. See error

## Expected behavior

A clear and concise description of what you expected to happen.

## Environment

**Terraform Configuration:**

```hcl
# Paste relevant parts of your Terraform configuration here
# Please redact any sensitive information (tokens, project IDs, etc.)
```

**Versions:**

- Elastic CI Stack for GCP version: [e.g., v0.1.0 or commit SHA]
- Terraform version: [output of `terraform version`]
- GCP Provider version: [from terraform.lock.hcl or terraform version output]
- gcloud CLI version: [output of `gcloud version`]

**GCP Environment:**

- Project ID: [your GCP project ID, or redact if sensitive]
- Region: [e.g., us-central1]
- Machine type: [e.g., e2-standard-4]

**Module Configuration:**

- Using root module or sub-modules? [root / networking+iam+compute / other]
- Autoscaling enabled? [yes/no]
- Custom image or default? [custom / default Debian]

## Logs and Output

**Terraform output:**

```hcl
# Paste relevant terraform plan/apply/destroy output here
# Please redact any sensitive information
```

**GCP Console Logs (if applicable):**

```bash
# Cloud Logging output from agents or instances
# Serial console output
# Health check logs
```

**Buildkite Agent Logs (if applicable):**

```bash
# Agent connection errors
# Job execution errors
```

## Additional context

Add any other context about the problem here:

- Screenshots
- Related issues
- Workarounds you've tried
- Impact on your workflow

## Checklist

- [ ] I have searched for similar issues in the issue tracker
- [ ] I have redacted sensitive information (tokens, project IDs, etc.)
- [ ] I have included all relevant version information
- [ ] I have included relevant logs and error messages
