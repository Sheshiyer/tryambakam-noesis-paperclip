#!/usr/bin/env bash
set -euo pipefail

SOURCE_REPO="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$SOURCE_REPO/tests/lib/fixture-helpers.sh"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

mkdir -p "$TMP_ROOT/scripts" "$TMP_ROOT/.thoughtseed/teamforge"
copy_scripts_from_repo "$SOURCE_REPO" "$TMP_ROOT/scripts" teamforge-sync.sh
chmod +x "$TMP_ROOT/scripts/teamforge-sync.sh"

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:00:00Z",
  "metrics": {
    "newSignals": 0,
    "skippedSignals": 3,
    "suppressedSignals": 3,
    "dispatchedSignals": 0,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.75,
    "outcomes": {}
  },
  "alerts": {
    "maxLagWarning": false,
    "failureRateWarning": false,
    "coverageWarning": false
  }
}
JSON

status_output="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.failureRate == 0.75
  and .metrics.failureRateCurrent == 0
  and .metrics.failureRateScope == "historical_lifetime_runs"
  and .metrics.coverage.expectedSources == ["clockify", "huly", "slack"]
  and .metrics.coverage.seenSources == []
  and .metrics.coverage.evaluated == false
  and .metrics.coverage.ratio == null
  and .alerts.failureRateWarning == false
' <<< "$status_output" >/dev/null

rm -f "$TMP_ROOT/.thoughtseed/teamforge/health.json"

status_output_missing_health_fallback="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .generatedAt == null
  and .metrics.newSignals == 0
  and .metrics.skippedSignals == 0
  and .metrics.suppressedSignals == 0
  and .metrics.dispatchedSignals == 0
  and .metrics.errors == 0
  and .metrics.coverage.expectedSources == ["clockify", "huly", "slack"]
  and .metrics.coverage.seenSources == []
  and .metrics.coverage.evaluated == false
  and .metrics.coverage.ratio == null
  and .metrics.failureRate == 0
  and .metrics.failureRateCurrent == 0
  and .metrics.failureRateScope == "historical_lifetime_runs"
  and .alerts.maxLagWarning == false
  and .alerts.failureRateWarning == false
  and .alerts.coverageWarning == false
' <<< "$status_output_missing_health_fallback" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
"legacy_scalar_blob"
JSON

status_output_root_scalar_fallback="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .generatedAt == null
  and .metrics.newSignals == 0
  and .metrics.skippedSignals == 0
  and .metrics.suppressedSignals == 0
  and .metrics.dispatchedSignals == 0
  and .metrics.errors == 0
  and .metrics.coverage.expectedSources == ["clockify", "huly", "slack"]
  and .metrics.coverage.seenSources == []
  and .metrics.coverage.evaluated == false
  and .metrics.coverage.ratio == null
  and .metrics.failureRate == 0
  and .metrics.failureRateCurrent == 0
  and .metrics.failureRateScope == "historical_lifetime_runs"
  and .alerts.maxLagWarning == false
  and .alerts.failureRateWarning == false
  and .alerts.coverageWarning == false
' <<< "$status_output_root_scalar_fallback" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{ this is not valid json
JSON

status_output_invalid_json_fallback="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .generatedAt == null
  and .metrics.newSignals == 0
  and .metrics.skippedSignals == 0
  and .metrics.suppressedSignals == 0
  and .metrics.dispatchedSignals == 0
  and .metrics.errors == 0
  and .metrics.coverage.expectedSources == ["clockify", "huly", "slack"]
  and .metrics.coverage.evaluated == false
  and .metrics.failureRate == 0
  and .metrics.failureRateCurrent == 0
  and .metrics.failureRateScope == "historical_lifetime_runs"
  and .alerts.maxLagWarning == false
  and .alerts.failureRateWarning == false
  and .alerts.coverageWarning == false
' <<< "$status_output_invalid_json_fallback" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generated_at": "2026-04-20T12:00:30Z",
  "metrics": {
    "newSignals": 0,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 0,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.0,
    "outcomes": {}
  },
  "alerts": {
    "maxLagWarning": false,
    "failureRateWarning": false,
    "coverageWarning": false
  }
}
JSON

status_output_generated_at_snake_case="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .generatedAt == "2026-04-20T12:00:30Z"
' <<< "$status_output_generated_at_snake_case" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:00:45Z",
  "metrics": "legacy_scalar_blob",
  "alerts": "legacy_scalar_blob",
  "new_signals": "2",
  "skipped_signals": "1",
  "suppressed_signals": "0",
  "dispatched_signals": "1",
  "errors": "0",
  "lag": {
    "projectionLagSeconds": null,
    "maxSourceLagSeconds": 10,
    "sources": []
  },
  "coverage": {
    "expectedSources": ["clockify"],
    "seenSources": ["clockify"],
    "evaluated": true,
    "ratio": 1
  },
  "quality": {
    "score": 100,
    "findingCount": 0,
    "findingsByType": []
  },
  "failureRate": 0.0,
  "outcomes": {}
}
JSON

status_output_metrics_alerts_scalar_fallback="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.newSignals == 2
  and .metrics.skippedSignals == 1
  and .metrics.suppressedSignals == 0
  and .metrics.dispatchedSignals == 1
  and .metrics.errors == 0
  and .alerts.maxLagWarning == false
  and .alerts.failureRateWarning == false
  and .alerts.coverageWarning == false
' <<< "$status_output_metrics_alerts_scalar_fallback" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:01:00Z",
  "metrics": {
    "new_signals": 4,
    "skipped_signals": 2,
    "suppressed_signals": 1,
    "dispatched_signals": 3,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.0,
    "outcomes": {}
  }
}
JSON

status_output_core_counters_snake_case="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.newSignals == 4
  and .metrics.skippedSignals == 2
  and .metrics.suppressedSignals == 1
  and .metrics.dispatchedSignals == 3
' <<< "$status_output_core_counters_snake_case" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:01:15Z",
  "new_signals": "6",
  "skippedSignals": "2",
  "suppressed_signals": "1",
  "dispatchedSignals": "4",
  "error_count": "3",
  "metrics": {
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.0,
    "outcomes": {}
  }
}
JSON

status_output_core_counters_root_fallback="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.newSignals == 6
  and .metrics.skippedSignals == 2
  and .metrics.suppressedSignals == 1
  and .metrics.dispatchedSignals == 4
  and .metrics.errors == 3
  and .metrics.failureRateCurrent == 1
  and .alerts.failureRateWarning == true
' <<< "$status_output_core_counters_root_fallback" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:01:30Z",
  "metrics": {
    "newSignals": 1,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 0,
    "error_count": "2",
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify"],
      "seenSources": ["clockify"],
      "evaluated": true
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.0,
    "outcomes": {}
  }
}
JSON

status_output_error_count_snake_case="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.errors == 2
  and .metrics.failureRateCurrent == 1
  and .alerts.failureRateWarning == true
' <<< "$status_output_error_count_snake_case" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:01:45Z",
  "metrics": {
    "newSignals": 1,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 0,
    "errorCount": "3",
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify"],
      "seenSources": ["clockify"],
      "evaluated": true
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.0,
    "outcomes": {}
  }
}
JSON

status_output_error_count_camel_case="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.errors == 3
  and .metrics.failureRateCurrent == 1
  and .alerts.failureRateWarning == true
' <<< "$status_output_error_count_camel_case" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:02:00Z",
  "metrics": {
    "newSignals": 1,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify"],
      "seenSources": ["clockify"],
      "evaluated": true
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.10,
    "failureRateCurrent": "yes",
    "outcomes": {}
  }
}
JSON

