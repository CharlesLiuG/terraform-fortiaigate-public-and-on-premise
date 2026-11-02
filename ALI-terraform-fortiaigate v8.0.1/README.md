# FortiAIGate - 阿里云部署 (Terraform)

基于阿里云 ACK (容器服务 Kubernetes) + NAS (文件存储) + ALB (应用负载均衡) 部署 FortiAIGate。

## 架构对应关系 (AWS → 阿里云)

| 功能 | AWS | 阿里云 |
|------|-----|--------|
| K8S 集群 | EKS | ACK Managed |
| 共享存储 | EFS | NAS |
| 负载均衡 | ALB (AWS LBC) | ALB (ALB Ingress Controller) |
| SSL 证书 | ACM | 数字证书管理服务 |
| GPU 实例 | g5.4xlarge | ecs.gn7i-c16g1.4xlarge |
| 区域 | us-east-1 | cn-wulanchabu |

## 前置条件

- Terraform >= 1.5
- 阿里云 CLI (`aliyun`) 已配置认证
- `kubectl` + `helm` 已安装
- SSL 证书（CertIdentifier 格式：`数字ID-cn-hangzhou`）
- License 文件 (`.lic`) 放入 `charts/files/licenses/`
- ECR 镜像仓库可达（或镜像同步到 ACR）

### 所需 RAM 权限

```
AliyunCSFullAccess
AliyunECSFullAccess
AliyunVPCFullAccess
AliyunNASFullAccess
AliyunALBFullAccess
AliyunYundunCertReadOnlyAccess
```

### 首次使用需 RAM 角色授权

浏览器访问以下链接，完成 ACK 服务角色授权（只需一次）：

https://ram.console.aliyun.com/role/authorize?request=%7B%22ReturnUrl%22%3A%22https%3A%2F%2Fcs.console.aliyun.com%2F%22%2C%22Services%22%3A%5B%7B%22Roles%22%3A%5B%7B%22RoleName%22%3A%22AliyunCSManagedCsiPluginRole%22%2C%22TemplateId%22%3A%22AliyunCSManagedCsiPluginRole%22%7D%2C%7B%22RoleName%22%3A%22AliyunCSManagedLogRole%22%2C%22TemplateId%22%3A%22AliyunCSManagedLogRole%22%7D%2C%7B%22RoleName%22%3A%22AliyunCSManagedCmsRole%22%2C%22TemplateId%22%3A%22AliyunCSManagedCmsRole%22%7D%2C%7B%22RoleName%22%3A%22AliyunCSManagedCsiRole%22%2C%22TemplateId%22%3A%22AliyunCSManagedCsiRole%22%7D%2C%7B%22RoleName%22%3A%22AliyunCSManagedCsiProvisionerRole%22%2C%22TemplateId%22%3A%22AliyunCSManagedCsiProvisionerRole%22%7D%2C%7B%22RoleName%22%3A%22AliyunCSManagedNetworkRole%22%2C%22TemplateId%22%3A%22AliyunCSManagedNetworkRole%22%7D%2C%7B%22RoleName%22%3A%22AliyunCSDefaultRole%22%2C%22TemplateId%22%3A%22Default%22%7D%2C%7B%22RoleName%22%3A%22AliyunCSManagedKubernetesRole%22%2C%22TemplateId%22%3A%22ManagedKubernetes%22%7D%2C%7B%22RoleName%22%3A%22AliyunCSManagedArmsRole%22%2C%22TemplateId%22%3A%22AliyunCSManagedArmsRole%22%7D%2C%7B%22RoleName%22%3A%22AliyunOOSLifecycleHook4CSRole%22%2C%22TemplateId%22%3A%22AliyunOOSLifecycleHook4CSRole%22%7D%5D%2C%22Service%22%3A%22CS%22%7D%5D%7D

## Terraform Provider 镜像配置（国内环境）

国内访问 registry.terraform.io 可能很慢，配置镜像加速：

```bash
cat > ~/.terraformrc << 'EOF'
provider_installation {
  network_mirror {
    url     = "https://mirrors.aliyun.com/terraform/"
    include = ["registry.terraform.io/aliyun/*", "registry.terraform.io/hashicorp/alicloud"]
  }
  direct {
    exclude = []
  }
}
EOF
```

## 环境变量配置

建议写入 `~/.bashrc` 永久生效：

