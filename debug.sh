#!/usr/bin/env bash
# Builds the macOS app in debug mode. Keys and options: see tool/build_macos.sh.
exec "$(dirname "$0")/tool/build_macos.sh" debug "$@"
