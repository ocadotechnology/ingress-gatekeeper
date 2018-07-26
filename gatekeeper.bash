#!/usr/bin/env bash

get_gcp_external_ip_ranges() {
  declare desc="take json output of 'gcloud compute instances list' and parse out the external IPs adding /32 to each"
  jq '.[] | .networkInterfaces[0].accessConfigs[0].natIP' -r | sed 's_$_/32_'
}

get_whitelist_annotation_ranges() {
  declare desc="take json output of 'kubectl get ingress ingress_name' and parse out the whitelist ranges"
  jq '.metadata.annotations["nginx.ingress.kubernetes.io/whitelist-source-range"]' -r | head -c -1
}

build_annotation_patch() {
  declare desc="build ingress annotation patch json from list of ranges"
  local whitelist_source_range="$1"
  jq -n --arg wsr "$whitelist_source_range" '{metadata: {annotations: {"nginx.ingress.kubernetes.io/whitelist-source-range": $wsr, "ingress.kubernetes.io/whitelist-source-range": $wsr}}}'
}

space_sep_to_nl() {
  declare desc="take space separated list and replace spaces with /n"
  sed 's_ _\n_'
}

nl_sep_to_comma() {
  declare desc="take new line separated list, remove empty lines, sort, then replace /n with comma"
  sort | uniq | sed -e '/^$/d' -e 's|$|,|' | tr '\n' ' ' | head -c -2
}

T_get_gcp_external_ip_ranges() {
  local result="$(cat test/gcloud-instances.json | get_gcp_external_ip_ranges)"
  [[ "$result" == "104.199.71.226/32
35.205.60.205/32" ]]
}

T_get_whitelist_annotation_ranges() {
  local result="$(cat test/ingress.json | get_whitelist_annotation_ranges)"
  [[ "$result" == "192.168.0.0/24, 192.168.5.0/24, 35.205.194.164/32, 35.233.113.241/32" ]]
}

T_build_annotation_patch() {
  local result="$(build_annotation_patch '192.168.0.0/24')"
  [[ "$result" == '{
  "metadata": {
    "annotations": {
      "nginx.ingress.kubernetes.io/whitelist-source-range": "192.168.0.0/24",
      "ingress.kubernetes.io/whitelist-source-range": "192.168.0.0/24"
    }
  }
}' ]]
}

T_space_sep_to_nl(){
  local result="$(cat test/space_sep.txt | space_sep_to_nl)"
  [[ "$result" == "thing1
thing2
thing3" ]]
}

T_nl_sep_to_comma() {
  local result="$(cat test/nl_sep.txt | nl_sep_to_comma)"
  [[ "$result" == "line1, line2" ]]
}

loop() {

  local static_ranges="$1"
  local gcp_project_list="$2"
  local ingress_names="$3"

  readonly dynamic="/tmp/dynamic"
  readonly static="/tmp/static"
  readonly current="/tmp/current"
  readonly existing="/tmp/existing"
  readonly loop_delay_secs="60"

  while true; do
    sleep $loop_delay_secs
    # cleanup
    rm -f $dynamic $static $current $existing
    # Get list of ips in the projects we want to whitelist
    for project in $gcp_project_list; do
      gcloud compute instances list --format=json --project=$project | get_gcp_external_ip_ranges >> $dynamic
    done

    # debug
    echo "Dynamic list of IP ranges to whitelist: "
    cat $dynamic

    echo "$static_ranges" | space_sep_to_nl > $static

    echo "Static list of IP ranges to whitelist: "
    cat $static

    # build annotation string with sorted ips and static list
    cat $static $dynamic | nl_sep_to_comma > $current

    echo "Combined sorted list of IP ranges to whitelist: "
    cat $current

    # get ingresses to update
    for ingress in $ingress_names; do
      kubectl get ingress $ingress -o json | get_whitelist_annotation_ranges > $existing
      echo
      echo "Existing white list for $ingress: "
      cat $existing

      # compare list of ips with existing
      echo
      echo "Comparing lists for $ingress: "
      if diff $existing $current; then
        echo "No changes in listed ips for $ingress"
        continue
      fi

      # apply annotation to ingresses if different
      echo "Updating ingress annotation for $ingress..."
      kubectl patch ingress $ingress -p "$( build_annotation_patch "$(<$current)" )"
    done
  done
}

main() {
  set -eo pipefail; [[ "$TRACE" ]] && set -x

  : "${GCP_PROJECT_IDS:?GCP_PROJECT_IDS is required}"
  : "${INGRESS_NAMES:?INGRESS_NAMES is required}"

  echo "Starting..."
  # authenticate to google cloud
  echo "Reading google service account from /creds/auth.json"
  gcloud auth activate-service-account --key-file /creds/auth.json

  loop "${STATIC_IP_RANGES:-}" "$GCP_PROJECT_IDS" "$INGRESS_NAMES"
}

[[ "$0" == "$BASH_SOURCE" ]] && main "$@"
