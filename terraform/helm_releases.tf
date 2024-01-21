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
  depends_on = [
    digitalocean_kubernetes_cluster.cluster
  ]
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
    digitalocean_kubernetes_cluster.cluster,
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
    digitalocean_kubernetes_cluster.cluster,
    helm_release.cert_manager,
    digitalocean_record.dns_record
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
    digitalocean_kubernetes_cluster.cluster,
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
  set_sensitive {
    name  = "config.github_enterprise.client_secret"
    value = var.airflow_github_auth_app_client_secret
  }
  depends_on = [
    digitalocean_kubernetes_cluster.cluster,
    helm_release.cert_issuer
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
  timeout          = 120
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
  depends_on = [
    digitalocean_kubernetes_cluster.cluster,
    helm_release.cert_issuer
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
  depends_on = [
    digitalocean_kubernetes_cluster.cluster,
    helm_release.cert_issuer
  ]
}
