#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (C) 2026 Gabriel Ángel Montoya Rico
#
# En GitHub Actions, desde app/: escribe las credenciales OAuth de Google y
# Microsoft que llegan en GOOGLE_OAUTH_SECRETS_JSON y
# MICROSOFT_OAUTH_SECRETS_JSON (secretos del repositorio) y deja en
# OAUTH_DEFINES los --dart-define-from-file para `flutter build`. Sin ellos,
# la app compila igual pero sin Google Drive ni OneDrive.
set -euo pipefail

defines=""
if [ -n "${GOOGLE_OAUTH_SECRETS_JSON:-}" ]; then
  printf '%s' "$GOOGLE_OAUTH_SECRETS_JSON" > google_oauth_secrets.json
  defines="$defines --dart-define-from-file=google_oauth_secrets.json"
else
  echo "::warning::Sin GOOGLE_OAUTH_SECRETS_JSON: Google Drive no va a funcionar"
fi
if [ -n "${MICROSOFT_OAUTH_SECRETS_JSON:-}" ]; then
  printf '%s' "$MICROSOFT_OAUTH_SECRETS_JSON" > microsoft_oauth_secrets.json
  defines="$defines --dart-define-from-file=microsoft_oauth_secrets.json"
else
  echo "::warning::Sin MICROSOFT_OAUTH_SECRETS_JSON: OneDrive no va a funcionar"
fi
echo "OAUTH_DEFINES=$defines" >> "$GITHUB_ENV"
