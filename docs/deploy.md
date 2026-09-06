# Deploy

First-time (and recreate) walkthrough. PowerShell, region `eu-central-1`. Day-2 scale / promote / pod limits: [operations.md](operations.md).

This is a **local Terraform + GitOps** deploy: `bootstrap/` creates remote state and GitHub OIDC once; `terraform/` brings up the platform; **Argo CD** syncs Bank of Anthos. App GitHub Actions never talk to EKS. After the platform exists, `terraform-plan` / `terraform-apply` can run from GitHub — first apply is usually from the laptop so you can set knobs.

Default app env is **dev only**. Argo CD UI stays ClusterIP (port-forward). Frontend is public when `ingress_environments` is non-empty: lab HTTP ALB hostname, or `https://boa-<env>.<ingress_domain>` when a domain is set. Grafana (`enable_monitoring`): Ingress only with a domain (`https://boa-grafana.<ingress_domain>` on the **same** ALB); otherwise ClusterIP + port-forward.

## Prerequisites

- AWS CLI v2, logged in (bootstrap uses `aws_profile`; the main stack uses the default credential chain — set `$env:AWS_PROFILE` if you use a named profile)
- Terraform >= 1.5
- kubectl, Helm
- OpenSSL (Git for Windows is enough) — JWT keys
- A GitHub PAT:
  - Bootstrap: `repo` (writes Actions secrets/variables into an **existing** repo)
  - Argo CD: `contents:read` (same PAT is fine)
- Optional public UI: a domain **already registered** in Route 53 in this account (`ingress_domain`). This stack looks up the zone; it does **not** create one.

The GitHub repo must already exist. Bootstrap does **not** create it.

## 1. Bootstrap (once)

Creates the S3 state bucket, DynamoDB lock table, GitHub OIDC IAM role, and pushes `AWS_OIDC_ROLE_ARN`, `TF_STATE_BUCKET`, `TF_STATE_DYNAMODB_TABLE`, `AWS_REGION` (and `GH_PAT`) into the repo.

```powershell
cd bootstrap
Copy-Item terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`: `owner`, `github_owner`, `github_repo_name` (must match the real repo). Do not put the PAT in that file.

```powershell
$env:TF_VAR_github_token = "ghp_..."   # PAT with repo scope
terraform init
terraform apply
terraform output
```

Save `state_bucket_name`, `dynamodb_table_name`, `aws_region`, `github_actions_role_arn`.

Confirm in GitHub: **Settings → Secrets and variables → Actions** has secret `AWS_OIDC_ROLE_ARN` and variables `TF_STATE_BUCKET`, `TF_STATE_DYNAMODB_TABLE`, `AWS_REGION`.

## 2. Point the platform stack at that backend

```powershell
cd ..\terraform
Copy-Item backend.conf.example backend.conf
```

Fill `backend.conf` from bootstrap outputs (`bucket`, `dynamodb_table`, `region`). `backend.conf` is gitignored.

This repo **commits** `terraform/terraform.tfvars` (knobs, no secrets). Forks copy `terraform.tfvars.example` → `terraform.tfvars` and set `owner`, `argocd_repo_url`. Never put PATs in that file.

In `terraform.tfvars`:

- Keep `enabled_environments = ["dev"]` for a cheap first deploy
- `ingress_environments = ["dev"]` (empty list = no frontend Ingress = no ALB)
- `ingress_domain = ""` for lab (HTTP `*.elb.amazonaws.com`), **or** your Route 53 zone name for TLS + `boa-dev.<domain>`
- `enable_monitoring = false` until you want kube-prometheus-stack. Extra node `desired_size` is set at **create**; later applies ignore ASG desired count — see [operations.md](operations.md)
- To test a PR branch before merge: `argocd_target_revision = "feat/..."`, then set back to `main` after merge
- Leave RDS hosts / ECR registry out of Git — Terraform injects them into Argo

```powershell
$env:TF_VAR_argocd_gh_token = "ghp_..."   # PAT Argo uses to clone
terraform init -backend-config="backend.conf"
terraform plan
terraform apply
```

This takes a while (VPC, EKS 1.35, ECR, RDS Postgres 16, ESO, AWS Load Balancer Controller, Argo CD + root Applications; ExternalDNS + ACM only when `ingress_domain` is set).

Later changes: PR against `terraform/**` → `terraform-plan` (comment on the PR); merge to `main` → `terraform-apply` (GitHub Environment `infra`). Same `terraform.tfvars`, same remote state. Disable that apply workflow in the Actions UI when the lab should not apply itself.

## 3. Secrets Manager bootstraps (after platform apply)

