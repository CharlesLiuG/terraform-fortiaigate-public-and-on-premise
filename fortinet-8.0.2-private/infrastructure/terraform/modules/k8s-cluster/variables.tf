###############################################################################
# K8S 集群模块变量
###############################################################################

# --- 节点定义 ---
variable "master_node" {
  description = "Master 节点配置"
  type = object({
    host        = string
    user        = string
    hostname    = string
    internal_ip = optional(string, "")
  })
}

variable "worker_nodes" {
  description = "Worker 节点列表（支持 N 个），默认 1 个"
  type = list(object({
    host        = string
    user        = string
    hostname    = string
    labels      = optional(string, "")
    internal_ip = optional(string, "")
  }))

  validation {
    condition     = length(var.worker_nodes) >= 1
    error_message = "至少需要 1 个 Worker 节点"
  }
}

# --- SSH 连接 ---
variable "ssh_private_key" {
  description = "SSH 私钥内容（与 ssh_password 二选一）"
  type        = string
  default     = ""
  sensitive   = true
}

variable "ssh_password" {
  description = "SSH 密码（与 ssh_private_key 二选一）"
  type        = string
  default     = ""
  sensitive   = true
}

variable "ssh_port" {
  description = "SSH 端口"
  type        = number
  default     = 22
}

# --- Kubernetes 版本 ---
variable "k8s_version" {
  description = "Kubernetes 完整版本号"
  type        = string
  default     = "1.30.4"
}

variable "k8s_version_major" {
  description = "Kubernetes 主版本号（用于 APT 源路径，如 v1.30）"
  type        = string
  default     = "v1.30"
}

# --- 网络配置 ---
variable "pod_network_cidr" {
  description = "Pod 网络 CIDR（Calico 默认）"
  type        = string
  default     = "10.244.0.0/16"
}

variable "service_cidr" {
  description = "Service 网络 CIDR"
  type        = string
  default     = "10.96.0.0/12"
}

# --- 国内镜像源 ---
variable "k8s_image_repository" {
  description = "Kubernetes 组件镜像仓库（国内源）"
  type        = string
  default     = "registry.cn-hangzhou.aliyuncs.com/google_containers"
}

variable "pause_image" {
  description = "pause 容器镜像地址"
  type        = string
  default     = "registry.cn-hangzhou.aliyuncs.com/google_containers/pause:3.9"
}

variable "calico_version" {
  description = "Calico 版本号"
  type        = string
  default     = "v3.28.0"
}

variable "calico_image_mirror" {
  description = "Calico 容器镜像加速地址（替换 docker.io，国内可用）"
  type        = string
  default     = "docker.m.daocloud.io"
}

variable "github_proxy" {
  description = "GitHub 文件下载代理（国内加速下载 calico.yaml）"
  type        = string
  default     = "https://ghproxy.com/"
}

variable "kubeadm_extra_args" {
  description = "kubeadm init 额外参数"
  type        = string
  default     = ""
}

variable "private_registry" {
  description = "私有镜像仓库地址（如 172.16.0.169:5000），用于配置 containerd insecure registry"
  type        = string
  default     = ""
}
