#!/usr/bin/env bash

set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.44.0}"
FLUTTER_ROOT="${HOME}/flutter"

if [ -x "${FLUTTER_ROOT}/bin/flutter" ]; then
  INSTALLED_VERSION="$("${FLUTTER_ROOT}/bin/flutter" --version 2>/dev/null | head -n 1 | sed -E 's/.* ([0-9]+\.[0-9]+\.[0-9]+).*/\1/')"
  if [ "${INSTALLED_VERSION}" != "${FLUTTER_VERSION}" ]; then
    rm -rf "${FLUTTER_ROOT}"
  fi
fi

if [ ! -x "${FLUTTER_ROOT}/bin/flutter" ]; then
  git clone --depth 1 --branch "${FLUTTER_VERSION}" \
    https://github.com/flutter/flutter.git \
    "${FLUTTER_ROOT}"
fi

export PATH="${FLUTTER_ROOT}/bin:${PATH}"

flutter --version
flutter config --enable-web
flutter pub get
