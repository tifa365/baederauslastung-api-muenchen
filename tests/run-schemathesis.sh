#!/usr/bin/env bash
# Prüft openapi.yaml per Property-based Testing gegen die Live-API der SWM.
# Konfiguration (Base-URL, Rate-Limit 4 req/s, keine Methoden-Mutation) liegt in schemathesis.toml.
# Zwei bekannte Eigenheiten der API sind in tests/schemathesis-baseline.json als akzeptiert hinterlegt:
#   - area_id <= 0            -> HTTP 500 (HTML)            [not_a_server_error]
#   - area_id > int64-Maximum -> HTTP 200 mit return_code=exception [negative_data_rejection]
# Neue Abweichungen lassen den Lauf fehlschlagen. JUnit-Report: tests/reports/junit.xml
#
# Aufruf:            tests/run-schemathesis.sh
# Baseline erneuern: tests/run-schemathesis.sh --baseline-update
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p tests/reports
exec uvx schemathesis run openapi.yaml --checks all --baseline tests/schemathesis-baseline.json "$@"
