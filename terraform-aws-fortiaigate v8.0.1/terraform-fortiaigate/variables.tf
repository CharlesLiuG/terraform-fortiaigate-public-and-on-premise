variable "aws_region" {
  default = "us-east-1"
}

variable "namespace" {
  default = "fortiaigate"
}

variable "helm_release_name" {
  default = "fortiaigate"
}

variable "certificate_arn" {
  description = "ACM certificate ARN for ALB HTTPS listener"
  type        = string
}

variable "ingress_host" {
  description = "Optional hostname for ALB (leave empty for path-only routing)"
  default     = ""
}

# ─────────────────────────────────────────────────────────────────────────────
# EKS Configuration - 选择使用已有集群或创建新集群
# ─────────────────────────────────────────────────────────────────────────────
variable "create_eks" {
  description = "Set to true to create a new EKS cluster (VPC/Subnet auto-created); false to use existing"
  type        = bool
  default     = false
}

variable "cluster_name" {
  description = "EKS cluster name (existing or new)"
  type        = string
}

variable "cluster_version" {
  description = "EKS cluster Kubernetes version (only used when create_eks = true)"
  type        = string
  default     = "1.35"
}

variable "gpu_instance_type" {
  description = "GPU instance type for worker node (only used when create_eks = true)"
  type        = string
  default     = "g5.xlarge"
}

variable "gpu_node_group_desired" {
  description = "Desired number of GPU nodes (only used when create_eks = true)"
  type        = number
  default     = 1
}

variable "vpc_cidr" {
  description = "VPC CIDR block (only used when create_eks = true)"
  type        = string
  default     = "10.0.0.0/16"
}

# ─────────────────────────────────────────────────────────────────────────────
# EFS Configuration - 选择使用已有 EFS 或创建新的
# ─────────────────────────────────────────────────────────────────────────────
variable "create_efs" {
  description = "Set to true to create new EFS file systems; false to use existing"
  type        = bool
  default     = false
}

variable "efs_id" {
  description = "Existing EFS ID (required when create_efs = false)"
  type        = string
  default     = ""
}

# ─────────────────────────────────────────────────────────────────────────────
# GPU Node Name - 自动获取或手动指定
# ─────────────────────────────────────────────────────────────────────────────
variable "gpu_node_name" {
  description = "GPU node hostname. Leave empty to auto-detect from EKS GPU node group"
  type        = string
  default     = ""
}

# ─────────────────────────────────────────────────────────────────────────────
# Cluster Addons - 灵活控制安装
# ─────────────────────────────────────────────────────────────────────────────
variable "install_efs_csi_driver" {
  description = "Install AWS EFS CSI Driver"
  type        = bool
  default     = true
}

variable "create_efs_storage_class" {
  description = "Create EFS StorageClasses (set false if already exist in cluster)"
  type        = bool
  default     = true
}

variable "install_aws_lbc" {
  description = "Install AWS Load Balancer Controller"
  type        = bool
  default     = true
}

variable "install_nvidia_device_plugin" {
  description = "Install NVIDIA Device Plugin"
  type        = bool
  default     = true
}