```bash
cat >> ~/.bashrc << 'EOF'
export ALICLOUD_ACCESS_KEY=$(cat ~/.aliyun/config.json | jq -r '.profiles[0].access_key_id')
export ALICLOUD_SECRET_KEY=$(cat ~/.aliyun/config.json | jq -r '.profiles[0].access_key_secret')
export ALICLOUD_REGION=$(cat ~/.aliyun/config.json | jq -r '.profiles[0].region_id')
EOF
source ~/.bashrc
```

## 部署场景

### 场景 1: 全新部署 (New ACK + NAS + App)

在 `terraform.tfvars` 中设置：

```hcl
create_ack             = true
create_nas             = true
cluster_name           = "fortiaigate-cluster"
certificate_id         = "<your-cert-id>-cn-hangzhou"
gpu_instance_type      = "ecs.gn7i-c16g1.4xlarge"
gpu_node_pool_desired  = 1
region                 = "cn-wulanchabu"
cluster_version        = "1.35.2-aliyun.1"
vpc_cidr               = "10.0.0.0/16"
```

部署步骤（两阶段）：

```bash
cd ~/ALI-terraform-fortiaigate
terraform init

# 第一阶段：创建基础设施（不部署应用）
terraform plan -var="deploy_app=false" --out=tfplan.out
terraform apply tfplan.out

# kubeconfig 已自动生成（由 null_resource.kubeconfig 完成）
# 输出位置: ~/.kube/config 和 ./.kubeconfig

# 等待 GPU 节点 Ready
kubectl get nodes --watch

# 第二阶段：部署应用（自动完成以下操作）
# - 安装 ALB Ingress Controller
# - 安装并配置 ACR 免密拉镜像组件
# - 创建 AlbConfig、IngressClass、Ingress
# - 部署 Helm chart（含所有应用组件）
terraform plan --out=tfplan.out
terraform apply tfplan.out
```

### 场景 2: 已有 ACK + 已有 NAS

```hcl
create_ack         = false
create_nas         = false
cluster_name       = "your-cluster-name"
nas_id             = "your-nas-id"
nas_mount_target   = "<your-nas-id>-xxx.cn-wulanchabu.nas.aliyuncs.com"
certificate_id     = "<your-cert-id>-cn-hangzhou"
```

获取 `nas_mount_target` 的方法：
- **控制台**: NAS → File Systems → 点击文件系统 ID → Mount Targets → Mount Target Domain 列
- **命令行**: `aliyun nas DescribeMountTargets --region cn-wulanchabu --FileSystemId <NAS_ID> | jq -r '.MountTargets.MountTarget[0].MountTargetDomain'`

单阶段部署：

```bash
terraform init
terraform plan --out=tfplan.out
terraform apply tfplan.out
```

### 场景 3: 已有 ACK + 新建 NAS

```hcl
create_ack      = false
create_nas      = true
cluster_name    = "your-cluster-name"
certificate_id  = "<your-cert-id>-cn-hangzhou"
```

## 重要注意事项

### 1. ACR 企业版镜像拉取配置

Terraform 第二阶段部署时会自动安装 `aliyun-acr-credential-helper` 组件并配置免密拉镜像。前提条件：
- ACR 控制台已开启 VPC 内网访问并绑定 ACK 集群所在 VPC + 任意一个 node VSwitch（同 VPC 下所有子网自动生效）
- ACR 实例 ID 已在代码中配置（当前为 `<your-acr-instance-id>`）

如需更换 ACR 实例，修改 `main.tf` 中 `null_resource.acr_credential_config` 里的 `instanceId`。

### 2. 不要删除 ACK API Server 的 SLB

ACK 控制台 → 集群信息 → API server SLB 是集群控制面入口，**绝对不要手动删除或修改**。

### 3. Pod 网络出公网

Terraform 代码已为 node VSwitch 和 pod VSwitch 都配置了 SNAT 规则。如果 license 验证报 "Server Error"，检查 pod 是否能访问公网：

```bash
kubectl exec -n fortiaigate <pod-name> -- curl -s --connect-timeout 5 https://support.fortinet.com -o /dev/null -w "%{http_code}"
```

### 4. 证书 ID 格式

阿里云 ALB Ingress 的证书 ID 是 CertIdentifier 格式：`数字ID-cn-hangzhou`（不是纯数字）。在数字证书管理服务控制台查看。

### 5. GPU 节点无 Taint

代码中 GPU 节点池不设置 taint（与 AWS 版一致），所有 pod 直接调度到 GPU 节点上。

