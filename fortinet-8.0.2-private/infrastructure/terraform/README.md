# FortiAIGate 基础设施 - Terraform 私有化部署

通过 Terraform 一键部署 FortiAIGate 所需的完整私有化 Kubernetes 环境，所有镜像使用国内开源镜像源。

## 部署场景

支持 3 种客户环境场景，通过变量开关控制：

| 场景 | 客户环境 | 部署内容 | 变量设置 |
|------|----------|----------|----------|
| 场景1 | 全新环境 | K8S → NFS → Nginx Ingress → 验证 | `deploy_k8s_cluster=true, deploy_nfs=true, deploy_nginx_ingress=true` |
| 场景2 | 有K8S + 有NFS | Nginx Ingress → 验证 | `deploy_k8s_cluster=false, deploy_nfs=false, deploy_nginx_ingress=true` |
| 场景3 | 有K8S + 无NFS | NFS → Nginx Ingress → 验证 | `deploy_k8s_cluster=false, deploy_nfs=true, deploy_nginx_ingress=true` |

## 部署依赖顺序

### 场景1: 全新环境

```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌────────────────┐    ┌─────────────┐    ┌─────────────┐
│ K8S 集群 │ →  │   NFS    │ →  │   NFS    │ →  │ Nginx Ingress  │ →  │ Preflight   │ →  │ FortiAIGate │
│ (kubeadm)│    │  Server  │    │Provisioner│    │  Controller    │    │   验证      │    │  (手动Helm) │
└──────────┘    └──────────┘    └──────────┘    └────────────────┘    └─────────────┘    └─────────────┘
```

1. 部署 K8S 集群（1 Master + N Worker）
2. 部署 NFS Server（在指定节点安装 nfs-kernel-server 并配置导出）
3. 部署 NFS Provisioner（连接 NFS Server，创建 StorageClass）
4. 部署 Nginx Ingress Controller
5. 自动执行 Preflight 验证
6. 验证通过后，手动部署 FortiAIGate

### 场景2: 客户有 K8S + 有 NFS 存储

```
┌────────────────┐    ┌─────────────┐    ┌─────────────┐
│ Nginx Ingress  │ →  │ Preflight   │ →  │ FortiAIGate │
│  Controller    │    │   验证      │    │  (手动Helm) │
└────────────────┘    └─────────────┘    └─────────────┘
```

1. 部署 Nginx Ingress Controller
2. 自动执行 Preflight 验证（使用客户已有的 StorageClass）
3. 验证通过后，手动部署 FortiAIGate

### 场景3: 客户有 K8S + 无 NFS 存储

```
┌──────────┐    ┌──────────┐    ┌────────────────┐    ┌─────────────┐    ┌─────────────┐
│   NFS    │ →  │   NFS    │ →  │ Nginx Ingress  │ →  │ Preflight   │ →  │ FortiAIGate │
│  Server  │    │Provisioner│    │  Controller    │    │   验证      │    │  (手动Helm) │
└──────────┘    └──────────┘    └────────────────┘    └─────────────┘    └─────────────┘
```

1. 部署 NFS Server（在指定节点安装 nfs-kernel-server 并配置导出）
2. 部署 NFS Provisioner（连接 NFS Server，创建 StorageClass）
3. 部署 Nginx Ingress Controller
4. 自动执行 Preflight 验证
5. 验证通过后，手动部署 FortiAIGate

## Preflight 验证内容

每次 `terraform apply` 完成后自动执行以下检查：

| 检查项 | 说明 |
|--------|------|
| 节点数量 | 集群节点数 >= 预期值 |
| 节点状态 | 所有节点 Ready |
| StorageClass | 指定的 StorageClass 存在 |
| 存储可用性 | 创建测试 PVC，验证 ReadWriteMany 可绑定 |
| Ingress Controller | Nginx Ingress Pod 处于 Running 状态 |
| IngressClass | `nginx` IngressClass 已注册 |

所有检查通过后输出部署 FortiAIGate 的命令；任何检查失败则 Terraform 报错退出。

## 模块说明

```
infrastructure/terraform/
├── main.tf                              # 主入口，编排部署顺序
├── variables.tf                         # 全局变量（场景控制、节点、镜像源）
├── outputs.tf                           # 输出（集群IP、StorageClass、端口）
├── terraform.tfvars.example             # 配置示例（3种场景）
├── README.md
└── modules/
    ├── k8s-cluster/                     # K8S 集群 (kubeadm, 1 Master + N Worker)
    ├── nfs-server/                      # NFS Server (安装 nfs-kernel-server)
    ├── nfs-provisioner/                 # NFS Provisioner (StorageClass)
    ├── nginx-ingress/                   # Nginx Ingress Controller
    └── preflight-check/                 # 部署前验证
```

