# Agent instance updates

The regional managed instance group uses an opportunistic update policy. When
the instance template changes, Google Cloud records the new target template but
does not proactively replace existing agent VMs. Proactive instance
redistribution is also disabled so that the group does not delete a running
agent merely to rebalance instances between zones.

New instances use the latest template when the group scales out or otherwise
creates a replacement. Existing instances therefore adopt template changes as
they are recycled, rather than through an immediate rolling update. This avoids
interrupting jobs, but means a template change can take time to reach the whole
fleet when demand and instance membership remain stable.

This is a change from earlier stack releases, where instance template changes
triggered an immediate proactive rollout. If a security-sensitive change must
reach existing agents immediately, explicitly update instances only after they
are idle; otherwise allow normal instance recycling to adopt it without
interrupting jobs.

The `max_surge` and `max_unavailable` settings do not cause an opportunistic
template update to roll out automatically. To preserve these limits when
explicitly starting a rolling update with `gcloud compute instance-groups
managed rolling-action start-update`, pass both values explicitly with
`--max-surge` and `--max-unavailable`. If omitted for this stack's stateless
regional MIG, gcloud defaults both values to the number of zones rather than
reusing the Terraform settings. For a stateful MIG, omitted `--max-surge`
instead defaults to `0`; omitted `--max-unavailable` still defaults to the
number of zones.

Starting a rolling update changes the live MIG update policy and creates
temporary Terraform drift, so do not run `terraform apply` until the rolling
update has finished. The next apply restores the configured opportunistic
policy.

These settings do not limit a selective `update-instances` request targeting
named VMs. Prefer `update-instances` when you have identified specific idle
agents to recycle.

Disabling proactive redistribution can temporarily leave instances unevenly
distributed between zones after instance removal. The regional group still
converges toward balance when later resize operations create or remove
instances.
