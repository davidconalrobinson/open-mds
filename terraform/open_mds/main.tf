# https://github.com/kubernetes/ingress-nginx/tree/release-1.9/charts/ingress-nginx
resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  chart            = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  version          = "4.8.3"
  namespace        = var.ingress_namespace
  create_namespace = true
  lint             = true
  timeout          = 600
  values           = [
    file("../charts/ingress-nginx/values.yaml")
  ]
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/do-loadbalancer-hostname"
    value = "${var.ingress_namespace}.${var.host}"
  }
}

# https://github.com/cert-manager/cert-manager/tree/v1.13.3/deploy/charts/cert-manager
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  chart            = "cert-manager"
  repository       = "https://charts.jetstack.io"
  version          = "1.13.3"
  namespace        = var.ingress_namespace
  create_namespace = true
  lint             = true
  timeout          = 600
  values           = [
    file("../charts/cert-manager/values.yaml")
  ]
  depends_on = [
    helm_release.ingress_nginx
  ]
}

# Find this chart in /charts/cert-issuer
resource "helm_release" "cert_issuer" {
  name             = "cert-issuer"
  chart            = "../charts/cert-issuer"
  namespace        = var.ingress_namespace
  create_namespace = true
  lint             = true
  timeout          = 600
  values           = [
    file("../charts/cert-issuer/values.yaml")
  ]
  set {
    name  = "letsencrypt_email"
    value = var.lets_encrypt_email
  }
  depends_on = [
    helm_release.cert_manager
  ]
}

# https://github.com/bitnami/charts/tree/5687b241a2daa04df4b38f8e4d7dd110c64f5c7c/bitnami/clickhouse
resource "helm_release" "clickhouse" {
  name             = "clickhouse"
  chart            = "oci://registry-1.docker.io/bitnamicharts/clickhouse"
  version          = "4.1.16"
  namespace        = var.platform_namespace
  create_namespace = true
  lint             = true
  timeout          = 600
  values           = [
    file("../charts/clickhouse/values.yaml")
  ]
  set {
    name  = "auth.username"
    value = var.clickhouse_username
  }
  set_sensitive {
    name  = "auth.password"
    value = var.clickhouse_password
  }
  depends_on = [
    helm_release.cert_issuer
  ]
}

# https://github.com/apache/airflow/tree/helm-chart/1.11.0/chart
resource "helm_release" "airflow" {
  name             = "airflow"
  chart            = "airflow"
  repository       = "https://airflow.apache.org"
  version          = "1.11.0"
  namespace        = var.platform_namespace
  create_namespace = true
  lint             = true
  timeout          = 600
  wait             = false
  values           = [
    file("../charts/airflow/values.yaml")
  ]
  set {
    name  = "ingress.web.hosts[0].name"
    value = "airflow.${var.platform_namespace}.${var.host}"
  }
  set {
    name  = "config.webserver.base_url"
    value = "https://airflow.${var.platform_namespace}.${var.host}"
  }
  set {
    name  = "ingress.web.annotations.cert-manager\\.io/cluster-issuer"
    value = "letsencrypt-${var.lets_encrypt_environment}"
  }
  set {
    name  = "ingress.web.hosts[0].tls.secretName"
    value = "letsencrypt-${var.lets_encrypt_environment}"
  }
  set {
    name  = "config.github_enterprise.client_id"
    value = var.airflow_github_auth_app_client_id
  }
  set {
    name  = "dags.gitSync.repo"
    value = var.airflow_dag_sync_repo
  }
  set {
    name  = "dags.gitSync.branch"
    value = var.airflow_dag_sync_branch
  }
  set {
    name  = "dags.gitSync.subPath"
    value = var.airflow_dag_sync_subpath
  }
  set_sensitive {
    name  = "config.github_enterprise.client_secret"
    value = var.airflow_github_auth_app_client_secret
  }
  set {
    name  = "extraEnv"
    value = <<-EOT
      - name: 'RBAC'
        value: '${replace(jsonencode(var.rbac), ",", "\\,")}'
    EOT
  }
  depends_on = [
    helm_release.cert_issuer,
    helm_release.clickhouse
  ]
}