Run **after** `terraform apply`. ESO IRSA may read RDS-managed secrets plus these names.

**JWT** (required before Bank of Anthos login works). Creates `bank-of-anthos-jwt`; ESO syncs Kubernetes secret `jwt-key`.

```powershell
cd ..
.\scripts\bootstrap-jwt.ps1
```

**Grafana admin** (only if `enable_monitoring = true`). Creates `bank-of-anthos-grafana-admin` with JSON `admin_user` / `admin_password` (default user `admin`). ESO syncs Kubernetes secret `grafana-admin`. The script does **not** print the password.

```powershell
.\scripts\bootstrap-grafana.ps1
```

Read it when needed:

```powershell
aws secretsmanager get-secret-value --secret-id bank-of-anthos-grafana-admin --region eu-central-1 --query SecretString --output text
```

Both scripts are safe to re-run; `-ForceRotate` replaces the payload (JWT sessions / Grafana login break until ESO refreshes).

## 4. kubeconfig and sanity check

Cluster admin is IAM role `bank-of-anthos-eks-admin` (not your IAM user). `update-kubeconfig --role-arn` writes that into `~/.kube/config` once; later `kubectl` does not need the flag again. Terraform on the laptop should use the same role if the Kubernetes/Helm providers talk to the API.

```powershell
cd terraform
$roleArn = terraform output -raw eks_cluster_admin_role_arn
aws eks update-kubeconfig --name bank-of-anthos --region eu-central-1 --role-arn $roleArn
kubectl get nodes
kubectl get applications -n argocd
```

Always: `root-dev`, `root-platform-external-secrets`, then (after sync) `bank-of-anthos-secrets-dev` and `bank-of-anthos-dev`.

If `enable_monitoring = true`: also `root-platform-monitoring` (destination namespace `monitoring`). That Application **is** the stack (chart at `gitops/platform/monitoring`) — it is **not** App-of-Apps. App-of-Apps is only `root-dev` / `root-prod`.

If `"prod"` is in `enabled_environments`: `root-prod` plus prod children (children have **no** auto-sync — Sync them in the UI).

Helm (`helm list -A`) shows **Terraform** releases only: `argocd`, `argocd-apps`, `external-secrets`, `aws-load-balancer-controller`, and `external-dns` when a domain is set. Umbrella / monitoring from Argo do **not** appear there.

Argo UI (ClusterIP, never Ingress):

```powershell
[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String((kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}")))
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

Open `https://localhost:8080` — user `admin`, password from that secret.

## 5. Build and push images (ECR is empty until this)

CI never talks to the cluster. After ECR exists:

1. **Actions → `ci-build-images` → Run workflow** (or push to `main` under `src/**`)
2. That workflow pushes 7 images tagged with the short SHA
3. `cd-update-values-dev` then writes those tags into `charts/bank-of-anthos/values-dev.yaml` and pushes

Until that lands, Argo will try the tag already in `values-dev.yaml` and pods will `ImagePullBackOff` on a fresh registry.

## 6. Wait for the app to become healthy

Namespace: `bank-of-anthos-dev`.

```powershell
kubectl get externalsecrets,secrets -n bank-of-anthos-dev
kubectl get pods -n bank-of-anthos-dev
kubectl get jobs -n bank-of-anthos-dev
kubectl get ingress -A
```

Expect:

