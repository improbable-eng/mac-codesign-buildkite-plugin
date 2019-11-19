#!/bin/bash 

# These are shameless lifted from https://github.com/buildkite-plugins/docker-compose-buildkite-plugin/blob/master/lib/shared.bash
# Reads either a value or a list from plugin config
function plugin_read_list() {
  prefix_read_list "BUILDKITE_PLUGIN_MAC_CODESIGN_$1"
}

# Reads either a value or a list from the given env prefix
function prefix_read_list() {
  local prefix="$1"
  local parameter="${prefix}_0"

  if [[ -n "${!parameter:-}" ]]; then
    local i=0
    local parameter="${prefix}_${i}"
    while [[ -n "${!parameter:-}" ]]; do
      echo "${!parameter}"
      i=$((i+1))
      parameter="${prefix}_${i}"
    done
  elif [[ -n "${!prefix:-}" ]]; then
    echo "${!prefix}"
  fi
}
