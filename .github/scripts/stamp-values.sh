#!/usr/bin/env bash
# Builds one stamp value of 08 section 2 from the Environment lz-<lz>.
#
#   stamp-values.sh data_access | app_repo_ids | origin_cert_versions | edge_hostnames | alert_action_group_ids < variables.json
#   stamp-values.sh origin_certs < secrets.json
#
# Reads a JSON object of names to values on stdin: the Environment's variables
# (shared-plan.yml reads them through tl-landingzones-plan, shared-apply.yml from
# the vars context), or its secrets for origin_certs (shared-apply.yml only).
# Prints the value as compact JSON on one line.
set -euo pipefail
case "${1:-}" in
  data_access)
    jq -c '{readers: (.DATA_READERS_OBJECT_ID // ""), admins: (.DATA_ADMINS_OBJECT_ID // "")}' ;;
  app_repo_ids)
    # {} while global/github hasn't written the variable yet (ADR 0038).
    jq -c '(.APP_REPO_IDS // "{}") | fromjson
      | if type == "object" and all(.[]; type == "number") then . else error("APP_REPO_IDS is not a map of repository names to IDs") end' ;;
  origin_cert_versions)
    # ORIGIN_CERT_<ZONE>_VERSION -> {"<ZONE>": <integer>}; {} while global/edge has written none (ADR 0027).
    jq -c 'to_entries | map(select(.key | test("^ORIGIN_CERT_[A-Z0-9_]+_VERSION$"))
      | {key: (.key | sub("^ORIGIN_CERT_"; "") | sub("_VERSION$"; "")), value: (.value | tonumber)}) | from_entries' ;;
  edge_hostnames)
    # [] while global/edge hasn't written the variable yet (ADR 0027).
    jq -c '(.EDGE_HOSTNAMES // "[]") | fromjson
      | if type == "array" and all(.[]; type == "string") then . else error("EDGE_HOSTNAMES is not a list of hostnames") end' ;;
  alert_action_group_ids)
    # [] in a sandbox landing zone, and while landing-zones/_root hasn't written the variable yet (06 section 6.8).
    jq -c '(.ALERT_ACTION_GROUP_IDS // "[]") | fromjson
      | if type == "array" and all(.[]; type == "string") then . else error("ALERT_ACTION_GROUP_IDS is not a list of action group IDs") end' ;;
  origin_certs)
    # ORIGIN_CERT_<ZONE> -> {"<ZONE>": "<certificate and key PEM>"}. A credential: never printed by the caller.
    jq -c 'to_entries | map(select((.key | test("^ORIGIN_CERT_[A-Z0-9_]+$")) and (.key | test("_VERSION$") | not))
      | {key: (.key | sub("^ORIGIN_CERT_"; "")), value: .value}) | from_entries' ;;
  *)
    echo "usage: stamp-values.sh data_access|app_repo_ids|origin_cert_versions|edge_hostnames|alert_action_group_ids|origin_certs < values.json" >&2
    exit 2 ;;
esac
