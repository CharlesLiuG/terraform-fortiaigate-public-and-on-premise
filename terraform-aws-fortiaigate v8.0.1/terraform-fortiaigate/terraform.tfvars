# ═══════════════════════════════════════════════════════════════════════════════
# 场景 1: 全新部署（自动创建 VPC + EKS + EFS + FortiAIGate）
# 只需设置 cluster_name 和 certificate_arn，VPC/Subnet 自动创建
# ═══════════════════════════════════════════════════════════════════════════════
# create_eks             = true
# create_efs             = true
# cluster_name           = "fortiaigate-cluster"
# certificate_arn        = "arn:aws:acm:us-east-1:6555xxxxxx:certificate/xxx"
# gpu_instance_type      = "g5.4xlarge"
# gpu_node_group_desired = 1
# aws_region             = "us-east-1"
# cluster_version        = "1.35"
# vpc_cidr               = "10.0.0.0/16"

# ═══════════════════════════════════════════════════════════════════════════════
# Cluster Addons（默认安装，已有集群已装过可设为 false）
# ═══════════════════════════════════════════════════════════════════════════════
install_efs_csi_driver        = true
install_aws_lbc               = true
install_nvidia_device_plugin  = true
create_efs_storage_class      = true

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
# cluster_name    = "lg-AIGate-cluster"
# certificate_arn = "arn:aws:acm:us-east-1:6546124395042:certificate/xxxxxxx"
