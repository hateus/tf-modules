variable "amp_alias_name" {
  description = "Alias for the AMP workspace."
  type        = string
}

variable "rule_groups" {
  description = "A list of maps rule groups"
  type        = list(map(string))
  default     = []
}

variable "define_amp_alert_manager" {
  description = "Should this module create alertmanager definition?"
  type        = bool
  default     = false
}

variable "amp_alert_manager_filename" {
  description = "Alertmanager configuration filename"
  type        = string
  default     = ""
}

variable "eks_cluster_name" {
  description = "EKS cluster name to be use."
  type        = string
}

variable "tags" {
  description = "Map of tags to the resource that will be created."
  type        = map(string)
  default     = {}
}

# IAM for Ingest data
variable "service_account_write_name" {
  description = "Name of IAM proxy ingest service account."
  type        = string
  default     = "amp-iamproxy-ingest-service-account"
}

variable "service_account_iam_role_write_name" {
  description = "Name of IAM role for the service account to ingest data."
  type        = string
  default     = "amp-iamproxy-ingest-role"
}

variable "service_account_iam_role_write_desc" {
  description = "Description of IAM role for the service account to ingest data."
  type        = string
  default     = "IAM role to be used by a K8s service account with write access to AMP."
}

variable "service_account_iam_policy_write_name" {
  description = "Name of the service account IAM policy to ingest data."
  type        = string
  default     = "AMPIngestPolicy"
}

# Iam for Query data
variable "service_account_query_name" {
  description = "Name of IAM proxy query service account."
  type        = string
  default     = "amp-iamproxy-query-service-account"
}

variable "service_account_iam_role_query_name" {
  description = "Name of IAM role for the service account to query data."
  type        = string
  default     = "amp-iamproxy-query-role"
}

variable "service_account_iam_role_query_desc" {
  description = "Description of IAM role for the service account with query access to AMP."
  type        = string
  default     = "IAM role to be used by a K8s service account with query access to AMP."
}

variable "service_account_iam_policy_query_name" {
  description = "Name of the service account IAM policy to query data."
  type        = string
  default     = "AMPQueryPolicy"
}

variable "create_oidc_iam_provider" {
  description = "Should this module create the required IAM OIDC Provider?"
  type        = bool
  default     = false
}

variable "update_kube_prom_stack_values" {
  description = "Should this module update the helm kube-prom-stack values?"
  type        = bool
  default     = false
}

variable "grafana_namespace" {
  description = "Name of Grafana namespace."
  type        = string
  default     = "monitoring"
}

variable "prometheus_namespace" {
  description = "Name of Prometheus server namespace."
  type        = string
  default     = "monitoring"
}

variable "initiate_kube_prom_stack" {
  description = "Should this module install the kube-prom-stack helm chart?"
  type        = bool
  default     = false
}

variable "kube_prom_stack_release_name" {
  description = "Release name of the kube-prom-stack"
  type = string
  default = "prometheus"
}
