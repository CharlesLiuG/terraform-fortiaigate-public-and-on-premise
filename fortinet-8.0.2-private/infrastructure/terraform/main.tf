###############################################################################
# FortiAIGate Infrastructure - 私有化 Kubernetes 环境部署（国内镜像源）
#
# 支持 3 种部署场景：
#   场景1: 全新环境      → deploy_k8s_cluster=true,  deploy_nfs=true,  deploy_nginx_ingress=true
#   场景2: 有K8S+有NFS   → deploy_k8s_cluster=false, deploy_nfs=false, deploy_nginx_ingress=true
#   场景3: 有K8S+无NFS   → deploy_k8s_cluster=false, deploy_nfs=true,  deploy_nginx_ingress=true
#
# 部署顺序: K8S集群 → NFS存储 → Nginx Ingress → GPU环境 → 验证 → FortiAIGate(手动)
###############################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.0"
    }
  }
}

# ---------------------------------------------------------------------------
# SSH 私钥解析：优先用 ssh_private_key_path（读取文件内容），否则用 ssh_private_key
# 这样 tfvars 里只需填 ssh_private_key_path = "/home/ubuntu/.ssh/lg_key.pem"
# ---------------------------------------------------------------------------
locals {
  ssh_private_key_resolved = (
    var.ssh_private_key_path != "" ? file(pathexpand(var.ssh_private_key_path)) : var.ssh_private_key
  )
}

# ------------------------------------------------------------
# kubeconfig 容错处理
#
# 全新环境（deploy_k8s_cluster=true）第一次执行时，~/.kube/config
# 尚未生成（它由 module.k8s_cluster 的 fetch_kubeconfig 在 apply
# 过程中才拉取）。若此时 provider 直接指向不存在的路径，plan/apply
# 会报错：
#   "config_path refers to an invalid path ...: no such file or directory"
#
# Terraform 的 provider 无法依赖同一次 apply 中才生成的资源，因此
# 正确的做法是分两阶段部署（见 deploy.sh）：
#   阶段1: terraform apply -target=module.k8s_cluster  → 生成 kubeconfig
#   阶段2: terraform apply                              → 部署集群内资源
#
# 这里用 fileexists() 判断 kubeconfig 是否已存在：
#   - 存在 → 正常指向该文件
#   - 不存在 → 传 null，避免 provider 因路径不存在而在 plan 阶段崩溃
#     （此时集群内资源应通过 -target 阶段跳过，不会真正使用该 provider）
# ------------------------------------------------------------
locals {
  kubeconfig_abs_path = pathexpand(var.kubeconfig_path)
  kubeconfig_exists   = fileexists(local.kubeconfig_abs_path)
  kubeconfig_context  = var.kubeconfig_context != "" ? var.kubeconfig_context : null
}

provider "kubernetes" {
  config_path    = local.kubeconfig_exists ? local.kubeconfig_abs_path : null
  config_context = local.kubeconfig_context
}

provider "helm" {
  kubernetes {
    config_path    = local.kubeconfig_exists ? local.kubeconfig_abs_path : null
    config_context = local.kubeconfig_context
  }
}

# ============================================================
# 阶段 1: 部署 K8S 集群（1 Master + N Worker）
# 仅场景1（全新环境）启用
# ============================================================
module "k8s_cluster" {
  source = "./modules/k8s-cluster"
  count  = var.deploy_k8s_cluster ? 1 : 0

  master_node          = var.master_node
  worker_nodes         = var.worker_nodes
  ssh_private_key      = var.ssh_private_key
  ssh_password         = var.ssh_password
  ssh_port             = var.ssh_port
  k8s_version          = var.k8s_version
  k8s_version_major    = var.k8s_version_major
  pod_network_cidr     = var.pod_network_cidr
  service_cidr         = var.service_cidr
  k8s_image_repository = var.k8s_image_repository
  pause_image          = var.pause_image
  calico_version       = var.calico_version
  calico_image_mirror  = var.calico_image_mirror
  github_proxy         = var.github_proxy
  private_registry     = var.private_registry
}

# ============================================================
# 阶段 2: 部署 NFS Server + NFS Provisioner
# 场景1 和 场景3 启用
# ============================================================

# 2a. 先部署 NFS Server（在指定节点上安装 nfs-kernel-server）
module "nfs_server" {
  source = "./modules/nfs-server"
  count  = var.deploy_nfs ? 1 : 0

  nfs_server_host         = var.master_node.host
  nfs_server_user         = var.nfs_server_user
  nfs_server_internal_ip  = var.nfs_server_host
  nfs_export_path         = var.nfs_path
  allowed_network  = var.nfs_allowed_network
  nfs_client_hosts = var.deploy_k8s_cluster ? [for w in var.worker_nodes : w.host] : var.nfs_client_hosts
  nfs_client_user  = var.deploy_k8s_cluster ? var.master_node.user : var.nfs_server_user
  ssh_private_key  = var.ssh_private_key
  ssh_password     = var.ssh_password
  ssh_port         = var.ssh_port

