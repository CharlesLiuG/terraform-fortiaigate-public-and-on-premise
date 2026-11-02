# ═══════════════════════════════════════════════════════════════════════════════
# 场景 1: 全新部署（自动创建 VPC + ACK + NAS + FortiAIGate）
# ═══════════════════════════════════════════════════════════════════════════════
create_ack             = true
create_nas             = true
cluster_name           = "lg-fortiaigate-cluster"
certificate_id         = "21499736-cn-hangzhou"
gpu_instance_type      = "ecs.gn7i-c16g1.4xlarge"
gpu_node_pool_desired  = 1
region                 = "cn-wulanchabu"
cluster_version        = "1.35.7-aliyun.1"
vpc_cidr               = "172.16.0.0/16"

# ═══════════════════════════════════════════════════════════════════════════════
# Cluster Addons（ACK 通常已内置 CSI，ALB 需单独安装）
# ═══════════════════════════════════════════════════════════════════════════════
install_nvidia_device_plugin   = false
create_nas_storage_class       = true

# ═══════════════════════════════════════════════════════════════════════════════
# 场景 2: 已有 ACK + NAS，只部署 FortiAIGate
# ═══════════════════════════════════════════════════════════════════════════════
# create_ack         = false
# create_nas         = false
# cluster_name       = "fortiaigate-cluster"
# nas_id             = "your-nas-id"
# nas_mount_target   = "your-nas-id-xxx.cn-wulanchabu.nas.aliyuncs.com"
# certificate_id     = "21xxxxx-cn-hangzhou"

# ═══════════════════════════════════════════════════════════════════════════════
# 场景 3: 已有 ACK，新建 NAS
# ═══════════════════════════════════════════════════════════════════════════════
# create_ack      = false
# create_nas      = true
# cluster_name    = "fortiaigate-cluster"
# certificate_id  = "21xxxxx-cn-hangzhou"
