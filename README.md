<p align="center">
  <img src="assets/appicon.png" width="96" height="96" alt="Auth icon">
</p>

<h1 align="center">Auth</h1>

<p align="center">
  An offline two-factor authenticator for BlackBerry 10.<br>
  Native Cascades app. No network access, no permissions, no dependencies.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/BlackBerry_10-10.3-222222" alt="BlackBerry 10.3">
  <img src="https://img.shields.io/badge/version-0.1.1.1-2f80ed" alt="Version 0.1.1.1">
  <img src="https://img.shields.io/badge/license-MIT-34d399" alt="MIT licence">
</p>

---

Auth generates the six- and eight-digit codes that Google, GitHub, Microsoft, AWS and most other services ask for at sign-in. It appears on the home screen as Authenticator. Codes are computed on the phone from secrets you add. The app has no network permission, so nothing it holds can leave the device.

## Features

- Time-based one-time passwords (TOTP, RFC 6238) with HMAC-SHA1, 6 or 8 digits, 30-second period.
- Add an account by pasting its `otpauth://` setup link, or type the issuer, account name and secret by hand.
- Tap a row to copy its current code. Long-press a row to delete the account.
- Each code shows a countdown bar and the seconds left, and turns red in the last five seconds.
- A colour tile per issuer makes accounts easy to tell apart in a long list.

## Install

Download `org.bq.auth.bar` from the [latest release](https://github.com/iroham/bb10-auth/releases/latest).

The package is not signed by BlackBerry, so it installs through the system installer running as root. You need a BlackBerry 10.3 device with root SSH access.

```bash
mkdir -p build && cp ~/Downloads/org.bq.auth.bar build/
BB10_HOST=root@192.0.2.10 ./install.sh
```

`install.sh` copies the package to `/var/nt/work` on the device, writes an installer job and prints the result. It calls `grep` and `sleep` from `/var/nt/bin`; change `B=` in the script if your tools live elsewhere. `BB10_HOST` defaults to an SSH alias named `passport`.

## How it works

SHA-1, HMAC-SHA1, Base32 decoding and the HOTP/TOTP derivation are written from scratch in [`src/totp.cpp`](src/totp.cpp). There is no OpenSSL or other crypto library. At startup the app checks itself against the RFC 4226 and RFC 6238 known-answer vectors (`Totp::selftest()`), so a broken build logs a warning instead of showing wrong codes.

| Path | Contents |
| --- | --- |
| `src/` | C++: application setup and the TOTP engine |
| `assets/` | QML interface and images |
| `scripts/` | Cross-compile scripts run inside the build container |
| `package.py` | Builds the `.bar` archive and its manifest |
| `install.sh` | Installs the package on a device over SSH |

## Building from source

You need the BlackBerry 10 Native SDK (QNX toolchain, Qt 4.8, Cascades). The SDK cannot be redistributed, so it is not part of this repository.

```bash
scripts/in-container.sh app-build.sh   # cross-compile -> build/qnx/auth
python3 package.py                      # package     -> build/org.bq.auth.bar
./install.sh                            # install on the device
```

The build scripts target a specific Docker setup: Docker context `colima-aosp`, image `a11-build`, the clang toolchain in volume `a11-src`, and a build volume `tg-build`. They expect this repository checked out as `native-auth/` next to a `phase6/` directory that holds the SDK (`phase6/qnxsdk`) and the toolchain environment (`phase6/toolchain/qnx-env.sh`). To build elsewhere, edit the `docker run` line in [`scripts/in-container.sh`](scripts/in-container.sh).

## Security notes

Account secrets are stored in the app's private sandbox (`data/accounts.json`, owner-only file permissions). They are not encrypted at rest, so the device password and BlackBerry's device encryption are what protect them.

Only SHA-1 secrets are supported for now; that covers almost every service. SHA-256/SHA-512 secrets and QR-code scanning are not implemented yet.

## Licence

MIT. See [LICENSE](LICENSE).