| 模块 | 功能 | 镜像源 |
|------|------|--------|
| `k8s-cluster` | kubeadm 部署 K8S (1 Master + N Worker) | 阿里云 `google_containers` |
| `nfs-server` | 安装配置 NFS Server (nfs-kernel-server) | 系统 APT 包 |
| `nfs-provisioner` | NFS Subdir External Provisioner | 阿里云 `kubernetes-china` |
| `nginx-ingress` | Nginx Ingress Controller | 阿里云 `google_containers` |
| `preflight-check` | 验证基础设施就绪 | 无镜像依赖 |

## 前置条件

1. 准备好服务器（Ubuntu 20.04/22.04），节点间网络互通
2. 指定一台节点作为 NFS Server（可以是独立机器或 Master 节点）— 场景1/3
3. 本机已安装 Terraform >= 1.5
4. Master 到各 Worker 的 SSH 免密或密码认证（场景1）

## 快速开始

> 💡 **推荐使用 `deploy.sh` 一键部署**。它会自动处理"全新环境"下 kubeconfig
> 尚未生成导致 provider 无法连接集群的问题（详见下方
> [部署方式与两阶段部署](#部署方式与两阶段部署)）。

```bash
cd infrastructure/terraform

# 1. 配置 Terraform 国内镜像（解决 terraform init 下载 Provider 超时）
cp .terraformrc ~/.terraformrc

# 2. 配置变量
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars   # 根据场景修改

# 3. 一键部署（自动 init + 按需分两阶段 apply + 自动验证）
./deploy.sh              # 交互式，每阶段前需确认
# ./deploy.sh -auto      # 自动批准，无需人工确认
# ./deploy.sh -plan      # 仅预览计划，不实际部署

# 4. 验证通过后，部署 FortiAIGate
cd ~/fortinet-8.0.1-private
helm install fortiaigate ./fortiaigate \
  -f fortiaigate/values-private.yaml \
  -n fortiaigate --create-namespace
```

## 部署方式与两阶段部署

### 为什么全新环境不能一次 `terraform apply`

`kubernetes` 与 `helm` provider 在 `terraform plan/apply` **一开始**就要读取
`~/.kube/config` 来连接集群。但在**全新环境（`deploy_k8s_cluster=true`）** 下，
这个文件要等 K8S 集群搭建完成、由 `module.k8s_cluster` 的 `fetch_kubeconfig`
在 apply 过程中拉取后才存在。

于是第一次执行会报错：

```
Invalid attribute in provider configuration
provider "kubernetes" refers to an invalid path: "/root/.kube/config":
stat /root/.kube/config: no such file or directory

Error: Get "http://localhost/api/v1/namespaces/nfs-provisioner":
dial tcp 127.0.0.1:80: connect: connection refused
```

这是 Terraform 的固有限制：**provider 无法依赖同一次 apply 中才生成的资源**。
因此全新环境必须分两阶段执行：

```bash
# 阶段1：先搭建 K8S 集群，生成 ~/.kube/config
terraform apply -target=module.k8s_cluster

# 确认 kubeconfig 已生成、集群可连接
ls -l ~/.kube/config
kubectl get nodes

# 阶段2：kubeconfig 就绪后，部署集群内资源（NFS / Ingress / GPU / 验证）
terraform apply
```

### 用 deploy.sh 自动处理

`deploy.sh` 会自动判断：

- `deploy_k8s_cluster=true` 且 kubeconfig 不存在 → **自动执行上述两阶段**
- 连接已有集群 / kubeconfig 已存在 → **直接单阶段 apply**

```bash
./deploy.sh          # 交互式部署
./deploy.sh -auto    # 自动批准（-auto-approve）
./deploy.sh -plan    # 仅预览计划
```

> 说明：`main.tf` 中的 provider 已加入 `fileexists()` 容错，kubeconfig 不存在时
> 传入 `null` 而非无效路径，避免 `plan` 阶段直接崩溃；真正的连接仍由两阶段流程保证。


## 场景配置示例

### 场景1: 全新环境

```hcl
deploy_k8s_cluster   = true
deploy_nfs           = true
deploy_nginx_ingress = true

master_node = {
  host     = "192.168.1.10"
  user     = "root"
  hostname = "k8s-master"
}

worker_nodes = [
  {
    host     = "192.168.1.11"
    user     = "root"
    hostname = "k8s-worker-1"
    labels   = ""
  },
]

# NFS Server 部署在哪台机器上（可以是 Master、Worker 或独立节点）
nfs_server_host     = "192.168.1.10"
nfs_path            = "/data/nfs/fortiaigate"
nfs_allowed_network = "192.168.1.0/24"
```

### 场景2: 有K8S + 有NFS

```hcl
deploy_k8s_cluster     = false
deploy_nfs             = false
deploy_nginx_ingress   = true
existing_storage_class = "customer-nfs-sc"   # 客户已有的 StorageClass
expected_node_count    = 3                    # 客户集群节点数
```

### 场景3: 有K8S + 无NFS

```hcl
deploy_k8s_cluster   = false
deploy_nfs           = true
deploy_nginx_ingress = true
expected_node_count  = 3

# NFS Server 将部署在此节点上
nfs_server_host     = "192.168.1.100"
nfs_path            = "/data/nfs/fortiaigate"
nfs_allowed_network = "192.168.1.0/24"
# 指定 K8S Worker 节点安装 nfs-common 客户端
nfs_client_hosts    = ["192.168.1.11", "192.168.1.12"]
```

## Worker 节点扩展

默认 1 Master + 1 Worker，通过 `worker_nodes` 列表扩展到 N 个：

```hcl
worker_nodes = [
  { host = "192.168.1.11", user = "root", hostname = "k8s-worker-1", labels = "" },
  { host = "192.168.1.12", user = "root", hostname = "k8s-worker-2", labels = "" },
  { host = "192.168.1.13", user = "root", hostname = "k8s-worker-3", labels = "gpu=true" },
]
```

执行 `terraform apply` 即可自动将新节点加入集群。

## 国内镜像源

所有组件默认使用国内开源镜像源，无需翻墙：

| 组件 | 镜像源 | 说明 |
|------|--------|------|
| K8S 组件 (apiserver/etcd等) | `registry.cn-hangzhou.aliyuncs.com/google_containers` | 阿里云 |
| containerd 安装 | `mirrors.aliyun.com/docker-ce` | 阿里云 APT |
| kubeadm/kubelet/kubectl | `mirrors.aliyun.com/kubernetes-new` | 阿里云 APT |
| pause 容器 | `registry.cn-hangzhou.aliyuncs.com/google_containers/pause:3.9` | 阿里云 |
| Calico CNI 容器镜像 | `docker.m.daocloud.io` | DaoCloud 公益加速（替换 docker.io） |
| Calico manifest 下载 | `ghproxy.com` | GitHub 文件下载加速 |
| NFS Provisioner | `registry.cn-hangzhou.aliyuncs.com/kubernetes-china` | 阿里云 |
| Nginx Ingress Controller | `registry.cn-hangzhou.aliyuncs.com/google_containers` | 阿里云 |

如需替换为其他国内源，修改 `terraform.tfvars` 中对应变量即可：
- 中科大: `docker.mirrors.ustc.edu.cn`
- 华为云: `swr.cn-north-4.myhuaweicloud.com`
- 腾讯云: `mirror.ccs.tencentyun.com`

### Terraform Provider 镜像

`terraform init` 需要从 `registry.terraform.io` 下载 Provider 插件（hashicorp/kubernetes、hashicorp/helm、hashicorp/null），该地址在国内直连会超时。

项目已提供 `.terraformrc` 配置文件，使用腾讯云 Terraform 镜像加速。使用前需复制到用户 home 目录：

```bash
cp infrastructure/terraform/.terraformrc ~/.terraformrc
```

配置内容：
```hcl
provider_installation {
  network_mirror {
    url = "https://mirrors.tencent.com/terraform/"
  }
}
```

如腾讯云镜像不可用，可替换为阿里云：
```hcl
provider_installation {
  network_mirror {
    url = "https://mirrors.aliyun.com/terraform/"
  }
}
```

> ⚠️ 如不配置此文件，`terraform init` 在国内环境大概率会超时失败。

## 网络模式选择

### NodePort 模式（默认）

适合有外部负载均衡器或直接通过节点 IP 访问：

```hcl
nginx_service_type    = "NodePort"
nginx_node_port_https = 30443
```

访问地址：`https://<任意节点IP>:30443`

### HostNetwork 模式

直接绑定宿主机 80/443 端口：

```hcl
nginx_host_network = true
nginx_service_type = "ClusterIP"
```

访问地址：`https://<运行Ingress的节点IP>`

### LoadBalancer 模式

适合有 MetalLB 等 LB 实现的环境：

```hcl
nginx_service_type = "LoadBalancer"
```

## 部署后配置 FortiAIGate

Terraform 部署完成后，更新 `fortiaigate/values-private.yaml`：

```yaml
# 使用 Terraform 创建的 StorageClass
storage:
  storageClass: "nfs-client"   # 对应 terraform output storage_class_name

# Ingress（已默认配置 nginx）
ingress:
  className: "nginx"
```

## 清理

```bash
# 清理 Terraform 管理的基础设施
terraform destroy

# 如需完全重置 K8S 集群（在各节点执行）:
# sudo kubeadm reset -f
# sudo rm -rf /etc/cni /opt/cni /var/lib/kubelet /etc/kubernetes
```
