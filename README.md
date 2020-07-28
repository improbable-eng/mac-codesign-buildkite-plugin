# MacOS Code Signing Plugin

## Overview

This plugin performs the actual codesigning steps necessary to release MacOS software.  No support
for iOS, sorry.

See [here](https://brevi.link/design-code-signing) for the general design that this fits into.
TODO(@DoomGerbil): Make this design doc visible to people outside of Improbable.

Important note: this plugin relies upon the build agent already having the necessary keychains created on the machine.

The required keychain items should also have been allowed access for the relevant tools; more on this later.

### Features

- Signs binaries, dmgs, or apps for MacOS.
- Notarization, with stapling of the notarization ticket.
- Specifying multiple sub targets to sign. For example: the frameworks in a `.app`.
- Notarization password can be fetched from keychain.
- Automatic unlocking/locking of signing keychains.
- Secrets for unlocking signing certs can be supplied as env vars or fetched from external secret storage (eg Vault).
- Prevents signing jobs from being run on unapproved machines, or using unsafe workflows.

### Still TODO

- There are still a few places left that assume you're a user at Improbable.  Sorry.

## Prerequisites

Your build agent requires a few things for this to work properly.

1. XCode 11+ must be installed.
    1. `altool`, `codesign` must be on the $PATH.
1. [`gon`](https://github.com/mitchellh/gon) must be installed and on the $PATH. This is the wrapper which handles
codesigning and notarization.
1. `jq` must be installed and on the $PATH.
1. Each item stored in the keychain must have been whitelisted for access by the relevant tool. To do this, double click
on the restricted keychain item, select the "Access Control" tab, and add the tool to the list of applications
to "always allow access to". This means that:
    1. for code signing; the private key for your "Developer ID Application" cert must have `codesign` added to it.
    1. for notarization: your account password should be stored in a keychain item named "apple_password", with the
    "account" field being the relevant apple email. It should be accessible by `altool`.

## Example use cases

Using the `KEYCHAIN_PW` env var:

```yaml
- label: "sign-macos-binary"
  agents:
    - "queue=macos-codesigner"
  plugins:
    - improbable-eng/mac-codesign#v0.1.2:
        input_artifacts:
          - "thing.bin"
        keychain: "production-certs.keychain"
  env:
        KEYCHAIN_PW: "KeychainPasswordGoesHere"
```

Using the default Improbable secret-fetching script with `keychain_pw_secret_name` set:

```yaml
- label: "sign-macos-binary"
  agents:
    - "queue=macos-codesigner"
  plugins:
    - improbable-eng/mac-codesign#v0.1.2:
        input_artifacts:
          - "thing.bin"
          - "another-thing.bin"
        keychain: "production-certs.keychain"
        keychain_pw_secret_name: "ci/improbable/production-codesigning"
```

Using a custom secret-fetching script:

```yaml
- label: "sign-macos-binary"
  agents:
    - "queue=macos-codesigner"
  plugins:
    - improbable-eng/mac-codesign#v0.1.2:
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
  - Unlocks the signing keychain.
  - Fetches the artifact to sign from the BK artifact store.
    - This can be any one-or-more artifacts created in the same pipeline as this step, and then stored in the BK artifact store.
  - Signs the binary using the cert in the now-unlocked keychain.
  - Notarizes the binary using the account credentials in the keychain.
  - Uploads the signed artifact back to BuildKite.

- `post-command` just locks the keychain, regardless of how the rest of the job went.

#### Available properties

- `input_artifacts`: String array of artifact paths to download that are required to sign.
- `sign_prerequisites`: String array of the specific artifact paths to sign. In the case of `.app`s, make sure to list these bottom-up; internal frameworks/helpers first, and `.app` at the end.
- `output_artifacts`: String array of relevant artifact to upload back to artifacts.
- `entitlements`: String path of artifact containing entitlements to apply.
- `keychain`: Name of the keychain storing the secrets. (Note: usually requires the .keychain extension)
- `cert_identity`: Name of the cert to use to sign your artifacts. Should be the "Application" cert, not the "Installer" cert.
- `keychain_pw_secret_name`: (optional) Name of the password to extract from your preferred secret store (eg: Vault)
- `keychain_pw_helper_script`: (optional) Custom helper script to obtain the keychain password.
- `tool_bundle_id`: The apple bundle id to use with your artifacts.
- `apple_user_email`: The account email for your notarization process. Password should be stored in the keychain at the `apple_password` key.

#### Keychain unlocking

Since your signing certs need to be stored in a keychain, and that keychain is assumed to be locked, we
need a password to unlock the signing keychain.

There are two ways to supply a keychain unlocking password to this plugin:

1. In the simple case, you can set the environment variable `KEYCHAIN_PW` on your step.
1. If `KEYCHAIN_PW` is not set, the command hook will call a helper script, which needs to export your keychain unlock password as `KEYCHAIN_PW` - eg:

    - ```bash
      export KEYCHAIN_PW="foo-bar-123"
      ```

    - If you use a secret store like Vault, you should supply the path to your own helper script to retrieve the secret.  By default, the plugin will use `$HOOKS_DIR/helpers/fetch-keychain-pw.sh`, but you can override this with the `keychain_pw_helper_script` parameter.  
    - If set, `keychain_pw_secret_name` will be available to the helper script, which can be used to supply a name or path for a specific secret to retrieve.
