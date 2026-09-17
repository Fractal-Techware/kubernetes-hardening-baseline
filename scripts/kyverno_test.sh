#!/usr/bin/env bash
# Run `kyverno test` for every policy (policies/<name>/.kyverno-test/).
# Uses a local `kyverno` binary if it matches KYVERNO_VERSION, otherwise the pinned CLI container.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/versions.env"

if command -v kyverno >/dev/null 2>&1 && kyverno version 2>/dev/null | grep -q "${KYVERNO_VERSION#v}"; then
  echo "==> kyverno test policies (local kyverno ${KYVERNO_VERSION})"
  (cd "$ROOT/policies" && kyverno test . --remove-color)
else
  echo "==> kyverno test policies (${KYVERNO_CLI_IMAGE%@*})"
  docker run --rm -v "$ROOT:/work:ro" -w /work/policies "$KYVERNO_CLI_IMAGE" test . --remove-color
fi
