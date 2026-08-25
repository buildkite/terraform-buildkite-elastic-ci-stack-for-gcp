# Agent scaling and instance updates

## Job-safe scale-in

The native GCP autoscaler uses the Buildkite queue metric only to scale out,
not scale-in. When an agent has been idle for `agent_idle_timeout` seconds (600
by default) it disconnects, and a systemd lifecycle hook removes that VM from
the regional managed instance group and decrements the group's target size. Set
`agent_idle_timeout = 0` to disable idle agent scale-in.

When autoscaling remains enabled, using `0` also means the scale-out-only fleet
stays at its high-water mark; use it when autoscaling is disabled or another
system manages capacity.

The termination hook is installed by this Terraform module. It therefore
assumes the VM belongs to the regional MIG created by the module.

An agent crash follows the same lifecycle and removes the unusable VM. If the
removal request fails, the post-stop command fails, which triggers the service's
`Restart=on-failure` policy. Manually stopping or restarting the agent service
also recycles its VM; these agents are intended to be ephemeral.

An idle agent can remove itself while the group is at `min_size`. The
scale-out-only autoscaler then restores the minimum using the latest instance
template.

## Opportunistic template updates

The regional managed instance group uses an opportunistic update policy. When
the instance template changes, GCP records the new target template but does not
proactively replace existing agent VMs. Proactive instance redistribution is
also disabled so that the group does not delete a running agent merely to
rebalance instances between zones.

New instances use the latest template when the group scales out or otherwise
creates a replacement. Existing instances adopt template changes as they are
recycled, rather than through an immediate update. This avoids interrupting
jobs, but means a template change can take time to reach the whole fleet when it
is busy.

The `max_surge` and `max_unavailable` settings do not cause a template update to
roll out automatically. To preserve these limits when explicitly starting a
rolling update with `gcloud compute instance-groups managed rolling-action
start-update`, pass both values explicitly with `--max-surge` and
`--max-unavailable`. If omitted for this stack's stateless regional MIG, gcloud
defaults both values to the number of zones rather than reusing the Terraform
settings. For a stateful MIG, omitted `--max-surge` instead defaults to `0`;
omitted `--max-unavailable` still defaults to the number of zones.

Starting a rolling update changes the live MIG update policy and creates
temporary Terraform drift, so do not run `terraform apply` until the rolling
update has finished. The next apply restores the configured opportunistic
policy.

These settings do not limit a selective `update-instances` request targeting
named VMs. Prefer `update-instances` when you have identified specific idle
agents to recycle.

Disabling proactive redistribution can temporarily leave instances unevenly
distributed between zones after instance removal. The regional group will
rebalance when later resize operations create or remove instances.
