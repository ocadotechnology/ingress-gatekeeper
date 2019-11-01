#!/usr/bin/env bash

get_gcp_external_ips() {
  declare desc="take json output of 'gcloud compute instances list' and parse out the external IPs"
  jq '.[] | .networkInterfaces[0].accessConfigs[0].natIP' -r
}

get_handler_ips() {
  declare desc="take json output of istio handler and output ips"
  jq '.spec.params.overrides' -rc
}

make_ip_range() {
  declare desc="output list of ip ranges where plain ips are provided"
  sed -e '/\/[0-9][0-9]*$/!s/$/\/32/'
}

build_handler() {
  declare desc="create an istio handler object from the listchecker adapter with a json list of ips"
  local handler_name="$1"
  jq --arg name "$handler_name" '{apiVersion: "config.istio.io/v1alpha2", kind: "handler", metadata: {name: $name}, spec: {compiledAdapter: "listchecker", params: {blacklist: false, entryType: "IP_ADDRESSES", overrides: .}}}'
}

drop_invalid_ips() {
  declare desc="Get a list of newline separated ip ranges, drop invalid ones \n and return curated list"
  sed -r '/^(((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1?[0-9][0-9]|[1-9]?[0-9]))(\/([8-9]|[1-2][0-9]|3[0-2]))([^0-9.]|$)/!d'
}

build_valid_ip_list() {
  declare desc="Get newline separated list of IPs, validated them and build a json list"
  drop_invalid_ips | sort | uniq
}

to_json_array() {
  declare desc="turn newline separate list to json array"
  jq -ncR '[inputs]' -r
}

T_make_ip_range() {
  local result="$(cat test/list_with_invalid_cidr | make_ip_range)"
  [[ "$result" == "104.199.71.226/32
35.205.60.205/32
null/32
notanip/32
10.0.0.0.0/24
127.0.0.1/32
0.0.0.0/8" ]]
}

T_drop_invalid_ips() {
  local result="$(cat test/list_with_invalid_cidr | drop_invalid_ips)"
  [[ "$result" == "104.199.71.226/32
35.205.60.205/32
0.0.0.0/8" ]]
}

T_get_gcp_external_ips() {
  local result="$(cat test/gcloud-instances.json | get_gcp_external_ips)"
  [[ "$result" == "104.199.71.226
35.205.60.205" ]]
}

T_get_handler_ips() {
  local result="$(cat test/handler-ips.json | get_handler_ips)"
  [[ "$result" == '["104.199.71.226","35.205.60.205"]' ]]
}

T_build_valid_ip_list() {
  local result="$(cat test/list_with_invalid_cidr | build_valid_ip_list)"
  [[ "$result" == "0.0.0.0/8
104.199.71.226/32
35.205.60.205/32" ]]
}

T_to_json_array() {
  local result="$(cat test/list_with_invalid_cidr | to_json_array)"
  [[ "$result" == '["104.199.71.226/32","35.205.60.205/32","null/32","notanip","10.0.0.0.0/24","127.0.0.1","0.0.0.0/8"]' ]]
}

T_build_handler() {
  local result="$(echo '["foo","bar"]' | build_handler foobar)"
  [[ "$result" == '{
  "apiVersion": "config.istio.io/v1alpha2",
  "kind": "handler",
  "metadata": {
    "name": "foobar"
  },
  "spec": {
    "compiledAdapter": "listchecker",
    "params": {
      "blacklist": false,
      "entryType": "IP_ADDRESSES",
      "overrides": [
        "foo",
        "bar"
      ]
    }
  }
}' ]]
}

loop() {

  local source_handlers="$1"
  local gcp_project_list="$2"
  local dest_handler="$3"

  readonly dynamic="/tmp/dynamic"
  readonly static="/tmp/static"
  readonly current="/tmp/current"
  readonly loop_delay_secs="60"

  while true; do
    sleep $loop_delay_secs
    # cleanup
    rm -f $dynamic $static $current $existing
    touch $dynamic
    # Get list of ips in the projects we want to whitelist
    for project in $gcp_project_list; do
      gcloud compute instances list --format=json --project=$project | get_gcp_external_ips | make_ip_range >> $dynamic
    done

    # debug
    echo "Dynamic list of IP ranges to whitelist: "
    cat $dynamic

    touch $static
    for source_handler in $source_handlers; do
      kubectl get handlers.config.istio.io $source_handler -o json | get_handler_ips | make_ip_range >> $static
    done

    echo "Static list of IP ranges to whitelist: "
    cat $static

    # build annotation string with sorted ips and static list
    cat $static $dynamic | build_valid_ip_list > $current

    echo "Combined sorted list of IP ranges to whitelist: "
    cat $current

    echo "Updating handler object for $dest_handler..."
    cat $current | to_json_array | build_handler $dest_handler | kubectl apply -f -

  done
}

main() {
  set -eo pipefail
  echo "Starting..."

  readonly authfile=/creds/auth.json

  [ -z "$GCP_PROJECT_IDS" ] && \
  [ -z "$SOURCE_HANDLER_NAMES" ] && \
  { echo "Must set GCP_PROJECT_IDS or SOURCE_HANDLER_NAMES" && exit 1; }
  [ ! -z "$GCP_PROJECT_IDS" ] && \
  [ ! -f $authfile ] && \
  { echo "Must provide credentials at $authfile if GCP_PROJECT_IDS is set" && exit 1; } 
  : "${DEST_HANDLER_NAME:?DEST_HANDLER_NAME is required}"

  if [ -f $authfile ]; then
    # authenticate to google cloud
    echo "Reading google service account from /creds/auth.json"
    gcloud auth activate-service-account --key-file $authfile
  fi

  loop "${SOURCE_HANDLER_NAMES:-}" "${GCP_PROJECT_IDS:-}" "$DEST_HANDLER_NAME"
}

[[ "$TRACE" ]] && set -x
[[ "$0" == "$BASH_SOURCE" ]] && main "$@"
