# Elastic CI Stack for GCP

[![Build status](https://badge.buildkite.com/3215529db5b0c43976ce30bd625724ae0f71af146ef8ac0007.svg)](https://buildkite.com/buildkite/elastic-ci-stack-for-gcp?branch=main)

Terraform modules for running autoscaling [Buildkite](https://buildkite.com/) agents on Google Cloud Platform.

## Documentation

Full documentation is available at <https://buildkite.com/docs/agent/v3/gcp/elastic-ci-stack/elastic-ci-stack>.

Repository documentation:

- [Upgrading to module v1](docs/upgrading-to-v1.md) — Buildkite Agent v4 and removed
  module inputs
- [Agent scaling and instance updates](docs/instance-updates.md) — describes
  job-safe scale-in, idle-agent removal, and opportunistic template rollout
- [GCP image release pipeline](docs/image-release-pipeline.md)

## Getting Started

The module ships with a set of default values which can be overridden as needed, but should be sufficient for most use cases.

```hcl
module "elastic-ci-stack-for-gcp" {
  source  = "buildkite/elastic-ci-stack-for-gcp/buildkite"
  version = "~> 1.0"

  # Required
  project_id                  = "your-gcp-project"
  buildkite_organization_slug = "your-org-slug"
  buildkite_agent_token       = "YOUR_AGENT_TOKEN"
}
```

### GPU instances

GPU instances cannot live migrate during host maintenance. Set
`on_host_maintenance = "TERMINATE"` alongside the GPU machine type in your module
configuration, for example:

```hcl
  machine_type        = "a2-highgpu-1g"
  on_host_maintenance = "TERMINATE"
```

The default is `MIGRATE`, preserving live migration for existing CPU fleets.
`TERMINATE` stops the VM during host maintenance and can interrupt running builds;
automatic restart remains enabled. Choose zones that support your GPU and use a
Buildkite agent image with the required NVIDIA drivers (and NVIDIA Container
Toolkit for GPU-enabled Docker builds); the default image does not install them.

## Contributing

See [Contributing Guidelines](CONTRIBUTING.md).

## License

MIT

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 7.33, < 8.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_buildkite_metrics"></a> [buildkite\_metrics](#module\_buildkite\_metrics) | ./modules/buildkite-agent-metrics | n/a |
| <a name="module_compute"></a> [compute](#module\_compute) | ./modules/compute | n/a |
| <a name="module_iam"></a> [iam](#module\_iam) | ./modules/iam | n/a |
| <a name="module_networking"></a> [networking](#module\_networking) | ./modules/networking | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_agent_custom_role_id"></a> [agent\_custom\_role\_id](#input\_agent\_custom\_role\_id) | ID for the custom IAM role for agent instance management. Defaults to '{stack\_name}AgentInstanceMgmt' if not specified. | `string` | `null` | no |
| <a name="input_agent_idle_timeout"></a> [agent\_idle\_timeout](#input\_agent\_idle\_timeout) | Seconds an autoscaled agent must remain idle before disconnecting and removing its VM from the managed instance group. Set to 0 to disable idle-based scale-in; because the native autoscaler is scale-out-only, capacity will then remain at its high-water mark. Ignored when autoscaling is disabled. | `number` | `600` | no |
| <a name="input_agent_service_account_id"></a> [agent\_service\_account\_id](#input\_agent\_service\_account\_id) | ID for the Buildkite agent service account. Defaults to '{stack\_name}-agent' if not specified. | `string` | `null` | no |
| <a name="input_autoscaling_jobs_per_instance"></a> [autoscaling\_jobs\_per\_instance](#input\_autoscaling\_jobs\_per\_instance) | Number of unfinished Buildkite jobs assigned to each instance for autoscaling. Lower values provide more parallelism at higher cost. | `number` | `1` | no |
| <a name="input_buildkite_agent_tags"></a> [buildkite\_agent\_tags](#input\_buildkite\_agent\_tags) | Additional tags for Buildkite agents (comma-separated key=value pairs, e.g., 'docker=true,os=linux'). Use these to target specific agents in pipeline steps. | `string` | `""` | no |
| <a name="input_buildkite_agent_token"></a> [buildkite\_agent\_token](#input\_buildkite\_agent\_token) | Buildkite agent registration token from your Buildkite organization. Get this from: Buildkite Dashboard → Agents → Reveal Agent Token. Leave empty if using buildkite\_agent\_token\_secret. | `string` | `""` | no |
| <a name="input_buildkite_agent_token_secret"></a> [buildkite\_agent\_token\_secret](#input\_buildkite\_agent\_token\_secret) | Alternative to buildkite\_agent\_token: GCP Secret Manager secret name containing the Buildkite agent token (e.g., 'projects/PROJECT\_ID/secrets/buildkite-agent-token/versions/latest'). Recommended for production. | `string` | `""` | no |
| <a name="input_buildkite_api_endpoint"></a> [buildkite\_api\_endpoint](#input\_buildkite\_api\_endpoint) | Buildkite API endpoint URL. Only change if using a custom endpoint. | `string` | `"https://agent.buildkite.com/v3"` | no |
| <a name="input_buildkite_organization_slug"></a> [buildkite\_organization\_slug](#input\_buildkite\_organization\_slug) | Buildkite organization slug (from your Buildkite URL: `https://buildkite.com/<org-slug>`). Used for metrics namespacing. | `string` | n/a | yes |
| <a name="input_buildkite_queue"></a> [buildkite\_queue](#input\_buildkite\_queue) | Buildkite queue name that agents will listen to. Agents in this stack will only pick up jobs targeting this queue. | `string` | `"default"` | no |
| <a name="input_cooldown_period"></a> [cooldown\_period](#input\_cooldown\_period) | Cooldown period in seconds between autoscaling actions to prevent flapping | `number` | `60` | no |
| <a name="input_enable_autohealing"></a> [enable\_autohealing](#input\_enable\_autohealing) | Enable automatic replacement of unhealthy instances | `bool` | `true` | no |
| <a name="input_enable_autoscaling"></a> [enable\_autoscaling](#input\_enable\_autoscaling) | Enable autoscaling based on Buildkite job queue metrics. Requires buildkite-agent-metrics Cloud Function to be deployed. | `bool` | `true` | no |
| <a name="input_enable_iap_access"></a> [enable\_iap\_access](#input\_enable\_iap\_access) | Enable Identity-Aware Proxy (IAP) for secure SSH without external IPs or VPN | `bool` | `false` | no |
| <a name="input_enable_integrity_monitoring"></a> [enable\_integrity\_monitoring](#input\_enable\_integrity\_monitoring) | Enable integrity monitoring for shielded VM instances (recommended) | `bool` | `true` | no |
| <a name="input_enable_secondary_ranges"></a> [enable\_secondary\_ranges](#input\_enable\_secondary\_ranges) | Enable secondary IP ranges for future GKE support | `bool` | `false` | no |
| <a name="input_enable_secret_access"></a> [enable\_secret\_access](#input\_enable\_secret\_access) | Grant agents access to Secret Manager. Enable if your builds need to access secrets. | `bool` | `true` | no |
| <a name="input_enable_secure_boot"></a> [enable\_secure\_boot](#input\_enable\_secure\_boot) | Enable Secure Boot for shielded VM instances (additional security, slight performance overhead) | `bool` | `false` | no |
| <a name="input_enable_ssh_access"></a> [enable\_ssh\_access](#input\_enable\_ssh\_access) | Enable SSH access to instances via firewall rule. Set to false for additional security. | `bool` | `true` | no |
| <a name="input_enable_storage_access"></a> [enable\_storage\_access](#input\_enable\_storage\_access) | Grant agents access to Cloud Storage. Enable if your builds need to upload/download artifacts. | `bool` | `false` | no |
| <a name="input_enable_vtpm"></a> [enable\_vtpm](#input\_enable\_vtpm) | Enable virtual Trusted Platform Module for shielded VM instances (recommended) | `bool` | `true` | no |
| <a name="input_function_source"></a> [function\_source](#input\_function\_source) | Metrics function source. Null uses the module's pinned release. Set generation to null to use the latest generation of a custom object. | <pre>object({<br/>    bucket     = string<br/>    object     = string<br/>    generation = number<br/>  })</pre> | `null` | no |
| <a name="input_health_check_healthy_threshold"></a> [health\_check\_healthy\_threshold](#input\_health\_check\_healthy\_threshold) | Number of consecutive successful health checks before marking instance healthy | `number` | `2` | no |
| <a name="input_health_check_initial_delay_sec"></a> [health\_check\_initial\_delay\_sec](#input\_health\_check\_initial\_delay\_sec) | Time (in seconds) to wait after instance start before beginning health checks | `number` | `300` | no |
| <a name="input_health_check_interval_sec"></a> [health\_check\_interval\_sec](#input\_health\_check\_interval\_sec) | How often (in seconds) to perform health checks | `number` | `30` | no |
| <a name="input_health_check_port"></a> [health\_check\_port](#input\_health\_check\_port) | Port for health checks (22 for SSH, or custom port if running health endpoint) | `number` | `22` | no |
| <a name="input_health_check_timeout_sec"></a> [health\_check\_timeout\_sec](#input\_health\_check\_timeout\_sec) | How long (in seconds) to wait for health check response before marking as failed | `number` | `10` | no |
| <a name="input_health_check_unhealthy_threshold"></a> [health\_check\_unhealthy\_threshold](#input\_health\_check\_unhealthy\_threshold) | Number of consecutive failed health checks before marking instance unhealthy | `number` | `3` | no |
| <a name="input_image"></a> [image](#input\_image) | Source image for boot disk. Use a custom Packer-built image or a public Buildkite image. | `string` | `"buildkite-gcp-stack/buildkite-ci-stack-x86-64-2026-10-27-0339-69-e77aafd"` | no |
| <a name="input_instance_tag"></a> [instance\_tag](#input\_instance\_tag) | Network tag applied to instances for firewall targeting. Defaults to '{stack\_name}-agent' if not specified. | `string` | `null` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Additional labels to apply to all resources for organization and billing | `map(string)` | `{}` | no |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | GCP machine type for agent instances (e.g., 'e2-standard-4', 'n1-standard-2', 'c2-standard-4'). See: <https://cloud.google.com/compute/docs/machine-types> | `string` | `"e2-standard-4"` | no |
| <a name="input_max_size"></a> [max\_size](#input\_max\_size) | Maximum number of agent instances. Controls cost ceiling and maximum parallelization. | `number` | `10` | no |
| <a name="input_max_surge"></a> [max\_surge](#input\_max\_surge) | Maximum number of instances stored in the MIG update policy above target size. Pass this value explicitly with --max-surge when starting a gcloud rolling update; template changes are not rolled out proactively. | `number` | `3` | no |
| <a name="input_max_unavailable"></a> [max\_unavailable](#input\_max\_unavailable) | Maximum number of unavailable instances stored in the MIG update policy. Pass this value explicitly with --max-unavailable when starting a gcloud rolling update; template changes are not rolled out proactively. | `number` | `0` | no |
| <a name="input_metrics_custom_role_id"></a> [metrics\_custom\_role\_id](#input\_metrics\_custom\_role\_id) | ID for the custom IAM role for metrics autoscaling. Defaults to '{stack\_name}MetricsAutoscaler' if not specified. | `string` | `null` | no |
| <a name="input_metrics_service_account_id"></a> [metrics\_service\_account\_id](#input\_metrics\_service\_account\_id) | ID for the metrics function service account. Defaults to '{stack\_name}-metrics' if not specified. | `string` | `null` | no |
| <a name="input_min_size"></a> [min\_size](#input\_min\_size) | Minimum number of agent instances. Set to 0 to scale to zero when idle (cost-effective) or higher for always-available capacity. | `number` | `0` | no |
| <a name="input_network_name"></a> [network\_name](#input\_network\_name) | Name of the VPC network to create. Defaults to '{stack\_name}-network' if not specified. | `string` | `null` | no |
| <a name="input_on_host_maintenance"></a> [on\_host\_maintenance](#input\_on\_host\_maintenance) | Action to take during host maintenance: MIGRATE or TERMINATE. GPU instances require TERMINATE, which can interrupt running builds. | `string` | `"MIGRATE"` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | GCP project ID where the Elastic CI Stack will be deployed | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | GCP region where resources will be deployed (e.g., 'us-central1', 'europe-west1') | `string` | `"us-central1"` | no |
| <a name="input_root_disk_size_gb"></a> [root\_disk\_size\_gb](#input\_root\_disk\_size\_gb) | Size of the root disk in GB. Increase for larger Docker images or build artifacts. | `number` | `50` | no |
| <a name="input_root_disk_type"></a> [root\_disk\_type](#input\_root\_disk\_type) | Type of root disk: 'pd-standard' (cheaper, slower), 'pd-balanced' (recommended), 'pd-ssd' (fastest) | `string` | `"pd-balanced"` | no |
| <a name="input_ssh_source_ranges"></a> [ssh\_source\_ranges](#input\_ssh\_source\_ranges) | CIDR blocks allowed to SSH to instances. Restrict to your IP for security (e.g., ['203.0.113.0/24']). Only used if enable\_ssh\_access is true. | `list(string)` | <pre>[<br/>  "0.0.0.0/0"<br/>]</pre> | no |
| <a name="input_stack_name"></a> [stack\_name](#input\_stack\_name) | Name prefix for all resources in this stack. Used to identify and organize resources. | `string` | `"buildkite"` | no |
| <a name="input_zones"></a> [zones](#input\_zones) | List of availability zones within the region for high availability. If not specified, uses all zones in the region. | `list(string)` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_agent_service_account_email"></a> [agent\_service\_account\_email](#output\_agent\_service\_account\_email) | Email address of the Buildkite agent service account |
| <a name="output_agent_service_account_id"></a> [agent\_service\_account\_id](#output\_agent\_service\_account\_id) | Unique ID of the Buildkite agent service account |
| <a name="output_autoscaler_id"></a> [autoscaler\_id](#output\_autoscaler\_id) | ID of the autoscaler (if autoscaling is enabled) |
| <a name="output_autoscaler_name"></a> [autoscaler\_name](#output\_autoscaler\_name) | Name of the autoscaler (if autoscaling is enabled) |
| <a name="output_autoscaling_enabled"></a> [autoscaling\_enabled](#output\_autoscaling\_enabled) | Whether autoscaling is enabled |
| <a name="output_buildkite_queue"></a> [buildkite\_queue](#output\_buildkite\_queue) | Buildkite queue that agents are listening to |
| <a name="output_health_check_id"></a> [health\_check\_id](#output\_health\_check\_id) | ID of the health check (if autohealing is enabled) |
| <a name="output_instance_group_id"></a> [instance\_group\_id](#output\_instance\_group\_id) | ID of the instance group (for use with load balancers, etc.) |
| <a name="output_instance_group_manager_id"></a> [instance\_group\_manager\_id](#output\_instance\_group\_manager\_id) | ID of the managed instance group |
| <a name="output_instance_group_manager_name"></a> [instance\_group\_manager\_name](#output\_instance\_group\_manager\_name) | Name of the managed instance group |
| <a name="output_instance_template_id"></a> [instance\_template\_id](#output\_instance\_template\_id) | ID of the instance template |
| <a name="output_instance_template_name"></a> [instance\_template\_name](#output\_instance\_template\_name) | Name of the instance template used for Buildkite agents |
| <a name="output_machine_type"></a> [machine\_type](#output\_machine\_type) | Machine type used for agent instances |
| <a name="output_max_size"></a> [max\_size](#output\_max\_size) | Maximum number of agent instances |
| <a name="output_metrics_service_account_email"></a> [metrics\_service\_account\_email](#output\_metrics\_service\_account\_email) | Email address of the metrics service account |
| <a name="output_metrics_service_account_id"></a> [metrics\_service\_account\_id](#output\_metrics\_service\_account\_id) | Unique ID of the metrics service account |
| <a name="output_min_size"></a> [min\_size](#output\_min\_size) | Minimum number of agent instances |
| <a name="output_network_id"></a> [network\_id](#output\_network\_id) | ID of the VPC network |
| <a name="output_network_name"></a> [network\_name](#output\_network\_name) | Name of the VPC network |
| <a name="output_network_self_link"></a> [network\_self\_link](#output\_network\_self\_link) | Self link of the VPC network |
| <a name="output_region"></a> [region](#output\_region) | GCP region where resources were deployed |
| <a name="output_stack_name"></a> [stack\_name](#output\_stack\_name) | Name of the Elastic CI Stack |
| <a name="output_subnet_0_cidr"></a> [subnet\_0\_cidr](#output\_subnet\_0\_cidr) | CIDR range of the first subnet |
| <a name="output_subnet_0_name"></a> [subnet\_0\_name](#output\_subnet\_0\_name) | Name of the first subnet |
| <a name="output_subnet_1_cidr"></a> [subnet\_1\_cidr](#output\_subnet\_1\_cidr) | CIDR range of the second subnet |
| <a name="output_subnet_1_name"></a> [subnet\_1\_name](#output\_subnet\_1\_name) | Name of the second subnet |
<!-- END_TF_DOCS -->