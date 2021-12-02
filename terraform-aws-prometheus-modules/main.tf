data "aws_caller_identity" "this" {}
data "aws_region" "this" {}
data "aws_eks_cluster" "this" {
  name = var.eks_cluster_name
}

data "template_file" "prometheus_helm_values" {
  count    = var.update_kube_prom_stack_values == true ? 1 : 0
  template = file("${path.module}/template/prometheus-amp.values")

  vars = {
    region             = data.aws_region.this.name
    sa_write_name      = var.service_account_write_name
    sa_query_name      = var.service_account_query_name
    iam_role_arn_write = aws_iam_role.amp_role_write.arn
    iam_role_arn_query = aws_iam_role.amp_role_query.arn
    amp_endpoint       = aws_prometheus_workspace.amp_eks.prometheus_endpoint
  }
}

data "tls_certificate" "this" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

locals {
  oidc_provider = replace(data.aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")
}

resource "aws_prometheus_workspace" "amp_eks" {
  alias = var.amp_alias_name
}

resource "aws_prometheus_rule_group_namespace" "rule_groups" {
  count        = length(var.rule_groups)
  name         = var.rule_groups[count.index].name
  workspace_id = aws_prometheus_workspace.amp_eks.id
  data         = file(var.rule_groups[count.index].data_filename)
}

resource "aws_prometheus_alert_manager_definition" "alert_manager" {
  count        = var.define_amp_alert_manager == true ? 1 : 0
  workspace_id = aws_prometheus_workspace.amp_eks.id
  definition   = file(var.amp_alert_manager_filename)
}

data "aws_iam_policy_document" "remote_write_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.this.account_id}:oidc-provider/${local.oidc_provider}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider}:sub"
      values = [
        "system:serviceaccount:${var.prometheus_namespace}:${var.service_account_write_name}"
      ]
    }
  }
}

resource "aws_iam_role" "amp_role_write" {
  name               = var.service_account_iam_role_write_name
  description        = var.service_account_iam_role_write_desc
  assume_role_policy = data.aws_iam_policy_document.remote_write_assume.json
}

resource "aws_iam_policy" "amp_write" {
  name        = var.service_account_iam_policy_write_name
  description = "Permission to write tsdb to AMP workspaces."

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "aps:RemoteWrite",
          "aps:GetSeries",
          "aps:GetLabels",
          "aps:GetMetricMetadata"
        ],
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "amp_write" {
  role       = aws_iam_role.amp_role_write.name
  policy_arn = aws_iam_policy.amp_write.arn
}

data "aws_iam_policy_document" "remote_query_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.this.account_id}:oidc-provider/${local.oidc_provider}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider}:sub"
      values = [
        "system:serviceaccount:${var.grafana_namespace}:${var.service_account_query_name}"
      ]
    }
  }
}


resource "aws_iam_role" "amp_role_query" {
  name               = var.service_account_iam_role_query_name
  description        = var.service_account_iam_role_query_desc
  assume_role_policy = data.aws_iam_policy_document.remote_query_assume.json
}

resource "aws_iam_policy" "amp_query" {
  name        = var.service_account_iam_policy_query_name
  description = "Permission to query tsdb from AMP workspaces."

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "aps:QueryMetrics",
          "aps:GetSeries",
          "aps:GetLabels",
          "aps:GetMetricMetadata"
        ],
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "amp_query" {
  role       = aws_iam_role.amp_role_query.name
  policy_arn = aws_iam_policy.amp_query.arn
}

/*
resource "aws_iam_openid_connect_provider" "this" {
  count           = var.create_oidc_iam_provider == true ? 1 : 0
  client_id_list  = ["sts:amazonaws.com"]
  thumbprint_list = [data.tls_certificate.this.certificates[0].sha1_fingerprint]
  url             = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}
*/

resource "null_resource" "this" {
  count = var.create_oidc_iam_provider == true ? 1 : 0

  provisioner "local-exec" {
    command = "eksctl utils associate-iam-oidc-provider --cluster ${var.eks_cluster_name} --region ${data.aws_region.this.name} --approve"
  }

  depends_on = [
    aws_iam_role_policy_attachment.amp_query,
    aws_iam_role_policy_attachment.amp_write
  ]
}

resource "helm_release" "kube_prom_stack" {
  count            = var.initiate_kube_prom_stack == true ? 1 : 0
  name             = var.kube_prom_stack_release_name
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = var.prometheus_namespace
  create_namespace = true
  cleanup_on_fail  = true
}

resource "local_file" "kube_prom_stack_values" {
  count    = var.update_kube_prom_stack_values == true ? 1 : 0
  content  = data.template_file.prometheus_helm_values[0].rendered
  filename = "${path.cwd}/values-custom.yaml"
}

resource "null_resource" "kube_prom_stack_update" {
  count = var.update_kube_prom_stack_values == true ? 1 : 0

  provisioner "local-exec" {
    command = "helm upgrade --install ${var.kube_prom_stack_release_name} -f ${path.cwd}/values-custom.yaml --create-namespace --namespace ${var.prometheus_namespace} prometheus-community/kube-prometheus-stack"
  }

  depends_on = [
    local_file.kube_prom_stack_values
  ]
}
