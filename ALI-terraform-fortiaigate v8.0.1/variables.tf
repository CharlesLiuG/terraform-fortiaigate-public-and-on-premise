variable "region" {
  default = "cn-wulanchabu"
}

variable "namespace" {
  default = "fortiaigate"
}

variable "helm_release_name" {
  default = "fortiaigate"
}

variable "certificate_id" {
  description = "阿里云 SSL 证书 ID，用于 ALB HTTPS 监听"
  type        = string
  default     = ""
}

variable "ingress_host" {
  description = "Optional hostname for ALB (leave empty for path-only routing)"
  default     = ""
}

# ─────────────────────────────────────────────────────────────────────────────
# ACK Configuration - 选择使用已有集群或创建新集群
# ─────────────────────────────────────────────────────────────────────────────
variable "create_ack" {
  description = "Set to true to create a new ACK cluster (VPC/VSwitch auto-created); false to use existing"
  type        = bool
  default     = false
}

variable "cluster_name" {
  description = "ACK cluster name (existing or new)"
  type        = string
}

variable "cluster_version" {
  description = "ACK cluster Kubernetes version (only used when create_ack = true)"
  type        = string
  default     = "1.35.2-aliyun.1"
}

variable "gpu_instance_type" {
  description = "GPU instance type for worker node (only used when create_ack = true)"
  type        = string
  default     = "ecs.gn7i-c16g1.4xlarge"
}

variable "gpu_node_pool_desired" {
  description = "Desired number of GPU nodes (only used when create_ack = true)"
  type        = number
  default     = 1
}

variable "vpc_cidr" {
  description = "VPC CIDR block (only used when create_ack = true)"
  type        = string
  default     = "10.0.0.0/16"
}

# ─────────────────────────────────────────────────────────────────────────────
# NAS Configuration - 选择使用已有 NAS 或创建新的
# ─────────────────────────────────────────────────────────────────────────────
variable "create_nas" {
  description = "Set to true to create new NAS file system; false to use existing"
  type        = bool
  default     = false
}

variable "nas_id" {
  description = "Existing NAS file system ID (required when create_nas = false)"
  type        = string
  default     = ""
}

variable "nas_mount_target" {
  description = "Existing NAS mount target domain (required when create_nas = false)"
  type        = string
  default     = ""
}

# ─────────────────────────────────────────────────────────────────────────────
# GPU Node Name - 自动获取或手动指定
# ─────────────────────────────────────────────────────────────────────────────
variable "gpu_node_name" {
  description = "GPU node hostname. Leave empty to auto-detect from ACK GPU node pool"
  type        = string
  default     = ""
}

# ─────────────────────────────────────────────────────────────────────────────
# Cluster Addons - 灵活控制安装
# ─────────────────────────────────────────────────────────────────────────────
variable "install_nas_csi_driver" {
  description = "Install Alibaba NAS CSI Driver (通常 ACK 已内置)"
  type        = bool
  default     = false
}

variable "create_nas_storage_class" {
  description = "Create NAS StorageClasses (set false if already exist in cluster)"
  type        = bool
  default     = true
}

variable "install_alb_ingress_controller" {
  description = "Install ALB Ingress Controller (通常 ACK 已内置)"
  type        = bool
  default     = false
}

variable "install_nvidia_device_plugin" {
  description = "Install NVIDIA Device Plugin (ACK GPU 节点池通常已自带)"
  type        = bool
  default     = false
}

variable "deploy_app" {
  description = "Set to true to deploy FortiAIGate app (requires ACK cluster and nodes to be running)"
  type        = bool
  default     = true
}
