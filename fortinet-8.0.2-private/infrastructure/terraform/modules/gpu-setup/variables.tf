###############################################################################
# GPU Setup 模块变量
# 在 GPU Worker 节点上安装 NVIDIA Driver + CUDA Toolkit + Container Toolkit
###############################################################################

variable "gpu_worker_nodes" {
  description = "需要安装 GPU 驱动的 Worker 节点列表"
  type = list(object({
    host = string
    user = string
  }))
}

variable "ssh_private_key" {
  description = "SSH 私钥内容"
  type        = string
  default     = ""
  sensitive   = true
}

variable "ssh_password" {
  description = "SSH 密码"
  type        = string
  default     = ""
  sensitive   = true
}

variable "ssh_port" {
  description = "SSH 端口"
  type        = number
  default     = 22
}

variable "nvidia_driver_version" {
  description = "NVIDIA GPU 驱动版本"
  type        = string
  default     = "580"
}

variable "cuda_version" {
  description = "CUDA Toolkit 版本"
  type        = string
  default     = "13.0"
}

variable "cuda_package_version" {
  description = "CUDA Toolkit APT 包版本（如 13-0）"
  type        = string
  default     = "13-0"
}

variable "nvidia_container_toolkit_mirror" {
  description = "NVIDIA Container Toolkit 仓库地址（可替换为国内镜像）"
  type        = string
  default     = "https://nvidia.github.io/libnvidia-container/stable/deb/amd64"
}

variable "nvidia_device_plugin_version" {
  description = "NVIDIA K8s Device Plugin 版本"
  type        = string
  default     = "v0.17.0"
}

variable "nvidia_device_plugin_image" {
  description = "NVIDIA Device Plugin 镜像地址（支持国内镜像）"
  type        = string
  default     = "nvcr.io/nvidia/k8s-device-plugin"
}

variable "kubeconfig_path" {
  description = "Kubernetes kubeconfig 文件路径"
  type        = string
  default     = "~/.kube/config"
}

variable "kubeconfig_context" {
  description = "Kubernetes context 名称"
  type        = string
  default     = ""
}

variable "cuda_test_image" {
  description = "CUDA 测试镜像地址（用于 GPU 验证）"
  type        = string
  default     = "nvcr.io/nvidia/cuda"
}
