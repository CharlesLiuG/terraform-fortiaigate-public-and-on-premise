# ===========================================================================
# FortiAIGate 私有化环境部署配置（国内镜像源）
# 复制为 terraform.tfvars 并根据实际场景修改
# ===========================================================================

# ===========================================================================
# 部署场景选择（三选一，取消对应注释）
# ===========================================================================

# --- 场景 1: 全新环境 ---
# K8S集群 → NFS → Nginx Ingress → 验证 → FortiAIGate
deploy_k8s_cluster   = true
deploy_nfs           = true
deploy_nginx_ingress = true

# --- 场景 2: 客户有 K8S + 有 NFS 存储 ---
# Nginx Ingress → 验证 → FortiAIGate
# deploy_k8s_cluster   = false
# deploy_nfs           = false
# deploy_nginx_ingress = true
# existing_storage_class = "客户已有的StorageClass名称"

# --- 场景 3: 客户有 K8S + 无 NFS 存储 ---
# NFS → Nginx Ingress → 验证 → FortiAIGate
# deploy_k8s_cluster   = false
# deploy_nfs           = true
# deploy_nginx_ingress = true

# ===========================================================================
# Kubernetes 连接配置
# ===========================================================================
kubeconfig_path    = "~/.kube/config"
kubeconfig_context = ""

# 预期节点数（用于 preflight 验证，deploy_k8s_cluster=false 时设置）
expected_node_count = 2

# ===========================================================================
# K8S 集群配置（仅场景 1 需要）
# ===========================================================================
master_node = {
  host        = "161.189.43.245"
  user        = "ubuntu"
  hostname    = "k8s-master"
  internal_ip = "172.16.0.158"
}

# Worker 节点列表 - 默认 1 个，按需添加
worker_nodes = [
  {
    host        = "43.192.206.212"
    user        = "ubuntu"
    hostname    = "k8s-worker-1"
    labels      = ""
    internal_ip = "172.16.0.172"
  },
]

# SSH 认证（二选一）
ssh_private_key_path = "/home/ubuntu/.ssh/lg_key.pem"
# ssh_password    = "Fortinet@123.com"
ssh_port        = 22

# K8S 版本
k8s_version       = "1.35.6"
k8s_version_major = "v1.35"

# 网络
pod_network_cidr = "10.244.0.0/16"
service_cidr     = "10.96.0.0/12"

# ===========================================================================
# 国内镜像源配置
# ===========================================================================

# K8S 组件镜像（kubeadm）
k8s_image_repository = "registry.cn-hangzhou.aliyuncs.com/google_containers"
pause_image          = "registry.cn-hangzhou.aliyuncs.com/google_containers/pause:3.10"

# Calico CNI
calico_version      = "v3.28.0"
calico_image_mirror = "docker.m.daocloud.io"   # DaoCloud 公益加速，替换 docker.io
github_proxy        = "https://ghproxy.com/"   # GitHub 文件下载加速

# Nginx Ingress Controller
image_registry             = "registry.cn-hangzhou.aliyuncs.com"
nginx_controller_image     = "google_containers/nginx-ingress-controller"
nginx_controller_image_tag = "v1.12.1"

# NFS Provisioner
nfs_image_repository = "172.16.0.169:5000/lg-fortiaigate-registry/nfs-subdir-external-provisioner"
nfs_image_tag        = "v4.0.2"

# ===========================================================================
# NFS 配置（场景 1 和 场景 3 需要）
# Terraform 会自动在目标节点部署 NFS Server + NFS Provisioner
# ===========================================================================
nfs_server_host       = "172.16.0.158"          # NFS Server 部署在 master 节点（内网IP）
nfs_server_user       = "root"                    # 该节点的 SSH 用户
nfs_path              = "/data/nfs/fortiaigate"   # NFS 导出的共享目录
nfs_allowed_network   = "172.16.0.0/16"          # 允许挂载的网段
storage_class_name    = "nfs-client"
nfs_archive_on_delete = true

# 如果 deploy_k8s_cluster=false（场景3），需要手动指定 Worker 节点 IP 安装 nfs-common：
# nfs_client_hosts = ["192.168.1.11", "192.168.1.12"]

# ===========================================================================
# Nginx Ingress 配置
# ===========================================================================
nginx_replica_count   = 1
nginx_service_type    = "NodePort"
nginx_node_port_http  = 30080
nginx_node_port_https = 30443
nginx_host_network    = false

# ===========================================================================
# GPU 配置（NVIDIA Driver + CUDA + Device Plugin）
# 在 GPU Worker 节点上安装驱动并验证可用性
# ===========================================================================
deploy_gpu = true

# GPU Worker 节点列表（需要有 NVIDIA GPU 硬件的节点）
gpu_worker_nodes = [
  {
    host = "43.192.206.212"
    user = "ubuntu"
  },
]

# NVIDIA Driver 版本
nvidia_driver_version = "580"

# CUDA Toolkit 版本
cuda_version         = "13.0"
cuda_package_version = "13-0"    # APT 包名后缀: cuda-toolkit-13-0

# NVIDIA Container Toolkit 仓库（默认官方源，国内可替换）
nvidia_container_toolkit_mirror = "https://nvidia.github.io/libnvidia-container/stable/deb/amd64"

# NVIDIA K8s Device Plugin
nvidia_device_plugin_version = "v0.17.0"
nvidia_device_plugin_image   = "nvcr.io/nvidia/k8s-device-plugin"

# ===========================================================================
# 私有镜像仓库（HTTP insecure registry）
# ===========================================================================
private_registry = "172.16.0.158:5000"

# ===========================================================================
# FortiAIGate 应用部署（基础设施验证通过后开启）
# ===========================================================================
deploy_fortiaigate = false
