#!/usr/bin/env bash
# Builds the PyMySQL Lambda layer: build/pymysql_layer.zip
# PyMySQL is pure Python, so the layer can be built on any OS.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="${ROOT}/build"
LAYER_DIR="${BUILD}/layer"

rm -rf "${LAYER_DIR}" "${BUILD}/pymysql_layer.zip"
mkdir -p "${LAYER_DIR}/python"

python3 -m pip install --quiet --upgrade --target "${LAYER_DIR}/python" "pymysql>=1.1,<2"

( cd "${LAYER_DIR}" && zip -qr "${BUILD}/pymysql_layer.zip" python )

echo "Built ${BUILD}/pymysql_layer.zip"