- Secrets: `jwt-key`, `accounts-db-credentials`, `ledger-db-credentials`
- Jobs: `populate-accounts-db`, `populate-ledger-db` Complete (schema + demo data). Java ledger pods stay unready until the ledger Job succeeds — [operations.md](operations.md#seed-jobs)
- Pods: frontend, userservice, contacts, ledgerwriter, balancereader, transactionhistory, loadgenerator
- Ingress `frontend` in `bank-of-anthos-dev` when `ingress_environments` includes `"dev"`
- If monitoring is on: namespace `monitoring`, secret `grafana-admin`, Ingress `grafana` **only** when `ingress_domain` is set

## 7. Open the UI

**Frontend**

| `ingress_domain` | How you get the URL |
|---|---|
| Set (e.g. `dbembnista.com`) | `https://boa-dev.<domain>` (ExternalDNS alias on the ALB; TLS) |
| Empty (lab) | `kubectl get ingress -n bank-of-anthos-dev` — **ADDRESS** is `*.elb.amazonaws.com` (HTTP :80) |
| No Ingress (`ingress_environments = []`) | Port-forward |

```powershell
# Lab, no domain:
kubectl get ingress -n bank-of-anthos-dev frontend

# Fallback / no Ingress:
kubectl -n bank-of-anthos-dev port-forward svc/frontend 8081:80
```

Demo login: **`testuser` / `bankofanthos`** (also `alice`, `bob`, `eve` with the same password).

**Grafana** (`enable_monitoring = true`)

| `ingress_domain` | How you get the URL |
|---|---|
| Set | `https://boa-grafana.<domain>` — same ALB as frontend (`group.name`), not a second balancer |
| Empty | No Ingress. Port-forward: |

```powershell
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
```

Open `http://localhost:3000`. User `admin`; password from Secrets Manager (`admin_password`). Prometheus and Alertmanager stay ClusterIP (no public Ingress).

## Optional: prod

1. Set `enabled_environments = ["dev", "prod"]` in `terraform/terraform.tfvars` and apply (extra RDS pair + `root-prod`). Scale nodes first if you will hit the pod cap — [operations.md](operations.md#node-capacity).
2. Run **`cd-update-values-prod`** manually — copies tags from `values-dev.yaml` into `values-prod.yaml` (never auto-promotes).
3. In Argo CD, **Sync** `bank-of-anthos-secrets-prod` then `bank-of-anthos-prod` (no auto-sync on prod children).
4. App namespace: `bank-of-anthos-prod`. With a domain: `https://boa-prod.<domain>` if `"prod"` is also in `ingress_environments` (same ALB when domain is set).

## Optional: turn on monitoring later

1. `enable_monitoring = true` in `terraform.tfvars` and `terraform apply` (creates `root-platform-monitoring`; `desired_size` on an **existing** node group is ignored — scale with `aws eks update-nodegroup-config`).
2. `.\scripts\bootstrap-grafana.ps1`
3. Point `argocd_target_revision` at the branch that contains `gitops/platform/monitoring` until it is on `main`.
4. Wait for Application `root-platform-monitoring` to Healthy.

## Order that actually works

Bootstrap → `terraform apply` (platform) → JWT script → (Grafana script if monitoring) → `ci-build-images` → wait for Argo → open frontend URL (or port-forward).

JWT before images is fine; images before JWT means login/JWT-using services stay broken until the secret exists. Grafana script before the monitoring Application exists is fine (the Secrets Manager secret can sit unused).

## Tear down

ALBs are created by the AWS Load Balancer Controller from **Ingress**, not by Terraform. If you `terraform destroy` first, Helm removes the controller while Ingress/ALB ENIs remain and the VPC destroy hangs.

**0.** Disable GitHub Action `terraform-apply` (Actions → workflow → Disable) so CI does not recreate the stack mid-destroy. Kubeconfig must already use `--role-arn` (section 4).

**1.** Delete Argo Applications **while the ALB controller is still running** (cascade + finalizers). Do not `kubectl delete ingress` first while Argo is healthy — self-heal recreates it.

```powershell
kubectl get applications -n argocd
kubectl delete applications --all -n argocd
kubectl get applications -n argocd
```

Wait until the list is empty. If an Application sticks, it is usually `resources-finalizer.argocd.argoproj.io`.

**2.** Ingress can survive after Applications are gone. Delete leftovers, then wait for the ALB:

```powershell
kubectl get ingress -A
kubectl delete ingress --all --all-namespaces
```

If a delete hangs on `Terminating`, `kubectl describe` it. Finalizer `ingress.k8s.aws/resources` is expected — the controller is tearing down the ALB. **Do not** uninstall `aws-load-balancer-controller` yet.

```powershell
aws elbv2 describe-load-balancers --region eu-central-1 `
  --query "LoadBalancers[].[LoadBalancerName,State.Code]" --output table
```

Proceed only when there are **no** `k8s-*` balancers (often 2–5 minutes). ExternalDNS can then remove aliases while it is still installed.

**3.** Destroy the platform stack (same PAT as apply):

```powershell
cd terraform
$env:TF_VAR_argocd_gh_token = "ghp_..."
terraform destroy
```

Leave **`bootstrap/`** in place (S3 state, DynamoDB lock, GitHub OIDC). JWT / Grafana secrets in Secrets Manager are **not** in this state — delete them in AWS if you want a clean account.

**If destroy fails on subnets / IGW:** an ALB ENI or SG is still in the VPC. Find ENIs in that VPC, delete leftovers, re-run `terraform destroy`. Do not delete the controller Helm release before the ALB is gone.

## Do not commit

`bootstrap/terraform.tfvars`, `terraform/backend.conf`, `*.tfstate`, PATs.

`terraform/terraform.tfvars` **is** committed (knobs, no secrets). Tokens only via `$env:TF_VAR_github_token` and `$env:TF_VAR_argocd_gh_token`.
