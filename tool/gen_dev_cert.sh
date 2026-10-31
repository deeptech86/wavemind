#!/usr/bin/env bash
# Generates (or regenerates) a locally-trusted TLS certificate for the
# TideWell dev backend, via mkcert (https://github.com/FiloSottile/mkcert).
#
# Why: real devices talk to this backend over the LAN during development
# (see backend/README.md), and that traffic — including login passwords and
# session tokens — must not travel as plaintext HTTP. mkcert issues a cert
# signed by a local CA that's trusted on this Mac (and, once you install the
# same CA's root cert on each test device, on those too — see the printed
# instructions below), so the connection is genuine, browser/OS-trusted
# HTTPS, not a self-signed cert you have to click through warnings for.
#
# The cert is bound to specific addresses, so it must be regenerated
# whenever this Mac's LAN IP changes (different Wi-Fi network, DHCP lease
# renewal, etc.) — just re-run this script.
#
# Usage: tool/gen_dev_cert.sh
# Output: backend/certs/dev-cert.pem, backend/certs/dev-key.pem (gitignored
# — never commit a private key, even a dev one).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CERT_DIR="$REPO_ROOT/backend/certs"
mkdir -p "$CERT_DIR"

if ! command -v mkcert >/dev/null 2>&1; then
  echo "mkcert not found on PATH. Install it first:" >&2
  echo "  brew install mkcert   (or see https://github.com/FiloSottile/mkcert#installation)" >&2
  exit 1
fi

# Detect the current LAN IP (same approach used elsewhere in this project
# for --dart-define=API_BASE_URL). Falls back gracefully if none found.
LAN_IP="$(ipconfig getifaddr en0 2>/dev/null || true)"
if [ -z "$LAN_IP" ]; then
  LAN_IP="$(ifconfig | awk '/inet /{print $2}' | grep -v '^127\.' | head -1 || true)"
fi

HOSTS=(localhost 127.0.0.1 ::1 10.0.2.2)
if [ -n "$LAN_IP" ]; then
  HOSTS+=("$LAN_IP")
  echo "Including current LAN IP: $LAN_IP"
else
  echo "Warning: couldn't detect a LAN IP — cert will only cover localhost/10.0.2.2." >&2
  echo "Real devices over Wi-Fi won't be able to connect until you regenerate with a LAN IP." >&2
fi

mkcert -cert-file "$CERT_DIR/dev-cert.pem" -key-file "$CERT_DIR/dev-key.pem" "${HOSTS[@]}"

CAROOT="$(mkcert -CAROOT)"
echo
echo "Wrote $CERT_DIR/dev-cert.pem and dev-key.pem (covers: ${HOSTS[*]})"
echo
echo "This Mac already trusts the mkcert CA (run 'mkcert -install' once if not)."
echo "To trust it on a real test device, copy its root cert and install it there:"
echo "  $CAROOT/rootCA.pem"
echo
echo "  iPhone: AirDrop rootCA.pem to the phone -> it installs as a profile ->"
echo "          then go to Settings > General > VPN & Device Management, install it,"
echo "          then Settings > General > About > Certificate Trust Settings and"
echo "          toggle full trust for 'mkcert <you>@<host>'."
echo "  Android: copy rootCA.pem onto the device -> Settings > Security >"
echo "           Encryption & credentials > Install a certificate > CA certificate."
echo
echo "Run the backend with:"
echo "  cd backend && .venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8010 --reload \\"
echo "    --ssl-certfile certs/dev-cert.pem --ssl-keyfile certs/dev-key.pem"
