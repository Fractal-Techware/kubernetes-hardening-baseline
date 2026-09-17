# Kubernetes Hardening Baseline — tested Kyverno policies, Pod Security & default-deny NetworkPolicies

[![test](https://github.com/Fractal-Techware/kubernetes-hardening-baseline/actions/workflows/test.yml/badge.svg)](https://github.com/Fractal-Techware/kubernetes-hardening-baseline/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/fractal-techware-k8s-hardening)](https://artifacthub.io/packages/search?repo=fractal-techware-k8s-hardening)
[![Kubernetes 1.32–1.37](https://img.shields.io/badge/kubernetes-1.32--1.37-326ce5?logo=kubernetes&logoColor=white)](#compatibility)
[![Kyverno 1.19+](https://img.shields.io/badge/kyverno-1.19%2B-ff6b35)](https://kyverno.io)
[![kubeconform strict](https://img.shields.io/badge/kubeconform-strict-success)](scripts/kubeconform.sh)

A small, **tested** Kubernetes security baseline you can apply in minutes:

- **Pod Security Admission** namespace pinned to the `restricted` profile
- **Default-deny NetworkPolicy** (ingress + egress) with DNS egress allowed
- **Hardened Deployment template**: non-root, seccomp `RuntimeDefault`, drop `ALL` capabilities,
  read-only root filesystem, no service account token, requests/limits, probes
- **5 Kyverno policies** (CEL `ValidatingPolicy`) with `kyverno test` suites: disallow privileged
  containers, require runAsNonRoot, disallow `:latest`, require requests/limits, disallow hostPath
- **Audit mode by default** plus Warn and Enforce overlays, so nothing breaks on day one

Every file is validated in CI with `kubeconform -strict` (Kubernetes 1.35 and 1.37) and every
policy with `kyverno test` (30 pass/fail assertions, including Deployment autogen).

## Contents

```
manifests/                       PSA namespace, default-deny NetworkPolicy, hardened Deployment
policies/<name>/                 Kyverno ValidatingPolicy + artifacthub-pkg.yml
policies/<name>/.kyverno-test/   kyverno test suite (good.yaml must pass, bad.yaml must fail)
overlays/warn, overlays/enforce  kustomize overlays that switch validationActions
scripts/test.sh                  everything CI runs
```

## Quickstart

### 1. Harden a namespace (no extra components)

```bash
git clone https://github.com/Fractal-Techware/kubernetes-hardening-baseline.git
cd kubernetes-hardening-baseline

# Edit the namespace name in manifests/kustomization.yaml and manifests/00-namespace.yaml first
kubectl apply -k manifests
kubectl -n my-app rollout status deploy/web
```

You get a `my-app` namespace that rejects pods violating Pod Security `restricted`, blocks all
traffic except DNS, and runs a hardened nginx Deployment you can use as a template.

> Default-deny needs a CNI that enforces NetworkPolicy (Calico, Cilium, Antrea, AWS VPC CNI with
> network policy enabled, GKE Dataplane V2...). Flannel and old kindnet silently ignore it.

### 2. Add the Kyverno policies (audit mode)

```bash
helm repo add kyverno https://kyverno.github.io/kyverno/
helm install kyverno kyverno/kyverno -n kyverno --create-namespace   # Kyverno 1.19+

kubectl apply -k policies
kubectl get policyreports -A          # violations are reported, nothing is blocked
```

## Policies

| Policy | Severity | Blocks | Category |
|---|---|---|---|
| [`disallow-privileged-containers`](policies/disallow-privileged-containers) | critical | `securityContext.privileged: true` in containers, initContainers, ephemeralContainers | Pod Security |
| [`disallow-host-path`](policies/disallow-host-path) | critical | any `hostPath` volume | Pod Security |
| [`require-run-as-non-root`](policies/require-run-as-non-root) | high | missing `runAsNonRoot: true` (pod or container), `runAsUser: 0` | Pod Security |
| [`disallow-latest-tag`](policies/disallow-latest-tag) | high | `:latest` and untagged images (tag or digest required) | Supply Chain |
| [`require-resource-requests-limits`](policies/require-resource-requests-limits) | medium | missing CPU/memory requests or memory limit | Resource Management |

All policies:

- use Kyverno 1.19 `policies.kyverno.io/v1` `ValidatingPolicy` with CEL expressions
- apply to Pods and, via autogen, Deployments, StatefulSets, DaemonSets, Jobs and CronJobs
- skip `kube-system`, `kube-public`, `kube-node-lease` and `kyverno`
- carry CIS Kubernetes Benchmark and NSA/CISA hardening guidance references as annotations

## From audit to enforce

Rolling straight to `Deny` is how policy projects get reverted. Go in three phases:

| Phase | Command | Effect |
|---|---|---|
| 1. Audit (default) | `kubectl apply -k policies` | Violations recorded in PolicyReports only |
| 2. Warn | `kubectl apply -k overlays/warn` | Still admitted, but `kubectl` and CI print a warning |
| 3. Enforce | `kubectl apply -k overlays/enforce` | Violations rejected at admission |

1. Run **Audit for at least a week** so CronJobs and rarely-deployed workloads show up.
2. Fix what `kubectl get policyreports -A` reports. For each remaining violation decide: fix the
   workload, or grant a narrow, time-boxed Kyverno `PolicyException` with an owner.
3. Switch to **Warn** so teams see issues at deploy time without breaking pipelines.
4. **Enforce** once reports are clean. Existing pods are never evicted; only new or updated ones
   are checked. To roll back, re-apply `kubectl apply -k policies`.

### Rolling out to an existing namespace

Pod Security Admission works the same way: label an existing namespace with only the `audit`
and `warn` labels from `manifests/00-namespace.yaml`, watch for warnings, then add `enforce`.
The `enforce-version` is pinned so a cluster upgrade never silently tightens admission.

### What breaks after default-deny

Everything except DNS, by design. Typical allow rules you will need next: traffic from your
ingress controller, Prometheus scraping, app-to-app calls inside the namespace, and egress to
databases or external APIs. Verify enforcement from outside the namespace; this should time out:

```bash
kubectl run np-test --rm -it --restart=Never --image=busybox:1.37 -- wget -T3 -qO- http://web.my-app:8080
```

## Run the tests

```bash
scripts/test.sh
```

This checks the Artifact Hub metadata, runs `kubeconform -strict` against every manifest, policy
and kustomize render for Kubernetes 1.35 and 1.37, and runs `kyverno test` for every policy.
Local `kubeconform` / `kyverno` binaries are used when present; otherwise the pinned containers
from [`scripts/versions.env`](scripts/versions.env). The same checks run in
[GitHub Actions](.github/workflows/test.yml).

## Compatibility

Kubernetes 1.32–1.37 (validated against 1.35 and 1.37 schemas) · Kyverno 1.19+ · EKS, GKE, AKS,
k3s, kind and other conformant distributions.

## Guides

Tested walkthroughs on [https://fractal-techware.github.io/guides/](https://fractal-techware.github.io/guides/): [disallow the :latest tag](https://fractal-techware.github.io/guides/kyverno-disallow-latest-tag/), [require requests and limits](https://fractal-techware.github.io/guides/kyverno-require-requests-limits/), [Kyverno from Audit to Enforce](https://fractal-techware.github.io/guides/kyverno-audit-to-enforce/), [default-deny NetworkPolicy with DNS](https://fractal-techware.github.io/guides/kubernetes-default-deny-networkpolicy-dns/) and [Pod Security Admission restricted](https://fractal-techware.github.io/guides/pod-security-admission-restricted-migration/).

## Need the full baseline?

This repository is a free sample of the
[Kubernetes Hardening Baseline Kit](https://fractaltechware.gumroad.com/l/k8s-hardening-kit?utm_source=github&utm_medium=readme&utm_campaign=free-repo).
If it is useful, the paid tiers cover the rest of a production rollout:

| | Free (this repo) | Starter $19 | Pro $49 | Studio $99 |
|---|:-:|:-:|:-:|:-:|
| PSA namespace + default-deny NetworkPolicy | Yes | Yes | Yes | Yes |
| Hardened workload templates | Deployment + Service | + standalone Pod | Yes | Yes |
| CIS / NSA-CISA mapped hardening checklist | – | Yes | Yes | Yes |
| Troubleshooting & compatibility matrix | – | Yes | Yes | Yes |
| Tested Kyverno policies | 5 | – | 21 | 21 |
| PolicyException workflow (owner, ticket, expiry) | – | – | Yes | Yes |
| `ftw-baseline` Helm chart | – | – | Yes | Yes |
| NetworkPolicy allow patterns / RBAC templates | – | – | 6 / 3 | 6 / 3 |
| Native ValidatingAdmissionPolicies (no Kyverno) | – | – | – | 15 |
| Audit CLI with JSON / SARIF + GitHub Actions gate | – | – | – | Yes |
| Rollout runbook, client-use license | – | – | – | Yes |

[Compare tiers on Gumroad](https://fractaltechware.gumroad.com/l/k8s-hardening-kit?utm_source=github&utm_medium=readme&utm_campaign=free-repo)

## Contributing & license

Issues and PRs are welcome, see [CONTRIBUTING.md](CONTRIBUTING.md).
Released under the [MIT License](LICENSE) by Fractal Techware.

<sub>Keywords: Kubernetes security, Kubernetes hardening, Kyverno policies, Kyverno ValidatingPolicy,
Pod Security Standards, Pod Security Admission, NetworkPolicy default deny, CIS Kubernetes Benchmark,
NSA CISA Kubernetes hardening guidance, policy as code, DevSecOps, platform engineering.</sub>
