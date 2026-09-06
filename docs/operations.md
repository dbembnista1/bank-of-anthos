# Operations

Day-2 runbook for a lab that is already up. First-time apply and destroy: [deploy.md](deploy.md).


## Node capacity

VPC CNI assigns each pod a secondary IP from the node ENI. A `t3.medium` lands on the order of **17 pods** (`max-pods` ≈ `(ENIs × (IPv4-per-ENI − 1)) + 2`). DaemonSets (kube-proxy, VPC CNI, optional monitoring agents) count against that number.

`dev` at 1 replica per service plus seed Jobs plus loadgenerator already fills two nodes once platform add-ons are running. `dev` + `prod` HA (`replicas: 2` / `3` in `values-prod.yaml`) **does not fit** on two `t3.medium`s. Symptom: pods `Pending` with `Too many pods`.

There is **no Cluster Autoscaler**. Replica counts are fixed in Helm; lab spend should not surprise you. Scale the node group on purpose.

```powershell
aws eks list-nodegroups --cluster-name bank-of-anthos --region eu-central-1
aws eks update-nodegroup-config `
  --cluster-name bank-of-anthos `
  --nodegroup-name main `
  --scaling-config minSize=2,maxSize=4,desiredSize=3 `
  --region eu-central-1
```

`min` / `max` in that command cannot exceed what the ASG already allows. To raise the ceiling, change `eks_node_max_size` in `terraform/terraform.tfvars` and apply, **then** bump `desiredSize`.

Create-time desired size in Terraform is `(prod ? 3 : 2) + (monitoring ? 1 : 0)`. That formula does not keep running after the node group exists.

## Why `terraform apply` does not move `desired_size`

`terraform-aws-modules/eks` **ignores** managed node group `desired_size` after create (`lifecycle.ignore_changes` on the ASG). `min_size` / `max_size` still come from Terraform.

Effect: turning on `enable_monitoring` or adding `"prod"` later does **not** add nodes. The apply succeeds; pods still Pending. Scale with `update-nodegroup-config` (above), not by re-applying the same `tfvars`.

This is intentional. Autoscaling a lab overnight is a bill. The interview answer is: Terraform owns the bounds; a human owns the current count.

## Seed Jobs

Umbrella Jobs `populate-accounts-db` and `populate-ledger-db` apply upstream schema (and demo rows when `dbInit.loadDemoData=true`) to **RDS**. They need ExternalSecrets (`accounts-db-credentials`, `ledger-db-credentials`) first — Argo sync-wave `-1` on the secrets Application.

Java ledger services (`ledgerwriter`, `balancereader`, `transactionhistory`) probe `/ready` against Postgres. If the ledger Job has not Completed, those pods stay unready even though the Deployment exists. Wait for the Jobs, do not scale or restart the Java pods first.

```powershell
kubectl get jobs,pods -n bank-of-anthos-dev
kubectl logs job/populate-ledger-db -n bank-of-anthos-dev
```

Jobs use `ttlSecondsAfterFinished: 86400` and Argo `Replace` on sync (Job pod templates are immutable). Re-syncing the app can re-run them; SQL is written `IF NOT EXISTS` where it matters.

## Promote prod

Prod is a **manual gate** in two places: Git tags and Argo sync.

1. Platform: `"prod"` in `enabled_environments`, apply (extra RDS pair + `root-prod`). Scale nodes before HA replicas land.
2. Images: Actions → **`cd-update-values-prod`** (`workflow_dispatch` only). Copies tags from `values-dev.yaml` into `values-prod.yaml`. A green build never does this.
3. Argo: `root-prod` auto-syncs the child **Application** objects. The children `bank-of-anthos-secrets-prod` and `bank-of-anthos-prod` have **no** `automated` syncPolicy. **Sync** secrets first, then the umbrella.

Until you Sync, prod namespaces can exist while workloads stay at the previous (or empty) spec. That is the point.

## Terraform plan / apply from GitHub

| Workflow | Trigger | Effect |
|---|---|---|
| `terraform-plan.yaml` | PR on `terraform/**`, or `workflow_dispatch` | `fmt -check`, `validate`, `plan`; plan comment on the PR |
| `terraform-apply.yaml` | merge to `main` (`terraform/**`), or `workflow_dispatch` | `apply` (concurrency 1; DynamoDB lock still applies). GitHub Environment `infra` |

Both assume the GitHub OIDC role from `bootstrap/` and write `backend.conf` from GitHub Variables (`TF_STATE_BUCKET`, `TF_STATE_DYNAMODB_TABLE`, `AWS_REGION`). `terraform/terraform.tfvars` is committed — laptop and GHA use the same knobs. `TF_VAR_argocd_gh_token` comes from secret `GH_PAT` (bootstrap writes it).

App workflows (`ci-build-images`, tag bumps) still have **no** kubeconfig. Apply **may** talk to EKS (Helm/Kubernetes providers) — that is platform IaC, not the umbrella.

`bootstrap/` stays local. Do not add an apply workflow there (chicken and egg: that directory creates the role CI would use).

Lab: **Disable** workflow `terraform-apply` in the Actions UI when you do not want merge-to-main to mutate AWS. Do not comment `push` out of the YAML for that. Disable it **before** [destroy](deploy.md#tear-down) so CI does not recreate the stack.

If Argo still tracks a deleted feature branch, `argocd_target_revision` in `tfvars` was left off `main` — set it back and apply.

## kubeconfig

Humans assume `bank-of-anthos-eks-admin` (EKS access entry). GitHub Actions uses the OIDC role access entry directly — no assume-role in the providers.

```powershell
cd terraform
$roleArn = terraform output -raw eks_cluster_admin_role_arn
aws eks update-kubeconfig --name bank-of-anthos --region eu-central-1 --role-arn $roleArn
```

Once written into `~/.kube/config`, later `kubectl` calls reuse that role.
