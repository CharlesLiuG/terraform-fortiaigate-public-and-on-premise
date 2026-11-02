variable "namespace" {
  description = "Nginx Ingress 命名空间"
  type        = string
  default     = "ingress-nginx"
}

variable "replica_count" {
  description = "Controller 副本数"
  type        = number
  default     = 2
}

variable "service_type" {
  description = "Service 暴露类型"
  type        = string
  default     = "NodePort"
}

variable "node_port_http" {
  description = "HTTP NodePort"
  type        = number
  default     = 30080
}

variable "node_port_https" {
  description = "HTTPS NodePort"
  type        = number
  default     = 30443
}

variable "host_network" {
  description = "是否使用主机网络"
  type        = bool
  default     = false
}

# --- 国内镜像源配置 ---
variable "image_registry" {
  description = "镜像仓库地址（国内源）"
  type        = string
  default     = "registry.cn-hangzhou.aliyuncs.com"
}

variable "controller_image" {
  description = "Nginx Ingress Controller 镜像名称"
  type        = string
  default     = "google_containers/nginx-ingress-controller"
}

variable "controller_image_tag" {
  description = "Nginx Ingress Controller 镜像 Tag"
  type        = string
  default     = "v1.12.1"
}

variable "kube_webhook_certgen_image" {
  description = "Webhook Certgen 镜像名称"
  type        = string
  default     = "google_containers/kube-webhook-certgen"
}

variable "kube_webhook_certgen_tag" {
  description = "Webhook Certgen 镜像 Tag"
  type        = string
  default     = "v1.5.2"
}
