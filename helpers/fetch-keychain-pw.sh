#!/usr/bin/env bash
#
# If required, this script fetches a secret from Improbable's Vault
# using our imp-ci tool and echos it to stdout.

[[ -n "${DEBUG-}" ]] && set -x

# All decryption password secrets must live under this path
keychain_pw_root="secret/sync.v1/dev-workflow/production-buildkite/buildkite-agents/cert-decryption-password/"
keychain_pw_name="${BUILDKITE_PLUGIN_MAC_CODESIGN_KEYCHAIN_PW_SECRET_NAME}"
keychain_pw_path="${keychain_pw_root}/${keychain_pw_name}"

# Get the keychain password from Vault
if ! keychain_pw=$(imp-vault read-key --key="${keychain_pw_path}" --field=token --vault_role="continuous-integration-production-improbable-iam"); then
  echo "Unable to read specified secret ${keychain_pw_name}"
  exit 1
else
  echo "${keychain_pw}"
fi
