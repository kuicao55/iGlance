# Signing & Notarizing iGlance

iGlance is a menu bar app distributed outside the Mac App Store. macOS
Gatekeeper treats unsigned or ad-hoc-signed downloads as "unidentified
developer" and blocks them until the user explicitly allows the app.

There are two levels of signing:

| Level | What it fixes | Requires |
|---|---|---|
| **Ad-hoc** (`codesign -s -`) | Binds `Info.plist` to the binary so `LSUIElement` works; integrity check on the local machine | Nothing (already the default) |
| **Developer ID + notarization** | Opens without warnings on any Mac, including downloads | Apple Developer Program membership |

`build-app.sh` does ad-hoc signing automatically. The rest of this document
covers Developer ID signing and notarization.

---

## 1. Get a Developer ID certificate

1. Join the [Apple Developer Program](https://developer.apple.com/programs/).
2. In Xcode → **Settings → Accounts**, add your Apple ID and select your team.
3. Click **Manage Certificates… → + → Developer ID Application**.
4. Confirm the certificate is in your login keychain:

```bash
security find-identity -v -p codesigning
# "Developer ID Application: Your Name (TEAMID)"
```

Your **Team ID** is the 10-character value in parentheses.

---

## 2. Build a signed release

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
  ./build-app.sh --release
```

This produces `.build/release/iGlance.app` and `dist/iGlance.app.zip`.

Verify locally:

```bash
codesign --verify --deep --strict --verbose=2 .build/release/iGlance.app
codesign -dvvv .build/release/iGlance.app
# Authority=Developer ID Application: ...
# TeamIdentifier=TEAMID
```

> The build script already enables the hardened runtime (`--options runtime`)
> and a secure timestamp, both required for notarization.

---

## 3. Notarize

Notarization uploads the app to Apple, scans it, and returns a ticket you
staple to the bundle.

### Store notarytool credentials once

Create an app-specific password at
[appleid.apple.com](https://appleid.apple.com) (Sign-In and Security →
App-Specific Passwords), then:

```bash
xcrun notarytool store-credentials "iGlanceNotary" \
  --apple-id "you@example.com" \
  --team-id "TEAMID" \
  --password "xxxx-xxxx-xxxx-xxxx"
```

### Build, sign, submit, staple

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="iGlanceNotary" \
  ./build-app.sh --notarize
```

`--notarize` implies `--release`, so you get a stapled app plus
`dist/iGlance.app.zip`. The script runs:

```bash
xcrun notarytool submit dist/iGlance-notarize.zip --keychain-profile iGlanceNotary --wait
xcrun stapler staple  .build/release/iGlance.app
xcrun stapler validate .build/release/iGlance.app
```

### Verify Gatekeeper acceptance

```bash
spctl --assess --type execute --verbose=4 .build/release/iGlance.app
# accepted, source=Notarized Developer ID
```

The ZIP asset you upload to GitHub must be created **after** stapling — which
is what `--release`/`--notarize` do.

---

## 4. Publish a release the updater can use

The in-app updater reads `releases/latest` from the GitHub API and expects:

- a tag such as `v0.2.0`, **newer** than `CFBundleShortVersionString`
- an asset named `iGlance.app.zip` containing `iGlance.app`

```bash
gh release create v0.2.0 dist/iGlance.app.zip \
  --title "iGlance v0.2.0" \
  --notes "What changed…"
```

Keep the bundle version in sync with the tag:

```bash
MARKETING_VERSION=0.2.0 BUILD_NUMBER=2 ./build-app.sh --release
```

The updater verifies the downloaded bundle's identifier and code signature
before replacing the running app, keeps a backup while copying, and restores
the old app if the copy fails.

---

## 5. Troubleshooting

| Symptom | Fix |
|---|---|
| `errSecInternalComponent` during signing | Unlock the login keychain, or run `security set-key-partition-list -S apple-tool:,apple: -s -k <password> login.keychain` |
| `notarytool` returns `Invalid` | Open the log: `xcrun notarytool log <submission-id> --keychain-profile iGlanceNotary`; usually an unsigned nested binary or missing hardened runtime |
| `spctl` says `rejected` | The ticket was not stapled, or you uploaded the ZIP made before stapling |
| Users still see a quarantine warning | They downloaded an older unsigned asset; publish a notarized build and bump the release tag |
| `--notarize` complains about `SIGN_IDENTITY` | Pass the full `Developer ID Application: … (TEAMID)` string, not just the team name |

Ad-hoc builds are fine for local development, but only Developer ID +
notarization gives users a warning-free install.
