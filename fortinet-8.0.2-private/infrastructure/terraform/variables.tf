###############################################################################
# 变量定义
###############################################################################

# --- 通用配置 ---
variable "kubeconfig_path" {
  description = "Kubernetes kubeconfig 文件路径"
  type        = string
  default     = "~/.kube/config"
}

variable "kubeconfig_context" {
  description = "Kubernetes context 名称（留空使用当前 context）"
  type        = string
  default     = ""
}

# ============================================================
# 部署场景控制
# ============================================================
# 场景1（全新环境）:     deploy_k8s_cluster=true,  deploy_nfs=true,  deploy_nginx_ingress=true
# 场景2（有K8S+有NFS）:  deploy_k8s_cluster=false, deploy_nfs=false, deploy_nginx_ingress=true
# 场景3（有K8S+无NFS）:  deploy_k8s_cluster=false, deploy_nfs=true,  deploy_nginx_ingress=true

variable "deploy_k8s_cluster" {
  description = "是否部署 K8S 集群（全新环境设为 true）"
  type        = bool
  default     = true
}

variable "deploy_nfs" {
  description = "是否部署 NFS Provisioner（客户无 NFS 存储时设为 true）"
  type        = bool
  default     = true
}

variable "deploy_nginx_ingress" {
  description = "是否部署 Nginx Ingress Controller"
  type        = bool
  default     = true
}

# ============================================================
# K8S 集群部署配置（仅 deploy_k8s_cluster=true 时需要）
# ============================================================
variable "master_node" {
  description = "Master 节点配置"
  type = object({
    host        = string
    user        = string
    hostname    = string
    internal_ip = optional(string, "")
  })
  default = {
    host        = "192.168.1.10"
    user        = "root"
    hostname    = "k8s-master"
    internal_ip = ""
  }
}

variable "worker_nodes" {
  description = "Worker 节点列表，默认 1 个，可扩展为 N 个"
  type = list(object({
    host        = string
    user        = string
    hostname    = string
    labels      = optional(string, "")
    internal_ip = optional(string, "")
  }))
  default = [
    {
      host        = "192.168.1.11"
      user        = "root"
      hostname    = "k8s-worker-1"
      labels      = ""
      internal_ip = ""
    }
  ]
}

variable "ssh_private_key" {
  description = "SSH 私钥内容"
  type        = string
  default     = ""
  sensitive   = true
}

variable "ssh_private_key_path" {
  description = "SSH 私钥文件路径（填此项则自动读取内容，支持 ~ 展开，优先级高于 ssh_private_key）"
  type        = string
  default     = ""
  sensitive   = true
}

variable "ssh_password" {
  description = "SSH 密码（不推荐，建议使用密钥）"
  type        = string
  default     = ""
  sensitive   = true
}

variable "ssh_port" {
  description = "SSH 端口"
  type        = number
  default     = 22
}

variable "k8s_version" {
  description = "Kubernetes 版本"
  type        = string
  default     = "1.30.4"
}

variable "k8s_version_major" {
  description = "Kubernetes 主版本号（用于 APT 源，如 v1.30）"
  type        = string
  default     = "v1.30"
}

variable "pod_network_cidr" {
  description = "Pod 网络 CIDR"
  type        = string
  default     = "10.244.0.0/16"
}

variable "service_cidr" {
  description = "Service 网络 CIDR"
  type        = string
  default     = "10.96.0.0/12"
}

variable "k8s_image_repository" {
  description = "Kubernetes 组件镜像仓库（国内源）"
  type        = string
  default     = "registry.cn-hangzhou.aliyuncs.com/google_containers"
}

variable "pause_image" {
  description = "pause 容器镜像"
  type        = string
  default     = "registry.cn-hangzhou.aliyuncs.com/google_containers/pause:3.9"
}

variable "calico_version" {
  description = "Calico CNI 版本"
  type        = string
  default     = "v3.28.0"
}

variable "calico_image_mirror" {
  description = "Calico 镜像加速（国内替换 docker.io）"
  type        = string
  default     = "docker.m.daocloud.io"
}

variable "github_proxy" {
  description = "GitHub 文件下载代理（国内加速）"
  type        = string
  default     = "https://ghproxy.com/"
}

# ============================================================
# NFS 配置（场景1 和 场景3 需要）
# Terraform 会先在目标节点部署 NFS Server，再部署 NFS Provisioner
# ============================================================
variable "nfs_server_host" {
  description = "NFS Server 部署/连接的目标节点 IP"
  type        = string
  default     = ""
}

variable "nfs_server_user" {
  description = "NFS Server 节点 SSH 用户"
  type        = string
  default     = "root"
}

