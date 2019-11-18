# MacOS Code Signing Plugin

This allows us to perform the actual codesigning steps necessary to release MacOS software.

See [here](https://brevi.link/design-code-signing) for the general design that this fits into.

## Overview

This plugin relies upon the build agent already having the necessary keychains created on the machine.

Unfortunately, this is a necessity due to macos' insistence upon a one-time-per-key/keychain manual
intervention to approve access to the signing key before `codesign` can use it (even if the cert/key are imported with `codesign` pre-granted access to use it).

## Example use TODO(seanrobertson)

```yaml
- label: "sign-macos-binary"
  command: "" # No command needed here, since the `command` hook does the work.
  agents:
    - "queue=macos-codesigner"
  artifact_paths: "signed-thing.bin"
  plugins:
    - mac-codesign#v1.0.0:
        input_artifact: "unsigned-thing.bin"
        keychain: "production-certs.keychain"
        keychain_secret: "secret/sync.v1/dev-workflow/production-buildkite/buildkite-agents/cert-decryption-password/ci/improbable/production-codesigning"
```

### Implementation Details

This plugin defines hooks for `environment`, `checkout`, `command`, and `post-command` which execute in that order.

- `environment` performs pre-execution setup and validation before we can actually perform code signing.  It's mostly responsible for checking that the machine in question is allowed to run codesigning jobs.

- `checkout` just disables checkout, since the plugin doesn't need a repo.

- `command` does the main work:
  - Fetches the artifact to sign from the BK artifact store.
  - Fetches the keychain unlock secret from Vault
  - Unlocks the signing keychain.
  - Signs the binary using the cert in the now-unlocked keychain.
  - Validates the signature.

- `post-command` just locks the keychain, regardless of how the rest of the job went.