status_output_failure_rate_current_string_true="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.failureRateCurrent == 1
' <<< "$status_output_failure_rate_current_string_true" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:03:00Z",
  "metrics": {
    "newSignals": 1,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 1,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify"],
      "seenSources": ["clockify"],
      "evaluated": true
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.10,
    "failureRateCurrent": "no",
    "outcomes": {}
  }
}
JSON

status_output_failure_rate_current_string_false="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.failureRateCurrent == 0
' <<< "$status_output_failure_rate_current_string_false" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:04:00Z",
  "metrics": {
    "newSignals": 1,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 1,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify"],
      "seenSources": ["clockify"],
      "evaluated": true
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.10,
    "failureRateCurrent": false,
    "outcomes": {}
  }
}
JSON

status_output_failure_rate_current_bool_false="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.failureRateCurrent == 0
' <<< "$status_output_failure_rate_current_bool_false" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:04:30Z",
  "metrics": {
    "newSignals": 1,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify"],
      "seenSources": ["clockify"],
      "evaluated": true
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.10,
    "failure_rate_current": "yes",
    "outcomes": {}
  }
}
JSON

status_output_failure_rate_current_snake_case="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.failureRateCurrent == 1
' <<< "$status_output_failure_rate_current_snake_case" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:04:45Z",
  "metrics": {
    "newSignals": 1,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify"],
      "seenSources": ["clockify"],
      "evaluated": true
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "runs": {
      "total": 10,
      "failed": 9
    },
    "failure_rate": "0.35",
    "outcomes": {}
  }
}
JSON

status_output_failure_rate_snake_case="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.failureRate == 0.35
' <<< "$status_output_failure_rate_snake_case" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:05:00Z",
  "metrics": {
    "newSignals": 5,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 3,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify", "huly", "slack", "jira"],
      "seenSources": ["clockify", "huly", "huly"],
      "evaluated": true
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.10,
    "outcomes": {}
  },
  "alerts": {
    "maxLagWarning": false,
    "failureRateWarning": false,
    "coverageWarning": false
  }
}
JSON

status_output_computed="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  (.metrics.coverage.expectedSources | sort) == ["clockify", "huly", "jira", "slack"]
  and .metrics.coverage.seenSources == ["clockify", "huly"]
  and .metrics.coverage.evaluated == true
  and .metrics.coverage.ratio == 0.5
' <<< "$status_output_computed" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:06:00Z",
  "metrics": {
    "newSignals": 5,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 3,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify", "huly", "slack", "jira"],
      "seenSources": ["clockify", "huly"],
      "evaluated": true,
      "coverage_ratio": "0.25"
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.10,
    "outcomes": {}
  }
}
JSON

status_output_coverage_ratio_snake_case="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.coverage.ratio == 0.25
' <<< "$status_output_coverage_ratio_snake_case" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:06:30Z",
  "metrics": {
    "newSignals": 5,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 3,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify", "huly", "slack", "jira"],
      "seenSources": ["clockify", "huly"],
      "evaluated": true,
      "coverageRatio": "0.75"
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.10,
    "outcomes": {}
  }
}
JSON

status_output_coverage_ratio_camel_alias="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.coverage.ratio == 0.75
' <<< "$status_output_coverage_ratio_camel_alias" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:06:30Z",
  "metrics": {
    "newSignals": 1,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": " Clockify ",
      "seen_sources": " clockify ",
      "evaluated": true
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.10,
    "outcomes": {}
  }
}
JSON

status_output_coverage_scalar_sources="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.coverage.expectedSources == ["clockify"]
  and .metrics.coverage.seenSources == ["clockify"]
  and .metrics.coverage.evaluated == true
  and .metrics.coverage.ratio == 1
' <<< "$status_output_coverage_scalar_sources" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:06:35Z",
  "metrics": {
    "newSignals": 1,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify", true, false, null, "huly"],
      "seenSources": ["clockify", false, null],
      "evaluated": true
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.10,
    "outcomes": {}
  }
}
JSON

status_output_coverage_array_boolean_filter="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.coverage.expectedSources == ["clockify","huly"]
  and .metrics.coverage.seenSources == ["clockify"]
  and .metrics.coverage.evaluated == true
  and .metrics.coverage.ratio == 0.5
  and .alerts.coverageWarning == true
' <<< "$status_output_coverage_array_boolean_filter" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:06:36Z",
  "metrics": {
    "newSignals": 1,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": [
        {"source": "clockify"},
        {"source": "huly"},
        {"source": false},
        {"note": "ignored"},
        true
      ],
      "seenSources": [
        {"source": "clockify"},
        {"source": true},
        false
      ],
      "evaluated": true
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.10,
    "outcomes": {}
  }
}
JSON

status_output_coverage_array_object_source_extract="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.coverage.expectedSources == ["clockify","huly"]
  and .metrics.coverage.seenSources == ["clockify"]
  and .metrics.coverage.evaluated == true
  and .metrics.coverage.ratio == 0.5
  and .alerts.coverageWarning == true
' <<< "$status_output_coverage_array_object_source_extract" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:06:37Z",
  "metrics": {
    "newSignals": 1,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": [
        {"sources": ["clockify", "huly"]}
      ],
      "seenSources": [
        {"sources": ["clockify"]}
      ],
      "evaluated": true
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.10,
    "outcomes": {}
  }
}
JSON

status_output_coverage_array_object_sources_field="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.coverage.expectedSources == ["clockify","huly"]
  and .metrics.coverage.seenSources == ["clockify"]
  and .metrics.coverage.evaluated == true
  and .metrics.coverage.ratio == 0.5
  and .alerts.coverageWarning == true
' <<< "$status_output_coverage_array_object_sources_field" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:06:39Z",
  "metrics": {
    "newSignals": 1,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": true,
      "seenSources": false,
      "evaluated": true
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.10,
    "outcomes": {}
  }
}
JSON

status_output_coverage_scalar_boolean_sources="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.coverage.expectedSources == []
  and .metrics.coverage.seenSources == []
  and .metrics.coverage.evaluated == true
  and .metrics.coverage.ratio == 1
  and .alerts.coverageWarning == false
' <<< "$status_output_coverage_scalar_boolean_sources" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:06:39Z",
  "metrics": {
    "newSignals": 1,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": {
        "sources": true
      },
      "seenSources": {
        "sources": false
      },
      "evaluated": true
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.10,
    "outcomes": {}
  }
}
JSON

status_output_coverage_nested_scalar_boolean_sources="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.coverage.expectedSources == []
  and .metrics.coverage.seenSources == []
  and .metrics.coverage.evaluated == true
  and .metrics.coverage.ratio == 1
  and .alerts.coverageWarning == false
' <<< "$status_output_coverage_nested_scalar_boolean_sources" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:06:39Z",
  "metrics": {
    "newSignals": 1,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": {
        "source": false
      },
      "seenSources": {
        "source": true
      },
      "evaluated": true
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.10,
    "outcomes": {}
  }
}
JSON

status_output_coverage_source_field_boolean_filter="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.coverage.expectedSources == []
  and .metrics.coverage.seenSources == []
  and .metrics.coverage.evaluated == true
  and .metrics.coverage.ratio == 1
  and .alerts.coverageWarning == false
' <<< "$status_output_coverage_source_field_boolean_filter" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:06:39Z",
  "metrics": {
    "newSignals": 1,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": {
        "source": false,
        "sources": ["clockify", "huly"]
      },
      "seenSources": {
        "source": false,
        "sources": ["clockify"]
      },
      "evaluated": true
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.10,
    "outcomes": {}
  }
}
JSON

status_output_coverage_source_field_fallback_to_sources="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.coverage.expectedSources == ["clockify","huly"]
  and .metrics.coverage.seenSources == ["clockify"]
  and .metrics.coverage.evaluated == true
  and .metrics.coverage.ratio == 0.5
  and .alerts.coverageWarning == true
