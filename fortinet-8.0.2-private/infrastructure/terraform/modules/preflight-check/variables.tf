variable "kubeconfig_path" {
  description = "kubeconfig 路径"
  type        = string
  default     = "~/.kube/config"
}

variable "kubeconfig_context" {
  description = "kubeconfig context"
  type        = string
  default     = ""
}

variable "storage_class_name" {
  description = "需要验证的 StorageClass 名称"
  type        = string
}

variable "ingress_class_name" {
  description = "需要验证的 IngressClass 名称"
  type        = string
  default     = "nginx"
}

variable "expected_nodes" {
  description = "预期的集群节点数量"
  type        = number
  default     = 2
}

variable "check_gpu" {
  description = "是否检查 GPU 环境"
  type        = bool
  default     = false
}

variable "gpu_driver_version" {
  description = "期望的 NVIDIA Driver 版本"
  type        = string
  default     = "580"
}

variable "cuda_version" {
  description = "期望的 CUDA 版本"
  type        = string
  default     = "13.0"
}
