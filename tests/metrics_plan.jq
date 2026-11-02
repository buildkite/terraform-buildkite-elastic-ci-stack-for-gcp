# Terraform assertions cannot access child module resources. Check the mocked
# plans instead, without adding outputs to the modules just for testing.
if [.[] | select(.type == "test_summary") | .test_summary.status] != ["pass"] then
  error(([.[] | select(.type == "diagnostic") | ."@message"] + ["Root Terraform tests failed or did not finish"]) | join("\n"))
else . end
| map(select(.type == "test_plan" and ."@testfile" == "tests/metrics.tftest.hcl"))
| if (map(."@testrun") | sort) != ["custom_source", "disabled_autoscaling", "latest_custom_generation", "pinned_default"] then
    error("Missing root metrics plans")
  else .[] end
| ."@testrun" as $run
| [.test_plan.resource_changes[]
    | select(.type == "google_cloudfunctions2_function")
    | .change.after.build_config[0].source[0].storage_source[0]
    | {bucket, object, generation}] as $sources
| [.test_plan.resource_changes[]
    | select(.address == "module.iam.google_project_iam_member.metrics_secret_accessor[0]")
    | .change.after] as $grants
| (if $run == "disabled_autoscaling" then
     $sources == [] and $grants == []
   else
     ($sources | length) == 1 and
     ($grants | length) == 1 and
     $grants[0].project == "test-project" and
     $grants[0].role == "roles/secretmanager.secretAccessor" and
     ($grants[0].condition | length) == 1 and
     ($grants[0].condition[0].expression | contains("/secrets/root-token/versions/")) and
     (if $run == "pinned_default" then
        $sources[0].bucket == "buildkite-cloud-functions" and
        ($sources[0].object | test("^buildkite-agent-metrics/v[0-9]+\\.[0-9]+\\.[0-9]+/buildkite-agent-metrics\\.zip$")) and
        $sources[0].generation > 0
      else
        $sources == [{
          bucket: "custom-metrics-source",
          object: "custom/metrics.zip",
          generation: (if $run == "custom_source" then 24680 else null end)
        }]
      end)
   end) as $valid
| if $valid then "\($run): child resource configuration passed"
  else error("\($run): unexpected metrics source or secret grant") end