' <<< "$status_output_coverage_source_field_fallback_to_sources" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:06:39Z",
  "metrics": {
    "newSignals": 1,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": {
        "source": "clockify",
        "sources": ["clockify", "huly"]
      },
      "seenSources": {
        "source": "clockify",
        "sources": ["clockify"]
      },
      "evaluated": true
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.10,
    "outcomes": {}
  }
}
JSON

status_output_coverage_source_field_prefers_sources_set="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.coverage.expectedSources == ["clockify","huly"]
  and .metrics.coverage.seenSources == ["clockify"]
  and .metrics.coverage.evaluated == true
  and .metrics.coverage.ratio == 0.5
  and .alerts.coverageWarning == true
' <<< "$status_output_coverage_source_field_prefers_sources_set" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:06:40Z",
  "metrics": {
    "newSignals": 1,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": {
        "clockify": true,
        "huly": true
      },
      "seenSources": {
        "clockify": true
      },
      "evaluated": true
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.10,
    "outcomes": {}
  }
}
JSON

status_output_coverage_object_source_sets="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.coverage.expectedSources == ["clockify","huly"]
  and .metrics.coverage.seenSources == ["clockify"]
  and .metrics.coverage.evaluated == true
  and .metrics.coverage.ratio == 0.5
  and .alerts.coverageWarning == true
' <<< "$status_output_coverage_object_source_sets" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:06:41Z",
  "metrics": {
    "newSignals": 1,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": {
        "clockify": true,
        "huly": false,
        "slack": "yes"
      },
      "seenSources": {
        "clockify": 1,
        "huly": 0,
        "slack": "no"
      },
      "evaluated": true
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.10,
    "outcomes": {}
  }
}
JSON

status_output_coverage_object_source_truthy_filter="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.coverage.expectedSources == ["clockify","slack"]
  and .metrics.coverage.seenSources == ["clockify"]
  and .metrics.coverage.evaluated == true
  and .metrics.coverage.ratio == 0.5
  and .alerts.coverageWarning == true
' <<< "$status_output_coverage_object_source_truthy_filter" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:06:41Z",
  "metrics": {
    "newSignals": 1,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": {
        "clockify": "enabled",
        "huly": "yes",
        "slack": "no"
      },
      "seenSources": {
        "clockify": "active",
        "huly": "0",
        "slack": "false"
      },
      "evaluated": true
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.10,
    "outcomes": {}
  }
}
JSON

status_output_coverage_object_source_unknown_scalar_tokens="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.coverage.expectedSources == ["clockify","huly"]
  and .metrics.coverage.seenSources == ["clockify"]
  and .metrics.coverage.evaluated == true
  and .metrics.coverage.ratio == 0.5
  and .alerts.coverageWarning == true
' <<< "$status_output_coverage_object_source_unknown_scalar_tokens" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:06:41Z",
  "metrics": {
    "newSignals": 1,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": {
        "clockify": {
          "source": "clockify"
        },
        "huly": false,
        "slack": "enabled"
      },
      "seenSources": {
        "clockify": {
          "source": "clockify"
        },
        "huly": 0,
        "slack": "no"
      },
      "evaluated": true
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.10,
    "outcomes": {}
  }
}
JSON

status_output_coverage_object_source_mixed_map_false_filter="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.coverage.expectedSources == ["clockify","slack"]
  and .metrics.coverage.seenSources == ["clockify"]
  and .metrics.coverage.evaluated == true
  and .metrics.coverage.ratio == 0.5
  and .alerts.coverageWarning == true
' <<< "$status_output_coverage_object_source_mixed_map_false_filter" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:06:41Z",
  "metrics": {
    "newSignals": 1,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": {
        "clockify": "   ",
        "huly": "yes",
        "slack": "enabled"
      },
      "seenSources": {
        "huly": "yes",
        "slack": "   "
      },
      "evaluated": true
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.10,
    "outcomes": {}
  }
}
JSON

status_output_coverage_object_source_blank_scalar_filter="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.coverage.expectedSources == ["huly","slack"]
  and .metrics.coverage.seenSources == ["huly"]
  and .metrics.coverage.evaluated == true
  and .metrics.coverage.ratio == 0.5
  and .alerts.coverageWarning == true
' <<< "$status_output_coverage_object_source_blank_scalar_filter" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:06:41Z",
  "metrics": {
    "newSignals": 1,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": {
        "sources": null
      },
      "seenSources": {
        "sources": []
      },
      "evaluated": true
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.10,
    "outcomes": {}
  }
}
JSON

status_output_coverage_nested_sources_invalid_fallback="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.coverage.expectedSources == []
  and .metrics.coverage.seenSources == []
  and .metrics.coverage.evaluated == true
  and .metrics.coverage.ratio == 1
  and .alerts.coverageWarning == false
' <<< "$status_output_coverage_nested_sources_invalid_fallback" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:06:42Z",
  "metrics": {
    "newSignals": 1,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": {
        "sources": [" Clockify ", "huly"]
      },
      "seenSources": {
        "sources": " clockify "
      },
      "evaluated": true
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.10,
    "outcomes": {}
  }
}
JSON

status_output_coverage_nested_sources_object="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.coverage.expectedSources == ["clockify","huly"]
  and .metrics.coverage.seenSources == ["clockify"]
  and .metrics.coverage.evaluated == true
  and .metrics.coverage.ratio == 0.5
  and .alerts.coverageWarning == true
' <<< "$status_output_coverage_nested_sources_object" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:06:45Z",
  "coverage": {
    "expectedSources": ["clockify", "huly", "slack"],
    "seenSources": ["clockify", "huly"],
    "evaluated": true,
    "ratio": "0.5"
  },
  "metrics": {
    "newSignals": 5,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 3,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.10,
    "outcomes": {}
  }
}
JSON

status_output_coverage_root_fallback="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.coverage.expectedSources == ["clockify","huly","slack"]
  and .metrics.coverage.seenSources == ["clockify","huly"]
  and .metrics.coverage.evaluated == true
  and .metrics.coverage.ratio == 0.5
' <<< "$status_output_coverage_root_fallback" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:07:00Z",
  "metrics": {
    "newSignals": 0,
    "skippedSignals": 7,
    "suppressedSignals": 7,
    "dispatchedSignals": 0,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify", "huly", "slack"],
      "seenSources": [],
      "evaluated": false,
      "ratio": 0
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.10,
    "outcomes": {}
  },
  "alerts": {
    "maxLagWarning": false,
    "failureRateWarning": false,
    "coverageWarning": false
  }
}
JSON

status_output_not_evaluated="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.coverage.evaluated == false
  and .metrics.coverage.ratio == null
' <<< "$status_output_not_evaluated" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:10:00Z",
  "metrics": {
    "newSignals": 2,
    "skippedSignals": 1,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 1,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": 7201,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify", "huly", "slack"],
      "seenSources": ["clockify"],
      "evaluated": true
    },
    "quality": {
      "score": 80,
      "findingCount": 1,
      "findingsByType": ["orphan_owner"]
    },
    "failureRate": 0.20,
    "outcomes": {}
  }
}
JSON

status_output_alerts_backfill="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.failureRateCurrent == 1
  and .metrics.failureRateScope == "historical_lifetime_runs"
  and .metrics.coverage.evaluated == true
  and (.metrics.coverage.ratio > 0.32 and .metrics.coverage.ratio < 0.34)
  and .metrics.quality.findingsByType == [{"type":"orphan_owner","count":1}]
  and .alerts.maxLagWarning == true
  and .alerts.failureRateWarning == true
  and .alerts.coverageWarning == true