### 6. ALB 域名访问

阿里云 ALB 的 HTTPS 监听器使用 SNI 匹配证书。使用 ALB 默认域名（`*.alb.aliyuncsslb.com`）访问时，SNI 与证书不匹配，ALB 会直接 reset 连接。**必须通过绑定了证书的域名访问**，将域名 CNAME 到 ALB 地址即可。

> 这与 AWS ALB 行为不同 — AWS ALB 在 SNI 不匹配时会 fallback 到默认证书完成握手。

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `region` | `cn-wulanchabu` | 阿里云区域 |
| `create_ack` | `false` | 创建新 ACK 集群 |
| `create_nas` | `false` | 创建新 NAS 文件系统 |
| `cluster_name` | — | ACK 集群名称 (required) |
| `cluster_version` | `1.35.2-aliyun.1` | Kubernetes 版本 |
| `gpu_instance_type` | `ecs.gn7i-c16g1.4xlarge` | GPU 实例规格 |
| `gpu_node_pool_desired` | `1` | GPU 节点数量 |
| `vpc_cidr` | `10.0.0.0/16` | VPC CIDR（新建集群时） |
| `nas_id` | `""` | 已有 NAS ID（create_nas=false 时必填） |
| `nas_mount_target` | `""` | 已有 NAS 挂载点域名（create_nas=false 时必填） |
| `certificate_id` | `""` | SSL 证书 CertIdentifier |
| `ingress_host` | `""` | ALB 域名 |
| `gpu_node_name` | `""` | GPU 节点名（留空自动检测，格式：region.private_ip） |
| `deploy_app` | `true` | 部署 Helm chart（设 false 仅建基础设施） |

## Outputs

| Output | Description |
|--------|-------------|
| `cluster_id` | ACK 集群 ID |
| `nas_id` | NAS 文件系统 ID |
| `gpu_node_name` | GPU 节点名（格式：cn-wulanchabu.x.x.x.x） |
| `namespace` | Kubernetes namespace |
| `fortiaigate_helm_status` | Helm release 状态 |

## License 绑定

`charts/files/licenses/*.lic` 文件会按字母排序与 GPU 节点 1:1 绑定。GPU 节点通过 ECS tag `ack.aliyun.com` 自动发现，节点名格式为 `region_id.private_ip`。

### 扩展 GPU 节点时自动激活 License

扩展节点后，Terraform 会自动发现新节点并从 `charts/files/licenses/` 中分配 license。操作步骤：

```bash
# 1. 扩容节点池（例如从 1 扩到 2）
aliyun cs ModifyClusterNodePool \
  --ClusterId <cluster_id> \
  --NodepoolId <nodepool_id> \
  --body '{"scaling_group":{"desired_size":2}}'

# 2. 等待新节点 Ready
kubectl get nodes -l nvidia.com/gpu.present=true --watch

# 3. 执行 terraform apply，自动绑定 license 到新节点
cd ~/ALI-terraform-fortiaigate
terraform apply

# 4. 扩展 Triton 副本数
kubectl scale deploy triton-server -n fortiaigate --replicas=2
```

> **注意事项**：
> - `charts/files/licenses/` 目录下的 `.lic` 文件数量必须 >= GPU 节点数，否则多出的节点无法分配 license
> - 新节点加入后必须执行 `terraform apply` 才能完成 license 绑定，不会全自动触发
> - License 按文件名字母排序与节点（按 IP 排序）一一对应，新增节点可能导致已有节点的 license 重新分配

## 清理

```bash
terraform destroy
```

## 故障排查

| 问题 | 排查方法 |
|------|----------|
| Pod ImagePullBackOff | ACR credential helper 未注入 imagePullSecret，手动 patch SA 并重启 Pod |
| License Server Error | Pod 无法访问公网，检查 SNAT 规则是否覆盖 pod VSwitch |
| PVC Pending | 检查 StorageClass 的 `server` 参数是否为 NAS mount target 域名 |
| Ingress 无 ADDRESS | 确认 ALB Ingress Controller 已安装、AlbConfig 和 IngressClass 已创建 |
| GPU 节点未检测到 | 确认节点带 tag `ack.aliyun.com`，或手动设置 `gpu_node_name` |
| Terraform count 错误 | state 不一致，用 `terraform import` 修复 |
| ALB 默认域名无法访问 | 阿里云 ALB 在 SNI 不匹配时直接 reset 连接，必须通过绑定证书的域名访问 |