  depends_on = [module.k8s_cluster]
}

# 2b. 再部署 NFS Provisioner（连接 NFS Server，创建 StorageClass）
module "nfs_provisioner" {
  source = "./modules/nfs-provisioner"
  count  = var.deploy_nfs ? 1 : 0

  namespace          = var.nfs_namespace
  nfs_server         = var.nfs_server_host
  nfs_path           = var.nfs_path
  storage_class_name = var.storage_class_name
  archive_on_delete  = var.nfs_archive_on_delete
  image_repository   = var.nfs_image_repository
  image_tag          = var.nfs_image_tag

  depends_on = [module.nfs_server]
}

# ============================================================
# 阶段 3: 部署 Nginx Ingress Controller
# 所有场景均启用
# ============================================================
module "nginx_ingress" {
  source = "./modules/nginx-ingress"
  count  = var.deploy_nginx_ingress ? 1 : 0

  namespace            = var.nginx_namespace
  replica_count        = var.nginx_replica_count
  service_type         = var.nginx_service_type
  node_port_http       = var.nginx_node_port_http
  node_port_https      = var.nginx_node_port_https
  host_network         = var.nginx_host_network
  image_registry       = var.image_registry
  controller_image     = var.nginx_controller_image
  controller_image_tag = var.nginx_controller_image_tag

  depends_on = [module.k8s_cluster, module.nfs_server, module.nfs_provisioner]
}

# ============================================================
# 阶段 4: GPU 环境部署
# 在 GPU Worker 节点安装 NVIDIA Driver + CUDA + Container Toolkit
# + Device Plugin，并验证 GPU 可用性
# ============================================================
module "gpu_setup" {
  source = "./modules/gpu-setup"
  count  = var.deploy_gpu ? 1 : 0

  gpu_worker_nodes = var.gpu_worker_nodes
  ssh_private_key  = var.ssh_private_key
  ssh_password     = var.ssh_password
  ssh_port         = var.ssh_port

  nvidia_driver_version           = var.nvidia_driver_version
  cuda_version                    = var.cuda_version
  cuda_package_version            = var.cuda_package_version
  nvidia_container_toolkit_mirror = var.nvidia_container_toolkit_mirror
  nvidia_device_plugin_version    = var.nvidia_device_plugin_version
  nvidia_device_plugin_image      = var.nvidia_device_plugin_image
  cuda_test_image                 = "${var.private_registry}/lg-fortiaigate-registry/cuda"

  kubeconfig_path    = local.kubeconfig_abs_path
  kubeconfig_context = var.kubeconfig_context

  depends_on = [module.k8s_cluster, module.nginx_ingress, module.nfs_provisioner]
}

# ============================================================
# 阶段 5: 部署前验证
# 验证基础设施满足 FortiAIGate 部署需求
# ============================================================
module "preflight_check" {
  source = "./modules/preflight-check"

  kubeconfig_path    = local.kubeconfig_abs_path
  kubeconfig_context = var.kubeconfig_context
  storage_class_name = var.deploy_nfs ? var.storage_class_name : var.existing_storage_class
  ingress_class_name = "nginx"
  expected_nodes     = var.deploy_k8s_cluster ? (1 + length(var.worker_nodes)) : var.expected_node_count
  check_gpu          = var.deploy_gpu
  gpu_driver_version = var.nvidia_driver_version
  cuda_version       = var.cuda_version

  depends_on = [module.nginx_ingress, module.nfs_provisioner, module.gpu_setup]
}

# ============================================================
# 阶段 6: 部署 FortiAIGate 应用
# 基础设施验证通过后部署，通过 deploy_fortiaigate 开关控制
# ============================================================
variable "deploy_fortiaigate" {
  description = "是否部署 FortiAIGate 应用（建议先完成基础设施部署验证后再开启）"
  type        = bool
  default     = false
}

variable "fortiaigate_values_file" {
  description = "FortiAIGate Helm values 文件路径"
  type        = string
  default     = "../../fortiaigate/values-private.yaml"
}

variable "fortiaigate_chart_path" {
  description = "FortiAIGate Helm chart 路径"
  type        = string
  default     = "../../fortiaigate"
}

variable "fortiaigate_namespace" {
  description = "FortiAIGate 部署的命名空间"
  type        = string
  default     = "fortiaigate"
}

resource "kubernetes_namespace" "fortiaigate" {
  count = var.deploy_fortiaigate ? 1 : 0

  metadata {
    name = var.fortiaigate_namespace
  }

  depends_on = [module.preflight_check]
}

resource "helm_release" "fortiaigate" {
  count = var.deploy_fortiaigate ? 1 : 0

  name      = "fortiaigate"
  namespace = kubernetes_namespace.fortiaigate[0].metadata[0].name
  chart     = var.fortiaigate_chart_path

  values = [
    file(var.fortiaigate_values_file)
  ]

  set {
    name  = "ingress.nodePort"
    value = var.nginx_service_type == "NodePort" ? tostring(var.nginx_node_port_https) : ""
  }

  timeout = 600

  depends_on = [module.preflight_check]
}
