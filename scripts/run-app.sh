#!/bin/bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$("$PROJECT_DIR/scripts/build-app.sh")"
open "$APP_PATH"
