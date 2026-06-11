# CI/CD Pipeline & Release Automation

MinhAgent uses GitHub Actions to build, test, and release app bundles automatically.

## Pipeline

Workflow: [.github/workflows/ci.yml](.github/workflows/ci.yml)

- **On push/PR to `main`**: runs tests + build verification.
- **On version tag** (e.g. `v1.0.0`): builds, tests, packages, creates GitHub Release.

**Runner**: `macos-14` (Apple Silicon M1), Swift 6.0+.

## Automation Steps

1. **Unit tests**: `./test.sh`
2. **Launch verification**: `./test_launch.sh`
3. **Package**: `ditto -c -k --keepParent MinhAgent.app MinhAgent.zip`
4. **Release**: `softprops/action-gh-release` uploads `MinhAgent.zip`, auto-generates changelog.

## Notarization Secrets

| Secret | Description |
| :--- | :--- |
| `APPLE_DEVELOPER_CERT` | Base64-encoded Developer ID Application p12 |
| `APPLE_CERT_PASSWORD` | p12 password |
| `APPLE_ID` | Apple developer email |
| `APPLE_ID_PASSWORD` | App-specific password |
| `APPLE_TEAM_ID` | 10-char Team ID |
