# ═══════════════════════════════════════════════════════════════════════════════
# 场景 1: 全新部署（自动创建 VPC + EKS + EFS + FortiAIGate）
# ═══════════════════════════════════════════════════════════════════════════════
create_eks             = true
create_efs             = true
cluster_name           = "xxxxxxxxxxx"
certificate_arn        = "arn:aws:acm:us-east-1:xxxxxxxxxxx:certificate/xxxxxxxxxxxx"
gpu_instance_type      = "g6.4xlarge"
gpu_node_group_desired = 1
aws_region             = "us-east-1"
cluster_version        = "1.35"
vpc_cidr               = "10.0.0.0/16"

# ═══════════════════════════════════════════════════════════════════════════════
# Cluster Addons（默认安装，已有集群已装过可设为 false）
# ═══════════════════════════════════════════════════════════════════════════════
install_efs_csi_driver       = true
install_aws_lbc              = true
install_nvidia_device_plugin = true
create_efs_storage_class     = true

# ═══════════════════════════════════════════════════════════════════════════════
# FortiAIGate 8.0.2 镜像与 GPU 配置
# ═══════════════════════════════════════════════════════════════════════════════
# 镜像仓库 / Tag：部署在 us-east-1,按需部署即可根据你的环境）
image_repository = "xxxxxxxxxxxxx.dkr.ecr.us-east-1.amazonaws.com/xxxxxx"
image_tag        = "V8.0.2-build0055"

# GPU 调优 profile：AWS g6 实例为 NVIDIA L4 -> "l4"（见 charts/files/gpu-profiles.yaml）
gpu_profile = "l4"

# ═══════════════════════════════════════════════════════════════════════════════
# License（8.0.2 变更）
# ═══════════════════════════════════════════════════════════════════════════════
# 8.0.2 起 License 不再通过 Helm 绑定到 GPU 节点，改为部署完成后通过管理 API 上传：
#   POST /api/v1/admin/licenses
# 因此不再需要 charts/files/licenses/*.lic，也不再有 gpu_node_name 变量。

# ═══════════════════════════════════════════════════════════════════════════════
# 场景 2: 客户已有 EKS + EFS，只部署 FortiAIGate
# ═══════════════════════════════════════════════════════════════════════════════
# create_eks      = false
# create_efs      = false
# cluster_name    = "xxxxxxxxxxxxxxxx"
# efs_id          = "fs-xxxxxxxxxxxxx"
# certificate_arn = "arn:aws:acm:us-east-1:6546xxxxxx:certificate/xxxxx"

# ═══════════════════════════════════════════════════════════════════════════════
# 场景 3: 客户已有 EKS，新建 EFS
# ═══════════════════════════════════════════════════════════════════════════════
# create_eks      = false
# create_efs      = true
# cluster_name    = "xxxxxxxxxxxx"
# certificate_arn = "arn:aws:acm:us-east-1:xxxxxxxxxxxxx:certificate/xxxxxxx"
