#!/usr/bin/env bash
# Builds the macOS app in debug or release mode. Called by debug.sh and
# release.sh at the repository root; anything after the mode is passed on to
# `flutter build macos`.
#
# The app's keys and settings are Dart defines (`String.fromEnvironment`), so
# they are compiled into the binary: they must be present when the app is
# built, and setting them in the environment of the launched .app does nothing.
# Each comes from env.json (or the file named by PICKSTOCK_ENV_FILE), and a
# variable of the same name set in the shell takes its place, so
#
#   FINNHUB_API_KEY=... ./release.sh
#
# builds with that key whatever env.json says. All of them are optional:
#
#   FINNHUB_API_KEY      live share prices; without it the price is typed in
#   MASSIVE_API_KEY      a day's closing price for every US stock, once a day
#   OLLAMA_API_KEY       Ollama's hosted web search; without it research is off
#   OLLAMA_HOST          the local model server (default http://localhost:11434)
#   OLLAMA_MODEL         the model it runs (default gemma4:12b-mlx)
#   PICKSTOCK_MOCK_DATA  `true` swaps the database for a fixture (debug only)

set -euo pipefail

readonly defines=(FINNHUB_API_KEY MASSIVE_API_KEY OLLAMA_API_KEY OLLAMA_HOST OLLAMA_MODEL PICKSTOCK_MOCK_DATA)

mode=${1:-}
case "$mode" in
  debug) configuration=Debug ;;
  release) configuration=Release ;;
  *)
    echo "usage: $0 debug|release [flutter build options...]" >&2
    exit 64
    ;;
esac
shift

cd "$(dirname "$0")/.."

fail() {
  echo "error: $*" >&2
  exit 1
}

command -v flutter >/dev/null || fail "flutter is not on PATH"
command -v jq >/dev/null || fail "jq is needed to read env.json (brew install jq)"
[[ -d ../fluf ]] || fail "../fluf is missing; pubspec.yaml depends on it by path"

env_file=${PICKSTOCK_ENV_FILE:-env.json}
if [[ -f "$env_file" ]]; then
  jq -e 'type == "object"' "$env_file" >/dev/null 2>&1 ||
    fail "$env_file is not a JSON object"
  json=$(cat "$env_file")
else
  [[ -n ${PICKSTOCK_ENV_FILE:-} ]] && fail "$env_file does not exist"
  echo "note: no env.json; copy env.example.json to env.json to keep keys out of your shell history"
  json='{}'
fi

for name in "${defines[@]}"; do
  if [[ -n ${!name:-} ]]; then
    json=$(jq --arg k "$name" --arg v "${!name}" '.[$k] = $v' <<<"$json")
  fi
done

# An empty value would replace a define's default with "" rather than leave it
# unset, so OLLAMA_HOST="" would point the app at no server at all.
json=$(jq 'with_entries(select(.value != "" and .value != null))' <<<"$json")

if [[ $mode == release ]] && jq -e 'has("PICKSTOCK_MOCK_DATA")' <<<"$json" >/dev/null; then
  fail "PICKSTOCK_MOCK_DATA is set; a release build must run against the real database"
fi

has() { jq -e --arg k "$1" 'has($k)' <<<"$json" >/dev/null; }

echo "Building PickStock ($configuration) with:"
for name in "${defines[@]}"; do
  if has "$name"; then
    case "$name" in
      *_KEY) echo "  $name  set" ;;
      *) echo "  $name  $(jq -r --arg k "$name" '.[$k]' <<<"$json")" ;;
    esac
  fi
done
has FINNHUB_API_KEY || echo "  warning: FINNHUB_API_KEY not set; share prices will have to be typed in"
has MASSIVE_API_KEY || echo "  warning: MASSIVE_API_KEY not set; the list and the scan will price companies one quote at a time"
has OLLAMA_API_KEY || echo "  warning: OLLAMA_API_KEY not set; web research will be unavailable"
if [[ $mode == release ]] && { has FINNHUB_API_KEY || has MASSIVE_API_KEY || has OLLAMA_API_KEY; }; then
  echo "  note: the keys are compiled into the app; do not hand the build to anyone you would not give them to"
fi

# The merged defines hold the keys, so they live in a private temp file that
# is removed however the build ends, rather than on the command line. Flutter
# reads the file as JSON only when its name ends in .json.
defines_dir=$(mktemp -d -t pickstock-defines)
trap 'rm -rf "$defines_dir"' EXIT
defines_file=$defines_dir/defines.json
(umask 077 && printf '%s\n' "$json" >"$defines_file")

flutter pub get
flutter build macos "--$mode" --dart-define-from-file="$defines_file" "$@"

echo "Built build/macos/Build/Products/$configuration/PickStock.app"
