locals {
  in_cluster_server = "https://kubernetes.default.svc"

  project_destinations = concat(
    [
      {
        server    = local.in_cluster_server
        namespace = var.namespace
      }
    ],
    [
      for ns in var.destination_namespaces : {
        server    = local.in_cluster_server
        namespace = ns
      }
    ]
  )

  # One root App-of-Apps per enabled environment (dev / prod).
  env_root_applications = {
    for env in var.enabled_environments :
    "root-${env}" => {
      namespace  = var.namespace
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
      project    = var.app_project_name
      source = {
        repoURL        = var.repo_url
        path           = var.gitops_app_paths[env]
        targetRevision = var.target_revision
        # Inject fork-specific URL so Application templates stay free of hardcoded remotes.
        helm = {
          parameters = [
            {
              name  = "repoURL"
              value = var.repo_url
            },
            {
              name  = "targetRevision"
              value = var.target_revision
            },
          ]
        }
      }
      destination = {
        server    = local.in_cluster_server
        namespace = var.namespace
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=true"]
      }
    }
  }

  # ClusterSecretStore (cluster-scoped) — always synced when Argo CD is installed.
  platform_root_applications = {
    root-platform-external-secrets = {
      namespace  = var.namespace
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
      project    = var.app_project_name
      source = {
        repoURL        = var.repo_url
        path           = var.gitops_platform_external_secrets_path
        targetRevision = var.target_revision
      }
      destination = {
        server    = local.in_cluster_server
        namespace = var.external_secrets_namespace
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true",
          "ServerSideApply=true",
        ]
      }
    }
  }

  root_applications = merge(local.env_root_applications, local.platform_root_applications)
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true
  wait             = true
  atomic           = true
  timeout          = 600

  # ClusterIP + port-forward for UI (ALB / Ingress is separate platform work).
  values = [
    yamlencode({
      configs = {
        params = {
          "server.insecure" = false
        }
      }
      server = {
        service = {
          type = "ClusterIP"
        }
      }
    })
  ]
}

# Repository credentials for private GitHub (never commit the PAT; use TF_VAR_argocd_gh_token).
resource "kubernetes_secret_v1" "repo" {
  metadata {
    name      = "repo-bank-of-anthos"
    namespace = helm_release.argocd.namespace
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    type     = "git"
    url      = var.repo_url
    username = var.gh_username
    password = var.gh_token
  }

  depends_on = [helm_release.argocd]
}

# AppProject + root App-of-Apps (avoids kubernetes_manifest CRD plan chicken-egg).
resource "helm_release" "argocd_apps" {
  name       = "argocd-apps"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = var.apps_chart_version
  namespace  = helm_release.argocd.namespace
  wait       = true
  atomic     = true
  timeout    = 300

  values = [
    yamlencode({
      projects = {
        (var.app_project_name) = {
          namespace    = var.namespace
          description  = "Bank of Anthos GitOps apps (shared cluster; optional env namespaces)"
          sourceRepos  = [var.repo_url]
          destinations = local.project_destinations
          clusterResourceWhitelist = [
            { group = "*", kind = "*" }
          ]
          namespaceResourceWhitelist = [
            { group = "*", kind = "*" }
          ]
        }
      }

      applications = local.root_applications
    })
  ]

  depends_on = [
    helm_release.argocd,
    kubernetes_secret_v1.repo,
  ]
}
