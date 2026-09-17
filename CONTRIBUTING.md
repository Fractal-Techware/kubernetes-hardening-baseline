# Contributing

Issues and pull requests are welcome: bug reports, false positives/negatives, clearer docs.

## Ground rules

- Every policy change needs matching test resources in `policies/<name>/.kyverno-test/`
  (at least one resource that must pass and one that must fail, including a Deployment for autogen).
- Policies ship in `Audit` mode. Do not change the default to `Deny`.
- After editing a policy, regenerate the Artifact Hub metadata:
  `python3 scripts/gen_artifacthub.py`.

## Run the checks locally

```bash
scripts/test.sh   # Artifact Hub metadata + kubeconform + kyverno test
```

Requires Python 3 and `kubectl` (or `kustomize`), plus Docker unless you have `kubeconform` and
`kyverno` (matching `scripts/versions.env`) installed.

By contributing you agree that your contribution is licensed under the MIT License.