' <<< "$status_output_alerts_backfill" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:14:00Z",
  "metrics": {
    "newSignals": 4,
    "skippedSignals": 1,
    "suppressedSignals": 0,
    "dispatchedSignals": 2,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify", "huly", "slack"],
      "seenSources": ["clockify", "huly", "slack"],
      "evaluated": true
    },
    "quality": {
      "findingsByType": ["timestamp_drift", "timestamp_drift", {"type": "orphan_owner", "count": 1}]
    },
    "runs": {
      "total": 10,
      "failed": 3
    },
    "outcomes": {
      "resolved": 1,
      "partial": 1,
      "no-change": 2
    }
  }
}
JSON

status_output_quality_and_outcomes_backfill="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.failureRate == 0.3
  and .metrics.failureRateCurrent == 0
  and .metrics.failureRateScope == "historical_lifetime_runs"
  and .metrics.quality.score == 82
  and .metrics.quality.findingCount == 3
  and .metrics.quality.findingsByType == [{"type":"orphan_owner","count":1},{"type":"timestamp_drift","count":2}]
  and .metrics.outcomes.resolved == 1
  and .metrics.outcomes.partial == 1
  and .metrics.outcomes.noChange == 2
  and .metrics.outcomes.regressed == 0
  and .metrics.outcomes.validatedSignals == 4
  and .metrics.outcomes.avgTimeToResolutionSeconds == null
  and .metrics.outcomes.recurrenceSignals == 0
  and .alerts.maxLagWarning == false
  and .alerts.failureRateWarning == false
  and .alerts.coverageWarning == false
' <<< "$status_output_quality_and_outcomes_backfill" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:14:30Z",
  "metrics": {
    "newSignals": 2,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify", "huly"],
      "seenSources": ["clockify", "huly"],
      "evaluated": true
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "runs": {
      "total_runs": "8",
      "failed_runs": "2"
    },
    "outcomes": {}
  }
}
JSON

status_output_runs_snake_case_fallback="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.failureRate == 0.25
' <<< "$status_output_runs_snake_case_fallback" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:14:45Z",
  "metrics": {
    "newSignals": 2,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify", "huly"],
      "seenSources": ["clockify", "huly"],
      "evaluated": true
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "runs": {
      "totalRuns": "10",
      "failedRuns": "3"
    },
    "outcomes": {}
  }
}
JSON

status_output_runs_camel_case_fallback="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.failureRate == 0.3
' <<< "$status_output_runs_camel_case_fallback" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:14:50Z",
  "metrics": {
    "newSignals": 2,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify", "huly"],
      "seenSources": ["clockify", "huly"],
      "evaluated": true
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "outcomes": {}
  },
  "runs": {
    "total": "5",
    "failed": "2"
  }
}
JSON

status_output_runs_root_fallback="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.failureRate == 0.4
' <<< "$status_output_runs_root_fallback" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:14:55Z",
  "failure_rate": "0.65",
  "failure_rate_current": "yes",
  "failure_rate_scope": " Per_Cycle_Window ",
  "metrics": {
    "newSignals": 2,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify", "huly"],
      "seenSources": ["clockify", "huly"],
      "evaluated": true
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "runs": {
      "total": "10",
      "failed": "1"
    },
    "outcomes": {}
  }
}
JSON

status_output_failure_rate_root_fallback="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.failureRate == 0.65
  and .metrics.failureRateCurrent == 1
  and .metrics.failureRateScope == "per_cycle_window"
' <<< "$status_output_failure_rate_root_fallback" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:14:57Z",
  "lag": {
    "projectionLagSeconds": "12",
    "sources": [
      {
        "source": "clockify",
        "entity": "time_entries",
        "lastSyncAt": "2026-04-20T12:14:33Z",
        "lagSeconds": "15"
      }
    ]
  },
  "coverage": {
    "expectedSources": ["clockify", "huly"],
    "seenSources": ["clockify"],
    "evaluated": true,
    "ratio": 0.5
  },
  "quality": {
    "score": 91,
    "findingCount": 2,
    "findingsByType": [{"type": "timestamp_drift", "count": 2}]
  },
  "outcomes": {
    "resolved": 1,
    "partial": 1,
    "noChange": 1,
    "regressed": 0,
    "avgTimeToResolutionSeconds": 30,
    "recurrenceSignals": 2
  },
  "runs": {
    "total": 4,
    "failed": 1
  },
  "metrics": {
    "newSignals": 3,
    "skippedSignals": 1,
    "suppressedSignals": 0,
    "dispatchedSignals": 2,
    "errors": 0,
    "lag": "legacy_scalar_blob",
    "coverage": "legacy_scalar_blob",
    "quality": "legacy_scalar_blob",
    "outcomes": "legacy_scalar_blob",
    "runs": "legacy_scalar_blob"
  }
}
JSON

status_output_subcontainers_scalar_root_fallback="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.newSignals == 3
  and .metrics.skippedSignals == 1
  and .metrics.suppressedSignals == 0
  and .metrics.dispatchedSignals == 2
  and .metrics.errors == 0
  and .metrics.lag.projectionLagSeconds == 12
  and .metrics.lag.maxSourceLagSeconds == 15
  and .metrics.coverage.evaluated == true
  and .metrics.coverage.ratio == 0.5
  and .metrics.quality.score == 91
  and .metrics.quality.findingCount == 2
  and .metrics.outcomes.resolved == 1
  and .metrics.outcomes.partial == 1
  and .metrics.outcomes.noChange == 1
  and .metrics.outcomes.regressed == 0
  and .metrics.outcomes.validatedSignals == 3
  and .metrics.outcomes.avgTimeToResolutionSeconds == 30
  and .metrics.outcomes.recurrenceSignals == 2
  and .metrics.failureRate == 0.25
' <<< "$status_output_subcontainers_scalar_root_fallback" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:15:00Z",
  "metrics": {
    "newSignals": 2,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify", "huly"],
      "seenSources": ["clockify", "huly"],
      "evaluated": true
    },
    "quality": {
      "score": 88,
      "finding_count": "4",
      "findings_by_type": ["timestamp_drift", {"type": "orphan_owner", "count": "2"}]
    },
    "failureRate": 0.0,
    "outcomes": {}
  }
}
JSON

status_output_quality_snake_case_fields="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.quality.score == 88
  and .metrics.quality.findingCount == 4
  and .metrics.quality.findingsByType == [{"type":"orphan_owner","count":2},{"type":"timestamp_drift","count":1}]
' <<< "$status_output_quality_snake_case_fields" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:15:30Z",
  "metrics": {
    "newSignals": 2,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify", "huly"],
      "seenSources": ["clockify", "huly"],
      "evaluated": true
    },
    "quality": {
      "findingsByType": {
        "timestamp_drift": "2",
        "orphan_owner": 1
      }
    },
    "failureRate": 0.0,
    "outcomes": {}
  }
}
JSON

status_output_quality_findings_object_map="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.quality.score == 82
  and .metrics.quality.findingCount == 3
  and .metrics.quality.findingsByType == [{"type":"orphan_owner","count":1},{"type":"timestamp_drift","count":2}]
' <<< "$status_output_quality_findings_object_map" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:16:00Z",
  "metrics": {
    "newSignals": 2,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify", "huly"],
      "seenSources": ["clockify", "huly"],
      "evaluated": true
    },
    "quality": {
      "qualityScore": "91",
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.0,
    "outcomes": {}
  }
}
JSON

status_output_quality_score_camel_alias="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.quality.score == 91
  and .metrics.quality.findingCount == 0
  and .metrics.quality.findingsByType == []
' <<< "$status_output_quality_score_camel_alias" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:16:30Z",
  "quality": {
    "score": "77",
    "findingCount": "2",
    "findingsByType": ["orphan_owner", "orphan_owner"]
  },
  "metrics": {
    "newSignals": 2,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify", "huly"],
      "seenSources": ["clockify", "huly"],
      "evaluated": true
    },
    "failureRate": 0.0,
    "outcomes": {}
  }
}
JSON

