# --------------------------------------------------
# Namespace
# --------------------------------------------------

locals {
  namespace         = "flux-system"
  fluentd_name      = "fluentd-cloudwatch"
  fluentd_namespace = "fluentd"
}

# --------------------------------------------------
# Github
# --------------------------------------------------

locals {
  known_hosts = "github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg="
}

data "github_repository" "main" {
  full_name = "${var.github_owner}/${var.repo_name}"
}

data "github_branch" "flux_branch" {
  repository = var.repo_name
  branch     = var.repo_branch
}

# --------------------------------------------------
# Monitoring
# --------------------------------------------------

locals {
  cluster_repo_path = "clusters/${var.cluster_name}"
  config_repo_path  = "platform-apps/${var.cluster_name}/${var.deploy_name}/config"
  app_install_name  = "platform-apps-${var.deploy_name}"

  app_config_path = {
    "apiVersion" = "kustomize.toolkit.fluxcd.io/v1beta2"
    "kind"       = "Kustomization"
    "metadata" = {
      "name"      = "${local.app_install_name}-config"
      "namespace" = "flux-system"
    }
    "spec" = {
      "interval" = "1m0s"
      "sourceRef" = {
        "kind" = "GitRepository"
        "name" = "flux-system"
      }
      "path"  = "./${local.config_repo_path}"
      "prune" = true
    }
  }

  config_init = {
    "apiVersion" = "kustomize.config.k8s.io/v1beta1"
    "kind"       = "Kustomization"
    "resources" = [
      "https://github.com/dfds/platform-apps/apps/${var.deploy_name}"
    ]
    "images" = [
      {
        "name"   = "fluent/fluentd-kubernetes-daemonset",
        "newTag" = "v1.11-debian-cloudwatch-1"
      }
    ]
    "patchesStrategicMerge" = [
      "patch.yaml"
    ]
  }

  config_patch_yaml = <<YAML
---
apiVersion: v1
kind: Namespace
metadata:
  name: ${local.fluentd_namespace}

---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: ${local.fluentd_name}
  namespace: ${local.fluentd_namespace}
spec:
  template:
    spec:
      serviceAccountName: ${local.fluentd_name}
      containers:
        - name: ${local.fluentd_name}
          env:
            - name: AWS_REGION
              value: "${var.aws_region}"
            - name: RETENTION_IN_DAYS
              value: "${var.retention_in_days}"

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${local.fluentd_name}
  namespace: ${local.fluentd_namespace}
data:
  02-tag.conf: |-
    # Tag with namespace and prefix with clustername
    <match kubernetes.**>
      @type rewrite_tag_filter
      <rule>
        key $.kubernetes.namespace_name
        pattern ^(.+)$
        tag /k8s/${var.cluster_name}/$1
      </rule>
    </match>

---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${local.fluentd_name}
  namespace: ${local.fluentd_namespace}
  annotations:
    eks.amazonaws.com/role-arn: ${aws_iam_role.this.arn}
    eks.amazonaws.com/sts-regional-endpoints: "true"
YAML
}


# --------------------------------------------------
# AWS
# --------------------------------------------------

# required TLS Certificate which is then used for the openid connect provider thumbprint list
data "tls_certificate" "eks" {
  url = "https://${var.eks_openid_connect_provider_url}"
}

data "aws_caller_identity" "this" {}

data "aws_iam_policy_document" "this_trust" {
  statement {
    effect = "Allow"

    principals {
      type = "Federated"

      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.this.account_id}:oidc-provider/${var.eks_openid_connect_provider_url}",
      ]
    }

    condition {
      test     = "StringEquals"
      values   = ["system:serviceaccount:${local.fluentd_namespace}:${local.fluentd_name}"]
      variable = "${var.eks_openid_connect_provider_url}:sub"
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]
  }
}

data "aws_iam_policy_document" "this" {
  statement {
    sid    = "ReadLogs"
    effect = "Allow"
    actions = [
      "logs:Describe*",
      "logs:Get*",
      "logs:List*"
    ]
    resources = ["*"]
  }

  statement {
    sid       = "LogStream"
    effect    = "Allow"
    actions   = ["logs:*"]
    resources = ["arn:aws:logs:*:${data.aws_caller_identity.this.account_id}:log-group:/k8s/${var.cluster_name}/*:log-stream:*"]
  }

  statement {
    sid       = "LogGroup"
    effect    = "Allow"
    actions   = ["logs:*"]
    resources = ["arn:aws:logs:*:${data.aws_caller_identity.this.account_id}:log-group:/k8s/${var.cluster_name}/*"]
  }
}