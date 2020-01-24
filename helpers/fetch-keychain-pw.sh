#!/usr/bin/env bash
#
# If required, this script fetches a secret from Improbable's Vault
# using our imp-ci tool and echos it to stdout.

[[ -n "${DEBUG-}" ]] && set -x

# All decryption password secrets must live under this path
keychain_pw_root="secret/sync.v1/dev-workflow/production-buildkite/buildkite-agents/cert-decryption-password/"
keychain_pw_secret="${BUILDKITE_PLUGIN_MAC_CODESIGN_SIGNING_CERT_PW_SECRET}"
keychain_pw_name="${1}"
keychain_pw_path="${keychain_pw_root}/${keychain_pw_name}"

export GOOGLE_APPLICATION_CREDENTIALS="/Users/Shared/secrets/service-account.json"
export VAULT_ADDR="https://vault-external.stable.i8e.io:8200"

# Get the keychain password from Vault
if ! keychain_pw=$(imp-vault read-key --key="${keychain_pw_path}" --field=token --vault_role="continuous-integration-production-improbable-iam"); then
  echo "Unable to read specified secret ${keychain_pw_secret}"
  exit 1
else
  echo "${keychain_pw}"
fi