status_output_quality_root_fallback="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.quality.score == 77
  and .metrics.quality.findingCount == 2
  and .metrics.quality.findingsByType == [{"type":"orphan_owner","count":2}]
' <<< "$status_output_quality_root_fallback" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:17:00Z",
  "metrics": {
    "newSignals": 2,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify", "huly"],
      "seenSources": ["clockify", "huly"],
      "evaluated": true
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.0,
    "outcomes": {
      "resolved": 0,
      "partial": 1,
      "no_change": "2",
      "regressed": "1",
      "avg_time_to_resolution_seconds": "45",
      "recurrence_signals": "3"
    }
  }
}
JSON

status_output_outcomes_alias_backfill="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.outcomes.resolved == 0
  and .metrics.outcomes.partial == 1
  and .metrics.outcomes.noChange == 2
  and .metrics.outcomes.regressed == 1
  and .metrics.outcomes.validatedSignals == 4
  and .metrics.outcomes.avgTimeToResolutionSeconds == 45
  and .metrics.outcomes.recurrenceSignals == 3
' <<< "$status_output_outcomes_alias_backfill" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:17:30Z",
  "outcomes": {
    "resolved": 2,
    "partial": 1,
    "no_change": "3",
    "regressed": 1,
    "avg_time_to_resolution_seconds": "30",
    "recurrence_signals": "4"
  },
  "metrics": {
    "newSignals": 2,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify", "huly"],
      "seenSources": ["clockify", "huly"],
      "evaluated": true
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.0
  }
}
JSON

status_output_outcomes_root_fallback="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.outcomes.resolved == 2
  and .metrics.outcomes.partial == 1
  and .metrics.outcomes.noChange == 3
  and .metrics.outcomes.regressed == 1
  and .metrics.outcomes.validatedSignals == 7
  and .metrics.outcomes.avgTimeToResolutionSeconds == 30
  and .metrics.outcomes.recurrenceSignals == 4
' <<< "$status_output_outcomes_root_fallback" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:16:00Z",
  "metrics": {
    "newSignals": 3,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify", "huly", "slack"],
      "seenSources": ["clockify", "huly", "slack"],
      "evaluated": true
    },
    "quality": {
      "findingsByType": [
        " TIMESTAMP_DRIFT ",
        {"type": " orphan_owner ", "count": "2"},
        {"type": "Stale_Mapping", "count": 1}
      ]
    }
  }
}
JSON

status_output_quality_type_trim_case_normalization="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.quality.findingCount == 4
  and .metrics.quality.findingsByType == [
    {"type":"orphan_owner","count":2},
    {"type":"stale_mapping","count":1},
    {"type":"timestamp_drift","count":1}
  ]
  and .metrics.quality.score == 62
' <<< "$status_output_quality_type_trim_case_normalization" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:18:00Z",
  "metrics": {
    "lag": {
      "projectionLagSeconds": null,
      "sources": [
        {
          "source": "clockify",
          "entity": "time_entries",
          "lastSyncAt": "2026-04-20T12:14:33Z",
          "lagSeconds": 4000
        },
        {
          "source": "huly",
          "entity": "issues",
          "lagSeconds": null
        }
      ]
    },
    "coverage": {
      "expectedSources": ["clockify"],
      "seenSources": ["clockify"],
      "evaluated": true
    },
    "runs": {
      "total": 0,
      "failed": 0
    }
  }
}
JSON

status_output_core_metrics_backfill="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.newSignals == 0
  and .metrics.skippedSignals == 0
  and .metrics.suppressedSignals == 0
  and .metrics.dispatchedSignals == 0
  and .metrics.errors == 0
  and .metrics.lag.maxSourceLagSeconds == 4000
  and .metrics.coverage.ratio == 1
  and .metrics.failureRate == 0
  and .alerts.maxLagWarning == true
  and .alerts.failureRateWarning == false
  and .alerts.coverageWarning == false
' <<< "$status_output_core_metrics_backfill" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:21:00Z",
  "metrics": {
    "newSignals": "2",
    "skippedSignals": "1",
    "suppressedSignals": "0",
    "dispatchedSignals": "1",
    "errors": "0",
    "lag": {
      "sources": [
        {
          "source": "clockify",
          "entity": "time_entries",
          "lagSeconds": "7205"
        }
      ]
    },
    "coverage": {
      "expectedSources": ["clockify"],
      "seenSources": ["clockify"],
      "evaluated": true
    },
    "quality": {
      "score": "150",
      "findingCount": "-5",
      "findingsByType": [{"type": "orphan_owner", "count": "2"}]
    },
    "failureRate": "1.7",
    "failureRateCurrent": "3",
    "outcomes": {
      "resolved": "2",
      "partial": "0",
      "no-change": "1",
      "regressed": "0",
      "validatedSignals": "-2",
      "avgTimeToResolutionSeconds": "-10",
      "recurrenceSignals": "-4"
    }
  }
}
JSON

status_output_numeric_coercion="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.newSignals == 2
  and .metrics.skippedSignals == 1
  and .metrics.suppressedSignals == 0
  and .metrics.dispatchedSignals == 1
  and .metrics.errors == 0
  and .metrics.lag.maxSourceLagSeconds == 7205
  and .metrics.quality.score == 100
  and .metrics.quality.findingCount == 2
  and .metrics.quality.findingsByType == [{"type":"orphan_owner","count":2}]
  and .metrics.failureRate == 1
  and .metrics.failureRateCurrent == 1
  and .metrics.outcomes.resolved == 2
  and .metrics.outcomes.noChange == 1
  and .metrics.outcomes.validatedSignals == 0
  and .metrics.outcomes.avgTimeToResolutionSeconds == null
  and .metrics.outcomes.recurrenceSignals == 0
  and .alerts.maxLagWarning == true
' <<< "$status_output_numeric_coercion" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:24:00Z",
  "metrics": {
    "newSignals": 5,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 2,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify", "clockify", 123, null, "huly"],
      "seenSources": ["clockify", 123, "clockify", ""],
      "evaluated": "true"
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.0,
    "outcomes": {}
  }
}
JSON

status_output_coverage_normalization="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.coverage.evaluated == true
  and .metrics.coverage.expectedSources == ["123","clockify","huly"]
  and .metrics.coverage.seenSources == ["123","clockify"]
  and (.metrics.coverage.ratio > 0.66 and .metrics.coverage.ratio < 0.67)
  and .alerts.coverageWarning == false
' <<< "$status_output_coverage_normalization" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:25:30Z",
  "metrics": {
    "newSignals": 3,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expected_sources": ["clockify", "huly"],
      "seen_sources": ["huly", "clockify"],
      "evaluated": true
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.0,
    "outcomes": {}
  }
}
JSON

status_output_coverage_snake_case_keys="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.coverage.evaluated == true
  and .metrics.coverage.expectedSources == ["clockify","huly"]
  and .metrics.coverage.seenSources == ["clockify","huly"]
  and .metrics.coverage.ratio == 1
  and .alerts.coverageWarning == false
' <<< "$status_output_coverage_snake_case_keys" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:25:00Z",
  "metrics": {
    "newSignals": 4,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 2,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": [" Clockify ", "huly", " SLACK", "clockify", ""],
      "seenSources": [" clockify", "HULY ", "slack ", null],
      "evaluated": true
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.0,
    "outcomes": {}
  }
}
JSON

status_output_coverage_source_trim_case_normalization="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.coverage.evaluated == true
  and .metrics.coverage.expectedSources == ["clockify","huly","slack"]
  and .metrics.coverage.seenSources == ["clockify","huly","slack"]
  and .metrics.coverage.ratio == 1
  and .alerts.coverageWarning == false
