#!/usr/bin/env bash
#
# If required, this script fetches a secret from Improbable's Vault
# using our imp-ci tool and echos it to stdout.

[[ -n "${DEBUG-}" ]] && set -x

# All decryption password secrets must live under this path
keychain_pw_root="secret/sync.v1/dev-workflow/production-buildkite/buildkite-agents/cert-decryption-password/"
keychain_pw_name="${1}"
keychain_pw_path="${keychain_pw_root}/${keychain_pw_name}"

# Get the keychain password from Vault
keychain_pw=$(imp-vault read-key --key="${keychain_pw_path}" --field=token)
if [[ $? -ne 0 || "${keychain_pw}" == "" ]]; then
  echo "Unable to read specified secret ${pw_secret}"
  exit 1
else
  echo "${keychain_pw}"
fi
