# MacOS Code Signing Plugin

This allows us to perform the actual codesigning steps necessary to release MacOS software.

See [here](https://brevi.link/design-code-signing) for the general design that this fits into.

## Overview

This plugin relies upon the build agent already having the necessary keychains created on the machine.

Unfortunately, this is a necessity due to macos' insistence upon a one-time-per-key/keychain manual
intervention to approve access to the signing key before `codesign` can use it (even if the cert/key are imported with `codesign` pre-granted access to use it).

## Example use cases

Using the `KEYCHAIN_PW` env var:

```yaml
- label: "sign-macos-binary"
  command: "" # No command needed here, since the `command` hook does the work.
  agents:
    - "queue=macos-codesigner"
  artifact_paths:
    - "thing.bin_signed"
    - "another-thing.bin_signed"
  plugins:
    - mac-codesign#v1.0.0:
        input_artifacts:
          - "thing.bin"
          - "another-thing.bin"
        keychain: "production-certs.keychain"
  env:
        KEYCHAIN_PW: "KeychainPasswordGoesHere"
```

Using the default Improbable secret-fetching script with `keychain_pw_secret_name` set:

```yaml
- label: "sign-macos-binary"
  command: "" # No command needed here, since the `command` hook does the work.
  agents:
    - "queue=macos-codesigner"
  artifact_paths:
    - "thing.bin_signed"
    - "another-thing.bin_signed"
  plugins:
    - mac-codesign#v1.0.0:
        input_artifacts:
          - "thing.bin"
          - "another-thing.bin"
        keychain: "production-certs.keychain"
        keychain_pw_secret_name: "ci/improbable/production-codesigning"
```

Using a custom secret-fetching script:

```yaml
- label: "sign-macos-binary"
  command: "" # No command needed here, since the `command` hook does the work.
  agents:
    - "queue=macos-codesigner"
  artifact_paths:
    - "thing.bin_signed"
    - "another-thing.bin_signed"
  plugins:
    - mac-codesign#v1.0.0:
        input_artifacts:
          - "thing.bin"
          - "another-thing.bin"
        keychain: "production-certs.keychain"
        keychain_pw_helper_script: "~/fetch-keychain-pw.sh"
        keychain_pw_secret_name: "production-codesigning-keychain-pw"
```

### Implementation Details

This plugin defines hooks for `environment`, `checkout`, `command`, and `post-command` which execute in that order.

- `environment` performs pre-execution setup and validation before we can actually perform code signing.  It's mostly responsible for checking that the machine in question is allowed to run codesigning jobs.

- `checkout` just disables checkout, since the plugin doesn't need a repo.

- `command` does the main work:
  - Fetches the artifact to sign from the BK artifact store.
    - This can be any one-or-more artifacts created in the same pipeline as this step, and then stored in the BK artifact store.
  - Unlocks the signing keychain.
  - Signs the binary using the cert in the now-unlocked keychain.
  - Validates the signature.

- `post-command` just locks the keychain, regardless of how the rest of the job went.

#### Keychain unlocking

Since your signing cert needs to be stored in a keychain, and that keychain is assumed to be locked, we
need a password to unlock the signing keychain.

There are two ways to supply a keychain unlocking password to this plugin:

1. In the simple case, you can set the environment variable `KEYCHAIN_PW` on your step.
1. If `KEYCHAIN_PW` is not set, the command hook will call a helper script, which needs to export your keychain unlock password as `KEYCHAIN_PW` - eg:

    - ```bash
      export KEYCHAIN_PW="foo-bar-123"
      ```

    - If you use a secret store like Vault, you should supply the path to your own helper script to retrieve the secret.  By default, the plugin will use `$HOOKS_DIR/helpers/fetch-keychain-pw.sh`, but you can override this with the `keychain_pw_helper_script` parameter.  
    - If set, `keychain_pw_secret_name` will be available to the helper script, which can be used to supply a name or path for a specific secret to retrieve.
