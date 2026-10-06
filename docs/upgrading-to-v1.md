# Upgrading to module v1

Module v1 deploys images that use Buildkite Agent v4. Read the [Agent v3 to v4 upgrade guide](https://buildkite.com/docs/agent/v3-v4-upgrade-guide) first; this page only covers the module-specific steps.

## Before upgrading

1. Update your module inputs. Terraform rejects inputs that aren't in module v1:
   - Remove `buildkite_agent_release`. It never changed the installed agent, which comes from the image.
2. If you set `image` to a custom image, rebuild it from this repository's [Packer configuration](../packer) at v1 and update the input in the same apply. An older image still boots with module v1, but it keeps Agent v3.
3. If `image` references the `buildkite-ci-stack-x86-64` or `buildkite-ci-stack-arm64` image family, it moves to Agent v4 as soon as Agent v4 images are published, regardless of the module version.
4. Preview the update with `terraform plan`.

If you need Agent v3, remain on module v0.x with a pinned `image`.

## Rolling out

To verify module v1 before upgrading production, deploy it as a separate module block with its own `stack_name` and `buildkite_queue`, then run pipeline steps on that queue.

Applying module v1 to an existing stack updates the instance template without replacing running VMs. New VMs use Agent v4, and existing VMs keep Agent v3 until they're removed, so jobs can run on either version during the rollout.
With autoscaling enabled, existing VMs remove themselves after their agents are idle for `agent_idle_timeout`, and replacements use Agent v4.

To finish sooner without interrupting jobs, stop the remaining Agent v3 agents with the [Buildkite CLI](https://buildkite.com/docs/platform/cli). Each agent finishes its current job before it stops, and its VM then removes itself from the managed instance group. For example, for the `default` queue:

```bash
bk agent list --tags queue=default --limit 1000 --output json \
  | jq -r '.[] | select(.version | startswith("3.")) | .id' \
  | bk agent stop
```

If autoscaling is disabled, stopped agents don't remove their VMs. Use the [job-safe replacement](instance-updates.md#upgrading-an-existing-stack) instead.

## Cancellation timing

Module v0.x set `cancel-grace-period=10`, which gave a canceled job's process 9 seconds before `SIGKILL`. Module v1 uses the Agent v4 defaults:

- `cancel-signal-timeout=10s` controls how long the process has before `SIGKILL`.
- `cancel-cleanup-timeout=5s` gives a stopping agent extra time to upload logs and artifacts.

These settings aren't module inputs.