# https://github.com/apache/superset/blob/superset-helm-chart-0.11.2/helm/superset
resource "helm_release" "superset" {
  name             = "superset"
  chart            = "superset"
  repository       = "https://apache.github.io/superset"
  version          = "0.11.2"
  namespace        = var.platform_namespace
  create_namespace = true
  lint             = true
  timeout          = 600
  values           = [
    file("../charts/superset/values.yaml")
  ]
  set_sensitive {
    name  = "extraSecretEnv.SUPERSET_SECRET_KEY"
    value = var.superset_secret_key
  }
  set {
    name  = "ingress.hosts"
    value = "{superset.${var.platform_namespace}.${var.host}}"
  }
  set {
    name  = "ingress.annotations.cert-manager\\.io/cluster-issuer"
    value = "letsencrypt-${var.lets_encrypt_environment}"
  }
  set {
    name  = "ingress.tls[0].secretName"
    value = "letsencrypt-${var.lets_encrypt_environment}"
  }
  set {
    name  = "ingress.tls[0].hosts"
    value = "{superset.${var.platform_namespace}.${var.host}}"
  }
  set {
    name  = "extraSecretEnv.GITHUB_AUTH_APP_CLIENT_ID"
    value = var.superset_github_auth_app_client_id
  }
  set_sensitive {
    name  = "extraSecretEnv.GITHUB_AUTH_APP_CLIENT_SECRET"
    value = var.superset_github_auth_app_client_secret
  }
  set {
    name  = "extraEnv.RBAC"
    value = replace(
      replace(
        replace(
          jsonencode(var.rbac),
          ",",
          "\\,"
        ),
        "{",
        "\\{"
      ),
      "}",
      "\\}"
    )
  }
  depends_on = [
    helm_release.cert_issuer,
    helm_release.clickhouse
  ]
}

# https://github.com/jupyterhub/zero-to-jupyterhub-k8s/tree/3.2.1/jupyterhub
resource "helm_release" "jupyterhub" {
  name             = "jupyterhub"
  chart            = "jupyterhub"
  repository       = "https://hub.jupyter.org/helm-chart/"
  version          = "3.2.1"
  namespace        = var.platform_namespace
  create_namespace = true
  lint             = true
  timeout          = 600
  values           = [
    file("../charts/jupyterhub/values.yaml")
  ]
  set {
    name  = "ingress.hosts"
    value = "{jupyterhub.${var.platform_namespace}.${var.host}}"
  }
  set {
    name  = "ingress.annotations.cert-manager\\.io/cluster-issuer"
    value = "letsencrypt-${var.lets_encrypt_environment}"
  }
  set {
    name  = "ingress.tls[0].secretName"
    value = "letsencrypt-${var.lets_encrypt_environment}"
  }
  set {
    name  = "hub.config.OAuthenticator.oauth_callback_url"
    value = "https://jupyterhub.${var.platform_namespace}.${var.host}/hub/oauth_callback"
  }
  set {
    name  = "hub.config.OAuthenticator.client_id"
    value = var.jupyterhub_github_auth_app_client_id
  }
  set_sensitive {
    name  = "hub.config.OAuthenticator.client_secret"
    value = var.jupyterhub_github_auth_app_client_secret
  }
  dynamic set_list {
    for_each = length([for k, v in var.rbac : k if contains(["admin"], v.platform_role)]) > 0 ? ["enabled"] : []
    content {
      name  = "hub.config.GitHubOAuthenticator.admin_users"
      value = [for k, v in var.rbac : k if contains(["admin"], v.platform_role)]
    }
  }
  dynamic set_list {
    for_each = length([for k, v in var.rbac : k if contains(["admin", "engineer", "scientist"], v.platform_role)]) > 0 ? ["enabled"] : []
    content {
      name  = "hub.config.GitHubOAuthenticator.allowed_users"
      value = [for k, v in var.rbac : k if contains(["admin", "engineer", "scientist"], v.platform_role)]
    }
  }
  depends_on = [
    helm_release.cert_issuer,
    helm_release.clickhouse
  ]
}

# # https://github.com/open-metadata/openmetadata-helm-charts/tree/openmetadata-1.2.7/charts/deps
# resource "helm_release" "open_metadata_dependencies" {
#   name             = "open-metadata-dependencies"
#   chart            = "openmetadata-dependencies"
#   repository       = "https://helm.open-metadata.org"
#   version          = "1.2.7"
#   namespace        = var.platform_namespace
#   create_namespace = true
#   lint             = true
#   timeout          = 600
#   values           = [
#     file("../charts/open-metadata-dependencies/values.yaml")
#   ]
#   depends_on = [
#     helm_release.cert_issuer,
#     helm_release.clickhouse
#   ]
# }

# # https://github.com/open-metadata/openmetadata-helm-charts/tree/openmetadata-1.2.7/charts/openmetadata
# resource "helm_release" "open_metadata" {
#   name             = "open-metadata"
#   chart            = "openmetadata"
#   repository       = "https://helm.open-metadata.org"
#   version          = "1.2.7"
#   namespace        = var.platform_namespace
#   create_namespace = true
#   lint             = true
#   timeout          = 600
#   values           = [
#     file("../charts/open-metadata/values.yaml")
#   ]
#   depends_on = [
#     helm_release.cert_issuer,
#     helm_release.open_metadata_dependencies,
#     helm_release.clickhouse
#   ]
# }
