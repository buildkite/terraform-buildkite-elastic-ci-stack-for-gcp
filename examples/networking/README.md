# Networking Example

This example demonstrates how to use the networking module to create GCP networking infrastructure for the Elastic CI Stack.

## Prerequisites

1. **GCP Project**: You need a GCP project with billing enabled
2. **Authentication**: Configure authentication using one of these methods:
   - `gcloud auth application-default login`
   - Set `GOOGLE_APPLICATION_CREDENTIALS` environment variable
   - Use a service account key
3. **Permissions**: Your account needs the following IAM roles:
   - `roles/compute.networkAdmin`
   - `roles/compute.securityAdmin`

## Usage

1. **Copy the example terraform.tfvars file:**

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Edit terraform.tfvars with your values:**

   ```hcl
   project = "your-gcp-project-id"
   region  = "us-central1"
   network_name = "my-elastic-ci-stack"
   ```

3. **Initialize Terraform:**

   ```bash
   terraform init
   ```

4. **Plan the deployment:**

   ```bash
   terraform plan
   ```

5. **Apply the configuration:**

   ```bash
   terraform apply
   ```

## What This Creates

This example creates the networking foundation for your Buildkite agent infrastructure:

- **VPC Network** (`elastic-ci-stack-example` by default)
- **Two Subnets** in the specified region for high availability:
  - Subnet 0: `10.0.1.0/24`
  - Subnet 1: `10.0.2.0/24`
- **Cloud Router** for NAT gateway functionality
- **Cloud NAT** for secure internet access without external IPs
- **Firewall Rules**:
  - SSH access (if enabled) for administration
  - Internal communication between subnets
  - Google Cloud health checks
  - IAP access (if enabled) for secure access

## Outputs

After deployment, you'll see outputs including:

- Network name and self-link for use with instance groups
- Subnet information for compute instances
- Network tag for instances

## Customization

You can customize the deployment by modifying variables in `terraform.tfvars`:

- **Security**: Restrict SSH access by setting `ssh_source_ranges` to specific IP ranges
- **IAP**: Enable Identity-Aware Proxy with `enable_iap_access = true` for secure access without VPN
- **Future GKE**: Enable secondary IP ranges with `enable_secondary_ranges = true`

## Verification

After deployment, you can verify the networking infrastructure using these `gcloud` commands:

**List the VPC network:**

```bash
gcloud compute networks list --filter="name:elastic-ci-stack-example"
```

**List subnets:**

```bash
gcloud compute networks subnets list --filter="network:elastic-ci-stack-example"
```

**Check Cloud Router:**

```bash
gcloud compute routers list --filter="name:elastic-ci-stack-example-router"
```

**Verify Cloud NAT:**

```bash
gcloud compute routers nats list --router=elastic-ci-stack-example-router --region=us-central1
```

**List firewall rules:**

```bash
gcloud compute firewall-rules list --filter="network:elastic-ci-stack-example"
```

**Get detailed network info:**

```bash
gcloud compute networks describe elastic-ci-stack-example
```

**View subnet details:**

```bash
gcloud compute networks subnets describe elastic-ci-stack-example-subnet-0 --region=us-central1
gcloud compute networks subnets describe elastic-ci-stack-example-subnet-1 --region=us-central1
```

## Clean Up

To destroy the infrastructure:

```bash
terraform destroy
```
