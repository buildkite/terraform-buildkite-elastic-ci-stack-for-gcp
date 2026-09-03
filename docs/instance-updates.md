# Agent scaling and instance updates

This behavior requires Google provider 7.33 or later because that release added
configurable autoscaler stabilization periods.

## Upgrading an existing stack

Applying this release does not reconfigure existing VMs because instance
updates are opportunistic. Those VMs retain their old agent configuration and
cannot scale themselves in, so they can keep the fleet above `min_size`.

After applying the release, perform a one-time job-safe replacement:

1. Pause dispatch for the stack's Buildkite queue.
2. Wait for all running jobs on its agents to finish.
3. Replace the MIG's existing members so they start from the new template. For
   smaller fleets with sufficient quota for temporary replacement VMs, run:

   ```bash
   gcloud compute instance-groups managed update-instances \
     "$(terraform output -raw instance_group_manager_name)" \
     --project=PROJECT_ID \
     --region="$(terraform output -raw region)" \
     --all-instances \
     --minimal-action=replace \
     --most-disruptive-allowed-action=replace
   ```

   This can replace every member concurrently, so the fleet might briefly have
   no connected agents. For larger fleets, update named members in batches with
   `--instances` to bound disruption and stay within CPU and IP quota.
4. Resume dispatch after the replacement agents have connected.

Do not replace members until dispatch is paused and jobs have drained. Selective
updates do not apply `max_surge` or `max_unavailable`, and the stack cannot
determine which existing agents are idle on the operator's behalf.

## Job-safe scale-in

The native GCP autoscaler assigns the queue's unfinished jobs across instances
and only scales out. Its one-second stabilization period avoids retaining a peak
recommendation that would recreate a VM just removed by an idle agent; zero
prevents scale-out for this custom metric. When an agent has been idle for
`agent_idle_timeout` seconds (600 by default), it disconnects, and a systemd
lifecycle hook removes that VM from the regional managed instance group and
decrements the group's target size.
Set `agent_idle_timeout = 0` to disable idle agent scale-in.

The idle timeout is also the grace period for bursty workloads. If another job
arrives before it expires, the idle agent accepts the job and resets its timer.
When autoscaling remains enabled, setting it to `0` keeps the scale-out-only
fleet at its high-water mark. When autoscaling is disabled, the module disables
idle disconnect and self-termination so the static MIG retains its configured
capacity.

When disabling autoscaling on an existing stack, pause dispatch, wait for jobs
to drain, disable autoscaling and apply, then replace the old members using the
process above. Existing members can still self-terminate on their old idle
timeout during this transition. Because Terraform intentionally ignores the
MIG's runtime target size, explicitly resize it to the desired static capacity
before resuming dispatch:

```bash
gcloud compute instance-groups managed resize \
  "$(terraform output -raw instance_group_manager_name)" \
  --project=PROJECT_ID \
  --region="$(terraform output -raw region)" \
  --size=STATIC_CAPACITY
```

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
