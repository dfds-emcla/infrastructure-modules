variable "cluster_name" {
  type = string
}

variable "deploy_name" {
  type        = string
  description = "Unique identifier of the deployment, only needs override if deploying multiple instances"
  default     = "traefik"
}

variable "namespace" {
  type        = string
  description = "The namespace in which to deploy Helm resources"
  default     = "traefik"
}

variable "replicas" {
  description = "The number of Traefik pods to spawn"
  type        = number
}

variable "http_nodeport" {
  description = "Nodeport used by ALB's to connect to the Traefik instance"
  type        = number
}

variable "admin_nodeport" {
  description = "Nodeport used by ALB's to connect to the Traefik instance admin page"
  type        = number
}

variable "github_owner" {
  type        = string
  description = "Name of the Github owner (previously: organization)"
}

variable "repo_name" {
  type        = string
  description = "Name of the Github repo to store the manifests in"
}

variable "repo_branch" {
  type        = string
  description = "Override the default branch of the repo (optional)"
  default     = null
}

variable "helm_chart_version" {
  type        = string
  description = "The version of the Traefik v2 Helm Chart that should be used"
  default     = null
}

variable "additional_args" {
  type        = list
  description = "Pass arguments to the additionalArguments node in the Traefik Helm chart"
  default     = ["--metrics.prometheus"]
}

variable "is_using_alb_auth" {
  type    = bool
  default = false
}

variable "dashboard_deploy" {
  type        = bool
  description = "Deploy ingressroute for external access to Traefik dashboard."
  default     = true
}

variable "dashboard_username" {
  type        = string
  description = "Username used for basic authentication."
  default     = "cloudengineer"
}

variable "dashboard_ingress_host" {
  type        = string
  description = "The alb auth dns name for accessing Traefik."
}

variable "ssm_param_createdby" {
  type        = string
  description = "The value that will be used for the createdBy key when tagging any SSM parameters"
  default     = null
}