variable "nfs_allowed_network" {
  description = "允许挂载 NFS 的网段（CIDR）"
  type        = string
  default     = "192.168.1.0/24"
}

variable "nfs_client_hosts" {
  description = "NFS 客户端节点 IP 列表（deploy_k8s_cluster=false 时需手动指定 Worker IP）"
  type        = list(string)
  default     = []
}

variable "nfs_namespace" {
  description = "NFS Provisioner 部署的命名空间"
  type        = string
  default     = "nfs-provisioner"
}

variable "nfs_path" {
  description = "NFS 导出/共享路径"
  type        = string
  default     = "/data/nfs/fortiaigate"
}

variable "storage_class_name" {
  description = "创建的 StorageClass 名称"
  type        = string
  default     = "nfs-client"
}

variable "nfs_archive_on_delete" {
  description = "PVC 删除时是否归档数据（而非直接删除）"
  type        = bool
  default     = true
}

variable "nfs_image_repository" {
  description = "NFS Provisioner 镜像（国内源）"
  type        = string
  default     = "registry.cn-hangzhou.aliyuncs.com/kubernetes-china/nfs-subdir-external-provisioner"
}

variable "nfs_image_tag" {
  description = "NFS Provisioner 镜像 Tag"
  type        = string
  default     = "v4.0.2"
}

# ============================================================
# Nginx Ingress 配置
# ============================================================
variable "nginx_namespace" {
  description = "Nginx Ingress Controller 部署的命名空间"
  type        = string
  default     = "ingress-nginx"
}

variable "nginx_replica_count" {
  description = "Nginx Ingress Controller 副本数"
  type        = number
  default     = 2
}

variable "nginx_service_type" {
  description = "Nginx Ingress Service 类型"
  type        = string
  default     = "NodePort"

  validation {
    condition     = contains(["NodePort", "LoadBalancer", "ClusterIP"], var.nginx_service_type)
    error_message = "service_type 必须是 NodePort、LoadBalancer 或 ClusterIP 之一"
  }
}

variable "nginx_node_port_http" {
  description = "HTTP NodePort 端口号"
  type        = number
  default     = 30080
}

variable "nginx_node_port_https" {
  description = "HTTPS NodePort 端口号"
  type        = number
  default     = 30443
}

variable "nginx_host_network" {
  description = "是否使用主机网络模式"
  type        = bool
  default     = false
}

# ============================================================
# 国内镜像源配置
# ============================================================
variable "image_registry" {
  description = "国内镜像仓库地址"
  type        = string
  default     = "registry.cn-hangzhou.aliyuncs.com"
}

variable "nginx_controller_image" {
  description = "Nginx Ingress Controller 镜像路径"
  type        = string
  default     = "google_containers/nginx-ingress-controller"
}

variable "nginx_controller_image_tag" {
  description = "Nginx Ingress Controller 版本"
  type        = string
  default     = "v1.12.1"
}

# ============================================================
# 验证配置（preflight-check）
# ============================================================
variable "existing_storage_class" {
  description = "客户已有的 StorageClass 名称（deploy_nfs=false 时使用）"
  type        = string
  default     = "nfs-client"
}

variable "expected_node_count" {
  description = "预期集群节点总数（deploy_k8s_cluster=false 时用于验证）"
  type        = number
  default     = 2
}

# ============================================================
# GPU 配置（NVIDIA Driver + CUDA + Device Plugin）
# ============================================================
variable "deploy_gpu" {
  description = "是否部署 GPU 环境（NVIDIA Driver + CUDA + Device Plugin）"
  type        = bool
  default     = true
}

variable "gpu_worker_nodes" {
  description = "需要安装 GPU 驱动的 Worker 节点列表"
  type = list(object({
    host = string
    user = string
  }))
  default = [
    {
      host = "192.168.1.11"
      user = "root"
    }
  ]
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
  description = "CUDA Toolkit APT 包版本（如 13-0，对应 cuda-toolkit-13-0）"
  type        = string
  default     = "13-0"
}

variable "nvidia_container_toolkit_mirror" {
  description = "NVIDIA Container Toolkit APT 仓库地址"
  type        = string
  default     = "https://nvidia.github.io/libnvidia-container/stable/deb/amd64"
}

variable "nvidia_device_plugin_version" {
  description = "NVIDIA K8s Device Plugin 版本"
  type        = string
  default     = "v0.17.0"
}

variable "nvidia_device_plugin_image" {
  description = "NVIDIA Device Plugin 镜像地址（支持替换为国内镜像）"
  type        = string
  default     = "nvcr.io/nvidia/k8s-device-plugin"
}

variable "private_registry" {
  description = "私有镜像仓库地址（如 172.16.0.169:5000），用于配置 containerd insecure registry"
  type        = string
  default     = ""
}
