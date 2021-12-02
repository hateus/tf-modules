output "amp_workspace_id" {
  value = aws_prometheus_workspace.amp_eks.id
}

output "amp_workspace_arn" {
  value = aws_prometheus_workspace.amp_eks.arn
}

output "amp_workspace_endpoint" {
  value = aws_prometheus_workspace.amp_eks.prometheus_endpoint
}

output "amp-role-write-arn" {
  value = aws_iam_role.amp_role_write.arn
}

output "amp-role-query-arn" {
  value = aws_iam_role.amp_role_query.arn
}