' <<< "$status_output_coverage_source_trim_case_normalization" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:26:00Z",
  "metrics": {
    "newSignals": 5,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 2,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify", "huly", "slack"],
      "seenSources": ["clockify"],
      "evaluated": "false"
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.0,
    "outcomes": {}
  }
}
JSON

status_output_coverage_evaluated_string_false="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.coverage.evaluated == false
  and .metrics.coverage.ratio == null
  and .alerts.coverageWarning == false
' <<< "$status_output_coverage_evaluated_string_false" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:27:00Z",
  "metrics": {
    "newSignals": 5,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 2,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify", "huly", "slack"],
      "seenSources": ["clockify"],
      "evaluated": false
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.0,
    "outcomes": {}
  }
}
JSON

status_output_coverage_evaluated_bool_false="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.coverage.evaluated == false
  and .metrics.coverage.ratio == null
  and .alerts.coverageWarning == false
' <<< "$status_output_coverage_evaluated_bool_false" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:27:30Z",
  "metrics": {
    "newSignals": 5,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 2,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify", "huly", "slack"],
      "seenSources": ["clockify"],
      "is_evaluated": "false"
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.0,
    "outcomes": {}
  }
}
JSON

status_output_coverage_is_evaluated_snake_case="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.coverage.evaluated == false
  and .metrics.coverage.ratio == null
  and .alerts.coverageWarning == false
' <<< "$status_output_coverage_is_evaluated_snake_case" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:27:45Z",
  "metrics": {
    "newSignals": 5,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 2,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify", "huly", "slack"],
      "seenSources": ["clockify"],
      "isEvaluated": "false"
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.0,
    "outcomes": {}
  }
}
JSON

status_output_coverage_is_evaluated_camel_case="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.coverage.evaluated == false
  and .metrics.coverage.ratio == null
  and .alerts.coverageWarning == false
' <<< "$status_output_coverage_is_evaluated_camel_case" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:27:50Z",
  "metrics": {
    "newSignals": 5,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 2,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify", "huly", "slack"],
      "seenSources": ["clockify"],
      "coverageEvaluated": "false"
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.0,
    "outcomes": {}
  }
}
JSON

status_output_coverage_coverage_evaluated_camel_case="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.coverage.evaluated == false
  and .metrics.coverage.ratio == null
  and .alerts.coverageWarning == false
' <<< "$status_output_coverage_coverage_evaluated_camel_case" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:28:00Z",
  "metrics": {
    "newSignals": 3,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify", "huly"],
      "seenSources": ["clockify"],
      "evaluated": true,
      "ratio": "1.8"
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.0,
    "outcomes": {}
  }
}
JSON

status_output_coverage_ratio_clamp_high="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.coverage.evaluated == true
  and .metrics.coverage.ratio == 1
  and .alerts.coverageWarning == false
' <<< "$status_output_coverage_ratio_clamp_high" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:30:00Z",
  "metrics": {
    "newSignals": 3,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify", "huly"],
      "seenSources": ["clockify"],
      "evaluated": true,
      "ratio": "-0.4"
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.0,
    "outcomes": {}
  }
}
JSON

status_output_coverage_ratio_clamp_low="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.coverage.evaluated == true
  and .metrics.coverage.ratio == 0
  and .alerts.coverageWarning == true
' <<< "$status_output_coverage_ratio_clamp_low" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:32:00Z",
  "metrics": {
    "newSignals": 2,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 1,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": 7200,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify", "huly"],
      "seenSources": ["clockify"],
      "evaluated": true,
      "ratio": 0.5
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.0,
    "outcomes": {}
  },
  "alerts": {
    "maxLagWarning": "false",
    "failureRateWarning": 0,
    "coverageWarning": "no"
  }
}
JSON

status_output_alert_bool_coercion_false="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .alerts.maxLagWarning == false
  and .alerts.failureRateWarning == false
  and .alerts.coverageWarning == false
' <<< "$status_output_alert_bool_coercion_false" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:34:00Z",
  "metrics": {
    "newSignals": 1,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": 0,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify"],
      "seenSources": ["clockify"],
      "evaluated": true,
      "ratio": 1
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.0,
    "outcomes": {}
  },
  "alerts": {
    "maxLagWarning": "yes",
    "failureRateWarning": "1",
    "coverageWarning": "TRUE"
  }
}
JSON

status_output_alert_bool_coercion_true="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .alerts.maxLagWarning == true
  and .alerts.failureRateWarning == true
  and .alerts.coverageWarning == true
' <<< "$status_output_alert_bool_coercion_true" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:35:00Z",
  "metrics": {
    "newSignals": 1,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 1,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": 7205,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify", "huly"],
      "seenSources": ["clockify"],
      "evaluated": true,
      "ratio": 0.5
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.0,
    "outcomes": {}
  },
  "alerts": {
    "max_lag_warning": false,
    "failure_rate_warning": false,
    "coverage_warning": false
  }
}
JSON

status_output_alert_snake_case_keys="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .alerts.maxLagWarning == false
  and .alerts.failureRateWarning == false
  and .alerts.coverageWarning == false
' <<< "$status_output_alert_snake_case_keys" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:35:30Z",
  "max_lag_warning": false,
  "failureRateWarning": "no",
  "coverage_warning": 0,
  "metrics": {
    "newSignals": 1,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 1,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": 7205,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify", "huly"],
      "seenSources": ["clockify"],
      "evaluated": true,
      "ratio": 0.5
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.0,
    "outcomes": {}
  }
}
JSON

status_output_alert_root_keys="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .alerts.maxLagWarning == false
  and .alerts.failureRateWarning == false
  and .alerts.coverageWarning == false
' <<< "$status_output_alert_root_keys" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:36:00Z",
  "metrics": {
    "newSignals": 0,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 0,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify"],
      "seenSources": [],
      "evaluated": false
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.0,
    "failureRateCurrent": 0,
    "failureRateScope": 0,
    "outcomes": {}
  }
}
JSON

status_output_failure_scope_default="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.failureRateScope == "historical_lifetime_runs"
' <<< "$status_output_failure_scope_default" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:38:00Z",
  "metrics": {
    "newSignals": 0,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 0,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify"],
      "seenSources": [],
      "evaluated": false
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.0,
    "failureRateCurrent": 0,
    "failureRateScope": "  per_cycle_window  ",
    "outcomes": {}
  }
}
JSON

status_output_failure_scope_trimmed="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.failureRateScope == "per_cycle_window"
' <<< "$status_output_failure_scope_trimmed" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:39:00Z",
  "metrics": {
    "newSignals": 0,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 0,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify"],
      "seenSources": [],
      "evaluated": false
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.0,
    "failureRateCurrent": 0,
    "failureRateScope": "  Historical_Lifetime_Runs  ",
    "outcomes": {}
  }
}
JSON

status_output_failure_scope_case_normalized="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.failureRateScope == "historical_lifetime_runs"
' <<< "$status_output_failure_scope_case_normalized" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:39:30Z",
  "metrics": {
    "newSignals": 0,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 0,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": null,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify"],
      "seenSources": [],
      "evaluated": false
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.0,
    "failureRateCurrent": 0,
    "failure_rate_scope": "  Per_Cycle_Window  ",
    "outcomes": {}
  }
}
JSON

status_output_failure_scope_snake_case="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.failureRateScope == "per_cycle_window"
' <<< "$status_output_failure_scope_snake_case" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:40:00Z",
  "metrics": {
    "newSignals": 0,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 0,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": "-9",
      "maxSourceLagSeconds": "-2",
      "sources": [
        {
          "source": 42,
          "entity": 7,
          "lastSyncAt": 12345,
          "lagSeconds": "-11"
        }
      ]
    },
    "coverage": {
      "expectedSources": ["clockify"],
      "seenSources": [],
      "evaluated": false
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.0,
    "failureRateCurrent": 0,
    "failureRateScope": "historical_lifetime_runs",
    "outcomes": {}
  }
}
JSON

