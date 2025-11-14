# Centralized Logging with Google Cloud Ops Agent

## Overview

The Elastic CI Stack for GCP uses the [Google Cloud Ops Agent](https://cloud.google.com/stackdriver/docs/solutions/agents/ops-agent) to provide centralized logging and monitoring capabilities, similar to CloudWatch Agent in the AWS Elastic CI Stack.

The Ops Agent is pre-installed and pre-configured in the custom VM image built by Packer. It automatically collects logs from various sources and sends them to Google Cloud Logging for centralized storage, analysis, and troubleshooting.

## Log Collection Strategy

The stack collects logs from the following sources:

### Application Logs

| Log Source | File Path | Description | AWS Equivalent |
|------------|-----------|-------------|----------------|
| **Buildkite Agent** | `/var/log/buildkite-agent.log` | Logs from the Buildkite agent service, including job execution, agent lifecycle events, and errors | `/buildkite/buildkite-agent` |
| **Docker Daemon** | `/var/log/docker.log` | Docker daemon logs (when Docker is installed) | `/buildkite/docker-daemon` |
| **Preemption Monitor** | `/var/log/preemption-monitor.log` | Logs from the preemption monitoring service that handles spot/preemptible instance termination | `/buildkite/lifecycled` |

### System Logs

| Log Source | File Path | Description | AWS Equivalent |
|------------|-----------|-------------|----------------|
| **System Messages** | `/var/log/syslog` | General system messages and events (Debian uses `syslog` instead of `messages`) | `/buildkite/system` |
| **Security/Auth** | `/var/log/auth.log` | Authentication and authorization logs (Debian uses `auth.log` instead of `secure`) | `/buildkite/auth` |

### Cloud Initialization Logs

| Log Source | File Path | Description | AWS Equivalent |
|------------|-----------|-------------|----------------|
| **Cloud-Init** | `/var/log/cloud-init.log` | Cloud initialization logs showing VM bootstrap process | `/buildkite/cloud-init` |
| **Cloud-Init Output** | `/var/log/cloud-init-output.log` | Output from cloud-init scripts and commands | `/buildkite/cloud-init/output` |

### Ops Agent Self-Logs

| Log Source | File Path | Description |
|------------|-----------|-------------|
| **Ops Agent** | `/var/log/google-cloud-ops-agent/subagents/logging-module.log` | Ops Agent self-logs for troubleshooting the agent itself |

## Log Routing Architecture

The logging system uses rsyslog to route systemd service logs to dedicated files:

1. **Systemd Services** → Output logs via systemd journal
2. **Rsyslog** → Routes service logs to dedicated files in `/var/log/`
3. **Ops Agent** → Tails log files and sends to Cloud Logging
4. **Cloud Logging** → Centralized log storage and analysis

### Rsyslog Configuration

The stack includes a custom rsyslog configuration (`/etc/rsyslog.d/10-buildkite-logging.conf`) that routes logs from systemd services to dedicated files:

```log
:programname, isequal, "buildkite-agent" /var/log/buildkite-agent.log
:programname, isequal, "dockerd" /var/log/docker.log
:programname, isequal, "preemption-monitor" /var/log/preemption-monitor.log
```

This ensures that logs from these services are collected by the Ops Agent and sent to Cloud Logging.

## Ops Agent Configuration

The Ops Agent configuration is located at `/etc/google-cloud-ops-agent/config.yaml` and defines:

- **Receivers**: What logs to collect (file paths, patterns)
- **Processors**: How to parse and transform logs (severity parsing, field extraction)
- **Pipelines**: How receivers and processors connect

### Log Processing Pipeline

**Buildkite Agent Logs:**

1. Collected from `/var/log/buildkite-agent.log`
2. Parsed using regex to extract timestamp, severity, and message
3. Severity mapped to Cloud Logging severity levels (DEBUG, INFO, WARNING, ERROR, CRITICAL)
4. Sent to Cloud Logging with proper `LogEntry` structure

**System Logs:**

1. Collected from their respective files
2. Sent to Cloud Logging as-is with minimal processing
3. Tagged with instance metadata (instance ID, zone, project)

## Viewing Logs in Cloud Logging

### Using the Google Cloud Console

1. Navigate to **Monitoring** > **Logs Explorer** in the Cloud Console
2. Use the following filters to view specific logs:

**View Buildkite Agent logs:**

```text
resource.type="gce_instance"
log_name="projects/YOUR_PROJECT_ID/logs/buildkite_agent"
```

**View System logs:**

```text
resource.type="gce_instance"
log_name="projects/YOUR_PROJECT_ID/logs/syslog"
```

**View logs from a specific instance:**

```text
resource.type="gce_instance"
resource.labels.instance_id="INSTANCE_ID"
```

**View logs with specific severity:**

```text
severity >= ERROR
```

### Using the gcloud CLI

**View recent Buildkite agent logs:**

```bash
gcloud logging read "resource.type=gce_instance AND log_name=projects/YOUR_PROJECT_ID/logs/buildkite_agent" \
  --limit 50 \
  --format json
```

**View logs from a specific instance:**

```bash
gcloud logging read "resource.labels.instance_id=INSTANCE_ID" \
  --limit 100 \
  --format json
```

**View logs from the last hour:**

```bash
gcloud logging read "resource.type=gce_instance" \
  --freshness=1h \
  --limit 100 \
  --format json
```

**View ERROR-level logs only:**

```bash
gcloud logging read "resource.type=gce_instance AND severity>=ERROR" \
  --limit 50 \
  --format json
```

## Log Retention

### Default Retention

- **Default retention**: 30 days for most logs
- **Admin Activity logs**: 400 days
- **Data Access logs**: 30 days

## Differences from AWS Elastic CI Stack

| Aspect | AWS (CloudWatch) | GCP (Cloud Logging) |
|--------|------------------|---------------------|
| **Agent** | CloudWatch Agent | Ops Agent |
| **Configuration** | JSON-based | YAML-based |
| **System logs** | `/var/log/messages` | `/var/log/syslog` |
| **Auth logs** | `/var/log/secure` | `/var/log/auth.log` |
| **Log format** | CloudWatch Log Groups/Streams | Cloud Logging LogEntry |
| **Instance metadata** | CloudWatch dimensions | Cloud Logging resource labels |
| **Log retention** | Configurable per log group | Project-wide with custom retention |
| **Lifecycle service** | lifecycled | preemption-monitor |

## Integration with Cloud Monitoring

The Ops Agent collects system metrics (CPU, memory, disk, network) and sends them to Cloud Monitoring. These metrics are used for:

- Autoscaling decisions
- Alerting on resource utilization
- Performance troubleshooting
- Capacity planning

### Buildkite Agent Metrics Function

The `buildkite-agent-metrics` Cloud Function publishes custom Buildkite queue metrics (`scheduled_jobs` and `running_jobs`) to Cloud Monitoring for autoscaling. The function has built-in Cloud Logging integration, so its logs appear automatically in Cloud Logging under:

```text
resource.type="cloud_function"
resource.labels.function_name="buildkite-agent-metrics"
```

For more information, see the [Cloud Monitoring documentation](https://cloud.google.com/monitoring/docs).

## References

- [Ops Agent Overview](https://cloud.google.com/stackdriver/docs/solutions/agents/ops-agent)
- [Ops Agent Configuration](https://cloud.google.com/stackdriver/docs/solutions/agents/ops-agent/configuration)
- [Cloud Logging Overview](https://cloud.google.com/logging/docs)
- [Logs Explorer](https://cloud.google.com/logging/docs/view/logs-explorer-interface)
