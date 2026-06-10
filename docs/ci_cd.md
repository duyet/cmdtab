# CI/CD Pipeline & Release Automation

`cmdtab` uses GitHub Actions to build, test, and release application bundles automatically. This document describes the pipeline structure, triggers, environments, and secret configurations.

---

## 1. Pipeline Architecture

The workflow is defined in [.github/workflows/ci.yml](.github/workflows/ci.yml). It has two main execution tracks:

1. **Pull Request / Commit Validation**: Runs tests and verifies the app builds without errors on every push to the `main` branch or when pull requests are created.
2. **Release Automation**: Triggered when a new git version tag (e.g. `v1.0.0`) is pushed. It builds, runs tests, packages the app, creates a GitHub Release, writes the changelog, and uploads the compiled bundle.

---

## 2. GitHub Actions Runner Configuration

- **Runner Environment**: `macos-14` (Apple Silicon M1 runner). This is crucial as it compiles arm64 native binaries optimized for M-series Apple Silicon Macs.
- **Swift version**: `6.0` or newer.

---

## 3. Automation Steps

### 3.1 Unit Testing
Executes unit tests verifying pasteboard sanitization, keychain storage security, and data model operations.
```bash
./test.sh
```

### 3.2 Launch Verification
Compiles the application with full compiler optimizations and executes it in a background sub-process for 2 seconds. This verifies that:
- Dynamic library loader (`dyld`) successfully locates all frameworks.
- The binary does not crash on startup.
```bash
./test_launch.sh
```

### 3.3 Packaging
Builds the app bundle using `./build.sh` and creates a compressed ZIP archive of the `CmdTab.app` structure:
```bash
# Done inside workflow
ditto -c -k --keepParent CmdTab.app CmdTab.zip
```

---

## 4. Release Automation Workflow

When you push a tag (e.g., `git tag v1.0.1 && git push origin v1.0.1`):
1. The builder runs both the unit tests and the launch tests.
2. The builder packages the app bundle into `CmdTab.zip`.
3. The workflow invokes the `softprops/action-gh-release` step, which:
   - Creates a draft/pre-release on GitHub.
   - Uploads `CmdTab.zip` as a release asset.
   - Auto-generates the changelog based on git commit logs between the previous release and the new tag.

---

## 5. Setting up CI/CD Notarization (Optional)

To enable automatic notarization inside the GitHub Actions runner, you should configure the following repository secrets:

| Secret Name | Description | Example Value |
| :--- | :--- | :--- |
| `APPLE_DEVELOPER_CERT` | Base64-encoded `Developer ID Application` p12 certificate. | `MIID...` |
| `APPLE_CERT_PASSWORD` | Password used to encrypt/decrypt the p12 certificate. | `my_password` |
| `APPLE_ID` | Your Apple ID developer email address. | `developer@email.com` |
| `APPLE_ID_PASSWORD` | App-specific password generated on appleid.apple.com. | `abcd-efgh-ijkl-mnop` |
| `APPLE_TEAM_ID` | Your 10-character Apple Developer Team ID. | `TEAMID123` |