status_output_lag_numeric_normalization="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.lag.projectionLagSeconds == 0
  and .metrics.lag.maxSourceLagSeconds == 0
  and .metrics.lag.sources == [{"source":"42","entity":"7","lastSyncAt":"12345","lagSeconds":0}]
  and .alerts.maxLagWarning == false
' <<< "$status_output_lag_numeric_normalization" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:40:30Z",
  "metrics": {
    "newSignals": 0,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 0,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": "4",
      "maxSourceLagSeconds": "9",
      "sources": "legacy_scalar_blob"
    },
    "coverage": {
      "expectedSources": ["clockify"],
      "seenSources": [],
      "evaluated": false
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.0,
    "failureRateCurrent": 0,
    "failureRateScope": "historical_lifetime_runs",
    "outcomes": {}
  }
}
JSON

status_output_lag_sources_scalar_container="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.lag.projectionLagSeconds == 4
  and .metrics.lag.maxSourceLagSeconds == 9
  and .metrics.lag.sources == [{"source":"legacy_scalar_blob","entity":null,"lastSyncAt":null,"lagSeconds":null}]
  and .alerts.maxLagWarning == false
' <<< "$status_output_lag_sources_scalar_container" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:40:40Z",
  "metrics": {
    "newSignals": 0,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 0,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": "6",
      "maxSourceLagSeconds": null,
      "sources": {
        "source": " Huly ",
        "entity": " issues ",
        "last_sync_at": " 2026-04-20T12:40:44Z ",
        "lag_seconds": "15"
      }
    },
    "coverage": {
      "expectedSources": ["clockify"],
      "seenSources": [],
      "evaluated": false
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.0,
    "failureRateCurrent": 0,
    "failureRateScope": "historical_lifetime_runs",
    "outcomes": {}
  }
}
JSON

status_output_lag_sources_object_container="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.lag.projectionLagSeconds == 6
  and .metrics.lag.maxSourceLagSeconds == 15
  and .metrics.lag.sources == [{"source":"huly","entity":"issues","lastSyncAt":"2026-04-20T12:40:44Z","lagSeconds":15}]
  and .alerts.maxLagWarning == false
' <<< "$status_output_lag_sources_object_container" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:40:50Z",
  "metrics": {
    "newSignals": 0,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 0,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": "8",
      "maxSourceLagSeconds": null,
      "sources": {
        "clockify": {
          "entity": " time_entries ",
          "last_sync_at": " 2026-04-20T12:40:46Z ",
          "lag_seconds": "22"
        },
        "huly": 11
      }
    },
    "coverage": {
      "expectedSources": ["clockify"],
      "seenSources": [],
      "evaluated": false
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.0,
    "failureRateCurrent": 0,
    "failureRateScope": "historical_lifetime_runs",
    "outcomes": {}
  }
}
JSON

status_output_lag_sources_object_map_container="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.lag.projectionLagSeconds == 8
  and .metrics.lag.maxSourceLagSeconds == 22
  and ((.metrics.lag.sources | sort_by(.source)) == [
    {"source":"clockify","entity":"time_entries","lastSyncAt":"2026-04-20T12:40:46Z","lagSeconds":22},
    {"source":"huly","entity":null,"lastSyncAt":null,"lagSeconds":11}
  ])
  and .alerts.maxLagWarning == false
' <<< "$status_output_lag_sources_object_map_container" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:40:51Z",
  "metrics": {
    "newSignals": 0,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 0,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": "9",
      "maxSourceLagSeconds": null,
      "sources": {
        "clockify": {
          "lag_seconds": "12"
        },
        "huly": false,
        "slack": true
      }
    },
    "coverage": {
      "expectedSources": ["clockify"],
      "seenSources": [],
      "evaluated": false
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.0,
    "failureRateCurrent": 0,
    "failureRateScope": "historical_lifetime_runs",
    "outcomes": {}
  }
}
JSON

status_output_lag_sources_object_map_bool_filter="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.lag.projectionLagSeconds == 9
  and .metrics.lag.maxSourceLagSeconds == 12
  and .metrics.lag.sources == [{"source":"clockify","entity":null,"lastSyncAt":null,"lagSeconds":12}]
  and .alerts.maxLagWarning == false
' <<< "$status_output_lag_sources_object_map_bool_filter" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:40:52Z",
  "metrics": {
    "newSignals": 0,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 0,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": "7",
      "maxSourceLagSeconds": null,
      "sources": {
        "sources": [
          {
            "source": " Clockify ",
            "entity": " time_entries ",
            "last_sync_at": " 2026-04-20T12:40:47Z ",
            "lag_seconds": "18"
          },
          "huly"
        ]
      }
    },
    "coverage": {
      "expectedSources": ["clockify"],
      "seenSources": [],
      "evaluated": false
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.0,
    "failureRateCurrent": 0,
    "failureRateScope": "historical_lifetime_runs",
    "outcomes": {}
  }
}
JSON

status_output_lag_sources_nested_wrapper="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.lag.projectionLagSeconds == 7
  and .metrics.lag.maxSourceLagSeconds == 18
  and ((.metrics.lag.sources | sort_by(.source)) == [
    {"source":"clockify","entity":"time_entries","lastSyncAt":"2026-04-20T12:40:47Z","lagSeconds":18},
    {"source":"huly","entity":null,"lastSyncAt":null,"lagSeconds":null}
  ])
  and .alerts.maxLagWarning == false
' <<< "$status_output_lag_sources_nested_wrapper" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:40:54Z",
  "metrics": {
    "newSignals": 0,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 0,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": "10",
      "maxSourceLagSeconds": null,
      "sources": [
        {
          "entity": "ghost",
          "lagSeconds": "500"
        },
        {
          "source": " clockify ",
          "lag_seconds": "45"
        }
      ]
    },
    "coverage": {
      "expectedSources": ["clockify"],
      "seenSources": [],
      "evaluated": false
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.0,
    "failureRateCurrent": 0,
    "failureRateScope": "historical_lifetime_runs",
    "outcomes": {}
  }
}
JSON

status_output_lag_max_ignores_null_source_rows="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.lag.projectionLagSeconds == 10
  and .metrics.lag.maxSourceLagSeconds == 45
  and .metrics.lag.sources == [
    {"source":null,"entity":"ghost","lastSyncAt":null,"lagSeconds":500},
    {"source":"clockify","entity":null,"lastSyncAt":null,"lagSeconds":45}
  ]
  and .alerts.maxLagWarning == false
' <<< "$status_output_lag_max_ignores_null_source_rows" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:41:00Z",
  "metrics": {
    "newSignals": 0,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 0,
    "errors": 0,
    "lag": {
      "projection_lag_seconds": "45",
      "max_source_lag_seconds": null,
      "sources": [
        {
          "source": " Clockify ",
          "entity": " time_entries ",
          "last_sync_at": " 2026-04-20T12:40:55Z ",
          "lag_seconds": "90"
        }
      ]
    },
    "coverage": {
      "expectedSources": ["clockify"],
      "seenSources": [],
      "evaluated": false
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.0,
    "failureRateCurrent": 0,
    "failureRateScope": "historical_lifetime_runs",
    "outcomes": {}
  }
}
JSON

status_output_lag_snake_case_fields="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.lag.projectionLagSeconds == 45
  and .metrics.lag.maxSourceLagSeconds == 90
  and .metrics.lag.sources == [{"source":"clockify","entity":"time_entries","lastSyncAt":"2026-04-20T12:40:55Z","lagSeconds":90}]
  and .alerts.maxLagWarning == false
