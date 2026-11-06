# End-to-End CI/CD: Java -> Maven -> Docker (GHCR) -> AKS, with Gitleaks

Push to `main` and GitHub Actions scans for secrets, builds and tests with Maven, builds and pushes a Docker image to GitHub Container Registry, deploys to Azure Kubernetes Service (AKS) with Ansible, and verifies the live endpoint.

## Architecture

```
 Developer
    | git push (pre-commit: gitleaks)
    v
 GitHub repo ------------------------------> GitHub Actions  (.github/workflows/ci-cd.yml)
                                                |
   1 Gitleaks  -> 2 Maven verify (tests) -> 3 Docker build/push -> Trivy -> 4 Ansible deploy -> 5 Verify
   (fail = stop)    app.jar artifact          ghcr.io/<owner>/<repo>:<sha>     |                  curl /api/version
                                                       |                       | Azure OIDC login (no passwords)
                                                       v                       v
                                                GHCR (container registry)   Azure: Resource group
                                                       ^                       +-- AKS cluster (2 nodes)
                                                       |  image pull               +-- ns javaapp: Deployment (2 pods)
                                                       +---------------------------+-- Service LoadBalancer -> public IP
                                                                                         |
                                                                                    Browser / curl
```

| Requirement (CIA 2) | Where |
|---|---|
| Git SCM | GitHub |
| Maven build + unit tests | `pom.xml`, `src/test/**`, job `build-test` |
| Docker + registry | `Dockerfile`, `.dockerignore`, job `docker` -> GHCR |
| Kubernetes on cloud | `k8s/*.yaml` on Azure AKS |
| CI/CD on push | `.github/workflows/ci-cd.yml` |
| Ansible | `ansible/deploy.yml`, `ansible/inventory.ini` |
| Verify availability | `scripts/verify.sh` (job `deploy`) |
| Security | Gitleaks, Trivy, OIDC (no cloud secrets), non-root container, Dependabot |

## Setup (one time)

**1. Create the GitHub repo and push this folder to `main`.**
```bash
git init && git add . && git commit -m "initial commit"
git branch -M main
git remote add origin https://github.com/<you>/<repo>.git
git push -u origin main
```
The first run will pass stages 1-3 and fail at deploy (no Azure secrets yet). That is expected.

**2. Create Azure resources.** In Azure Cloud Shell (bash), upload `infra/setup-azure.sh` and run:
```bash
GH_REPO=<you>/<repo> ./infra/setup-azure.sh
```
This creates the resource group, the AKS cluster, an Entra app with a GitHub OIDC federated credential, and a Contributor role scoped to the resource group. It prints three values.

**3. Add GitHub secrets** (Settings > Secrets and variables > Actions): `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`.

**4. Make the image pullable by AKS.** After the first successful `docker` job, go to your GitHub profile > Packages > the package > Package settings > Change visibility > Public. Then re-run the failed `deploy` job (Actions > Re-run failed jobs).
Keep it private? Create an image pull secret with a PAT that has `read:packages`, add it to the `javaapp` namespace, and reference it as `imagePullSecrets` in `k8s/deployment.yaml`.

**5. Optional: local secret scanning.** `pip install pre-commit && pre-commit install`

> If your university tenant blocks creating Entra apps, fallback: `az ad sp create-for-rbac --role Contributor --scopes /subscriptions/<sub>/resourceGroups/<rg> --sdk-auth`, store the JSON as secret `AZURE_CREDENTIALS`, and change the login step to `azure/login@v2` with `creds: ${{ secrets.AZURE_CREDENTIALS }}`.

## Demo script (what to show the evaluator)

**A. Gitleaks blocks a secret.**
1. `git checkout -b leak-test`
2. Add a file containing a fake token shaped like `ghp_` followed by 36 random letters/digits.
3. Push and open a PR. Stage 1 turns red and nothing else runs. Screenshot it, then delete the branch.

**B. Change -> auto-redeploy.**
1. Edit `src/main/resources/application.properties`: `app.message=Hello from AKS - v2`
2. `git commit -am "feat: update message to v2" && git push`
3. Watch Actions run all stages. Open `http://<EXTERNAL-IP>`; the message and the git SHA badge change.
4. `curl http://<EXTERNAL-IP>/api/version` shows the new SHA, matching the commit.

## Evidence checklist (screenshots / commands)

| Evidence | How |
|---|---|
| Cloud resources and cluster | Azure Portal > Resource groups > `rg-javaapp-devops`; `az aks list -o table` |
| Image in registry | GitHub > Packages > tags (`latest` and `<sha>`) |
| Pods Running, deployment ready | `kubectl get deploy,pods -n javaapp` (expect `2/2`, `Running`) |
| Service endpoint | `kubectl get svc -n javaapp` and the browser tab |
| Successful pipeline | Actions run with all green jobs + test summary |
| Test results | `build-test` job summary, `surefire-reports` artifact |
| Rollout history | `kubectl rollout history deployment/javaapp -n javaapp` |

To run kubectl from your machine: `az aks get-credentials -g rg-javaapp-devops -n aks-javaapp`

## Security considerations and limitations (for the report)

- **Secrets:** Gitleaks (CI, full history) plus a pre-commit hook. No long-lived Azure credentials exist: GitHub OIDC issues short-lived tokens bound to `repo:<owner>/<repo>:ref:refs/heads/main`.
- **Least privilege:** each job declares minimal `permissions`; only `deploy` gets `id-token: write`, only `docker` gets `packages: write`.
- **Image:** runs as non-root UID 10001, drops all capabilities, no privilege escalation. Trivy scans for CRITICAL/HIGH CVEs (report-only; flip `exit-code` to `1` to enforce).
- **Supply chain:** Dependabot for Maven, Actions and Docker. Production hardening would pin actions to commit SHAs.
- **Limitations:** public HTTP LoadBalancer (no TLS or Ingress), a single environment (no staging or approvals), no autoscaling, no monitoring stack, and the verify step is a smoke test rather than full integration tests.

## Cleanup (avoid Azure charges)

```bash
az aks stop -g rg-javaapp-devops -n aks-javaapp      # pause
az group delete -n rg-javaapp-devops --yes --no-wait # delete everything
```

## Viva quick answers

- **Why GHCR?** It sits next to the code, authenticates with the built-in `GITHUB_TOKEN`, and needs no extra Azure resource.
- **Why OIDC?** There is no stored credential to leak or rotate; Azure trusts GitHub's signed token for one repo and branch.
- **Why tag by SHA?** Every image is immutable and traceable to a commit, and rollback is simple (`kubectl rollout undo`).
- **Where is Ansible used?** `ansible/deploy.yml` applies the manifests and injects the exact image tag, then waits for the rollout to finish.
- **Zero downtime?** `maxUnavailable: 0` with readiness probes means old pods stay until new ones are Ready.
