#!/usr/bin/env bash
# kubeconform -strict for every manifest, policy and rendered kustomization, against each
# Kubernetes version in KUBECONFORM_K8S_VERSIONS. The Kyverno ValidatingPolicy schema lives in
# tests/schemas. Uses a local `kubeconform` if present, otherwise the pinned container.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/versions.env"
cd "$ROOT"

WORK="$ROOT/.render"
rm -rf "$WORK" && mkdir -p "$WORK"
trap 'rm -rf "$WORK"' EXIT

kustomize_build() {
  if command -v kubectl >/dev/null 2>&1; then kubectl kustomize "$1"; else kustomize build "$1"; fi
}

files=()
while IFS= read -r f; do files+=("$f"); done < <(
  find manifests policies \( -name '*.yaml' -o -name '*.yml' \) \
    -not -name kustomization.yaml -not -name kyverno-test.yaml -not -name artifacthub-pkg.yml | sort)

renders=0
while IFS= read -r k; do
  d="$(dirname "$k")"
  kustomize_build "$d" >"$WORK/kustomize-$(echo "$d" | tr '/' '_').yaml"
  renders=$((renders + 1))
done < <(find manifests policies overlays -name kustomization.yaml | sort)

SCHEMA=(-schema-location default -schema-location "tests/schemas/{{ .Group }}/{{ .ResourceKind }}_{{ .ResourceAPIVersion }}.json")
if command -v kubeconform >/dev/null 2>&1; then
  KC=(kubeconform)
else
  KC=(docker run --rm -v "$ROOT:/work:ro" -w /work "$KUBECONFORM_IMAGE")
fi

for kv in $KUBECONFORM_K8S_VERSIONS; do
  echo "==> kubeconform -strict, Kubernetes $kv: ${#files[@]} files + $renders kustomize renders"
  "${KC[@]}" -strict -summary -kubernetes-version "$kv" "${SCHEMA[@]}" "${files[@]}" .render
done