' <<< "$status_output_lag_snake_case_fields" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:42:00Z",
  "metrics": {
    "newSignals": 0,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 0,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "sources": [
        "clockify",
        88,
        false,
        true,
        {
          "source": "huly",
          "entity": "issues",
          "lagSeconds": 123
        }
      ]
    },
    "coverage": {
      "expectedSources": ["clockify"],
      "seenSources": [],
      "evaluated": false
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.0,
    "failureRateCurrent": 0,
    "failureRateScope": "historical_lifetime_runs",
    "outcomes": {}
  }
}
JSON

status_output_lag_source_scalar_rows="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.lag.maxSourceLagSeconds == 123
  and .metrics.lag.sources == [
    {"source":"clockify","entity":null,"lastSyncAt":null,"lagSeconds":null},
    {"source":"88","entity":null,"lastSyncAt":null,"lagSeconds":null},
    {"source":"huly","entity":"issues","lastSyncAt":null,"lagSeconds":123}
  ]
  and .alerts.maxLagWarning == false
' <<< "$status_output_lag_source_scalar_rows" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:42:30Z",
  "metrics": {
    "newSignals": 0,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 0,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "lag_sources": [
        {
          "source": "clockify",
          "entity": "time_entries",
          "lastSyncAt": "2026-04-20T12:14:33Z",
          "lagSeconds": 77
        }
      ]
    },
    "coverage": {
      "expectedSources": ["clockify"],
      "seenSources": [],
      "evaluated": false
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.0,
    "failureRateCurrent": 0,
    "failureRateScope": "historical_lifetime_runs",
    "outcomes": {}
  }
}
JSON

status_output_lag_sources_snake_case_array="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.lag.maxSourceLagSeconds == 77
  and .metrics.lag.sources == [{"source":"clockify","entity":"time_entries","lastSyncAt":"2026-04-20T12:14:33Z","lagSeconds":77}]
  and .alerts.maxLagWarning == false
' <<< "$status_output_lag_sources_snake_case_array" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:42:45Z",
  "metrics": {
    "newSignals": 0,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 0,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "lagSources": [
        {
          "source": "clockify",
          "entity": "time_entries",
          "lastSyncAt": "2026-04-20T12:14:36Z",
          "lagSeconds": 81
        }
      ]
    },
    "coverage": {
      "expectedSources": ["clockify"],
      "seenSources": [],
      "evaluated": false
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.0,
    "failureRateCurrent": 0,
    "failureRateScope": "historical_lifetime_runs",
    "outcomes": {}
  }
}
JSON

status_output_lag_sources_camel_case_array="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.lag.maxSourceLagSeconds == 81
  and .metrics.lag.sources == [{"source":"clockify","entity":"time_entries","lastSyncAt":"2026-04-20T12:14:36Z","lagSeconds":81}]
  and .alerts.maxLagWarning == false
' <<< "$status_output_lag_sources_camel_case_array" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:42:50Z",
  "lag": {
    "projectionLagSeconds": "33",
    "sources": [
      {
        "source": "clockify",
        "entity": "time_entries",
        "lastSyncAt": "2026-04-20T12:15:10Z",
        "lagSeconds": "64"
      }
    ]
  },
  "metrics": {
    "newSignals": 0,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 0,
    "errors": 0,
    "coverage": {
      "expectedSources": ["clockify"],
      "seenSources": [],
      "evaluated": false
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.0,
    "failureRateCurrent": 0,
    "failureRateScope": "historical_lifetime_runs",
    "outcomes": {}
  }
}
JSON

status_output_lag_root_fallback="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.lag.projectionLagSeconds == 33
  and .metrics.lag.maxSourceLagSeconds == 64
  and .metrics.lag.sources == [{"source":"clockify","entity":"time_entries","lastSyncAt":"2026-04-20T12:15:10Z","lagSeconds":64}]
  and .alerts.maxLagWarning == false
' <<< "$status_output_lag_root_fallback" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:43:00Z",
  "metrics": {
    "newSignals": 0,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 0,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "sources": [
        {
          "source": " Clockify ",
          "entity": " time_entries ",
          "lastSyncAt": " 2026-04-20T12:14:33Z ",
          "lagSeconds": 50
        },
        " HULY "
      ]
    },
    "coverage": {
      "expectedSources": ["clockify"],
      "seenSources": [],
      "evaluated": false
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.0,
    "failureRateCurrent": 0,
    "failureRateScope": "historical_lifetime_runs",
    "outcomes": {}
  }
}
JSON

status_output_lag_source_trim_case_normalization="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.lag.maxSourceLagSeconds == 50
  and .metrics.lag.sources == [
    {"source":"clockify","entity":"time_entries","lastSyncAt":"2026-04-20T12:14:33Z","lagSeconds":50},
    {"source":"huly","entity":null,"lastSyncAt":null,"lagSeconds":null}
  ]
  and .alerts.maxLagWarning == false
' <<< "$status_output_lag_source_trim_case_normalization" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:44:00Z",
  "metrics": {
    "newSignals": 2,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 1,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": 7201,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify", "huly"],
      "seenSources": ["clockify"],
      "evaluated": true,
      "ratio": 0.5
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.0,
    "outcomes": {}
  },
  "alerts": {
    "maxLagWarning": "maybe",
    "failureRateWarning": "unknown",
    "coverageWarning": "n/a"
  }
}
JSON

status_output_alert_unknown_string_fallback="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .alerts.maxLagWarning == true
  and .alerts.failureRateWarning == true
  and .alerts.coverageWarning == true
' <<< "$status_output_alert_unknown_string_fallback" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:46:00Z",
  "metrics": {
    "newSignals": 2,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 1,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": 7201,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify", "huly"],
      "seenSources": ["clockify"],
      "evaluated": true,
      "ratio": 0.5
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.0,
    "outcomes": {}
  },
  "alerts": {
    "maxLagWarning": " false ",
    "failureRateWarning": " no ",
    "coverageWarning": " 0 "
  }
}
JSON

status_output_alert_whitespace_bool="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .alerts.maxLagWarning == false
  and .alerts.failureRateWarning == false
  and .alerts.coverageWarning == false
' <<< "$status_output_alert_whitespace_bool" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:48:00Z",
  "metrics": {
    "newSignals": 2,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": 0,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify", "huly"],
      "seenSources": ["clockify"],
      "evaluated": " maybe "
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.0,
    "outcomes": {}
  }
}
JSON

status_output_coverage_evaluated_unknown_fallback="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.coverage.evaluated == true
  and (.metrics.coverage.ratio > 0.49 and .metrics.coverage.ratio < 0.51)
  and .alerts.coverageWarning == true
' <<< "$status_output_coverage_evaluated_unknown_fallback" >/dev/null

cat > "$TMP_ROOT/.thoughtseed/teamforge/health.json" <<'JSON'
{
  "schemaVersion": "teamforge-health/v1",
  "generatedAt": "2026-04-20T12:50:00Z",
  "metrics": {
    "newSignals": 2,
    "skippedSignals": 0,
    "suppressedSignals": 0,
    "dispatchedSignals": 1,
    "errors": 0,
    "lag": {
      "projectionLagSeconds": null,
      "maxSourceLagSeconds": 0,
      "sources": []
    },
    "coverage": {
      "expectedSources": ["clockify", "huly"],
      "seenSources": ["clockify"],
      "evaluated": " false ",
      "ratio": "0.5"
    },
    "quality": {
      "score": 100,
      "findingCount": 0,
      "findingsByType": []
    },
    "failureRate": 0.0,
    "outcomes": {}
  }
}
JSON

status_output_coverage_evaluated_whitespace_false="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/teamforge-sync.sh status
)"

jq -e '
  .metrics.coverage.evaluated == false
  and .metrics.coverage.ratio == null
  and .alerts.coverageWarning == false
' <<< "$status_output_coverage_evaluated_whitespace_false" >/dev/null
