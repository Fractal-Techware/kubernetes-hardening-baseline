#!/usr/bin/env bash
# Run every check CI runs: Artifact Hub metadata, kubeconform, kyverno test.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 "$ROOT/scripts/gen_artifacthub.py" --check
"$ROOT/scripts/kubeconform.sh"
"$ROOT/scripts/kyverno_test.sh"
echo "All checks passed."
