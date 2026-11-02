#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# Terraform Import Script - 重建 state
# 生成时间: 2026-07-14
# ═══════════════════════════════════════════════════════════════════════════════
set -e

cd "$(dirname "$0")"

echo "=== 开始导入 Terraform State ==="

# ─────────────────────────────────────────────────────────────────────────────
# Module: ACK - VPC
# ─────────────────────────────────────────────────────────────────────────────
echo "[1/20] 导入 VPC..."
terraform import 'module.ack[0].alicloud_vpc.this' vpc-0jlv8nq2xb1yxf9j5hoh0

# ─────────────────────────────────────────────────────────────────────────────
# Module: ACK - VSwitch (node)
# ─────────────────────────────────────────────────────────────────────────────
echo "[2/20] 导入 VSwitch node-0..."
terraform import 'module.ack[0].alicloud_vswitch.node[0]' vsw-0jle0g5g4l1yctyfjvo2v

echo "[3/20] 导入 VSwitch node-1..."
terraform import 'module.ack[0].alicloud_vswitch.node[1]' vsw-0jl6wdknu2dv8lv77pxay

# ─────────────────────────────────────────────────────────────────────────────
# Module: ACK - VSwitch (pod)
# ─────────────────────────────────────────────────────────────────────────────
echo "[4/20] 导入 VSwitch pod-0..."
terraform import 'module.ack[0].alicloud_vswitch.pod[0]' vsw-0jli3dauj86e8lk0nv1e4

echo "[5/20] 导入 VSwitch pod-1..."
terraform import 'module.ack[0].alicloud_vswitch.pod[1]' vsw-0jli316hhgobltpzw2y8h

# ─────────────────────────────────────────────────────────────────────────────
# Module: ACK - NAT Gateway
# ─────────────────────────────────────────────────────────────────────────────
echo "[6/20] 导入 NAT Gateway..."
terraform import 'module.ack[0].alicloud_nat_gateway.this' ngw-0jlsnh5jubavcptjeqzaj

# ─────────────────────────────────────────────────────────────────────────────
# Module: ACK - EIP
# ─────────────────────────────────────────────────────────────────────────────
echo "[7/20] 导入 EIP..."
terraform import 'module.ack[0].alicloud_eip_address.nat' eip-0jlbg3cleycapkwy4jssi

echo "[8/20] 导入 EIP Association..."
terraform import 'module.ack[0].alicloud_eip_association.nat' eip-0jlbg3cleycapkwy4jssi:ngw-0jlsnh5jubavcptjeqzaj

# ─────────────────────────────────────────────────────────────────────────────
# Module: ACK - SNAT Entries (node)
# node[0] -> vsw-0jle0g5g4l1yctyfjvo2v (node-0)
# node[1] -> vsw-0jl6wdknu2dv8lv77pxay (node-1)
# ─────────────────────────────────────────────────────────────────────────────
echo "[9/20] 导入 SNAT node[0]..."
terraform import 'module.ack[0].alicloud_snat_entry.node[0]' stb-0jl765erijm2x65jis0fj:snat-0jl3mjxlb5syzizi33ben

echo "[10/20] 导入 SNAT node[1]..."
terraform import 'module.ack[0].alicloud_snat_entry.node[1]' stb-0jl765erijm2x65jis0fj:snat-0jldr45e7wypwlh6x6cqq

# ─────────────────────────────────────────────────────────────────────────────
# Module: ACK - SNAT Entries (pod)
# pod[0] -> vsw-0jli3dauj86e8lk0nv1e4 (pod-0)
# pod[1] -> vsw-0jli316hhgobltpzw2y8h (pod-1)
# ─────────────────────────────────────────────────────────────────────────────
echo "[11/20] 导入 SNAT pod[0]..."
terraform import 'module.ack[0].alicloud_snat_entry.pod[0]' stb-0jl765erijm2x65jis0fj:snat-0jlwvoiiv1ewg9jnz1hrl

echo "[12/20] 导入 SNAT pod[1]..."
terraform import 'module.ack[0].alicloud_snat_entry.pod[1]' stb-0jl765erijm2x65jis0fj:snat-0jl653434enjbua74ljsu

# ─────────────────────────────────────────────────────────────────────────────
# Module: ACK - Managed Kubernetes Cluster
# ─────────────────────────────────────────────────────────────────────────────
echo "[13/20] 导入 ACK 集群..."
terraform import 'module.ack[0].alicloud_cs_managed_kubernetes.this' c7800a2be7c30421280c9d8ef2f5b05e6

# ─────────────────────────────────────────────────────────────────────────────
# Module: ACK - GPU Node Pool
# ─────────────────────────────────────────────────────────────────────────────
echo "[14/20] 导入 GPU Node Pool..."
terraform import 'module.ack[0].alicloud_cs_kubernetes_node_pool.gpu' c7800a2be7c30421280c9d8ef2f5b05e6:np09b274e9fb3c4312b0fa8b593c3b6d56

# ─────────────────────────────────────────────────────────────────────────────
# Module: ACK - ACR VPC Endpoint
# ─────────────────────────────────────────────────────────────────────────────
echo "[15/20] 导入 ACR VPC Endpoint [0] (node-0)..."
terraform import 'module.ack[0].alicloud_cr_vpc_endpoint_linked_vpc.acr[0]' cri-trdfajgsnkbtpthu:vpc-0jlv8nq2xb1yxf9j5hoh0:vsw-0jle0g5g4l1yctyfjvo2v

echo "[16/20] 导入 ACR VPC Endpoint [1] (node-1)..."
terraform import 'module.ack[0].alicloud_cr_vpc_endpoint_linked_vpc.acr[1]' cri-trdfajgsnkbtpthu:vpc-0jlv8nq2xb1yxf9j5hoh0:vsw-0jl6wdknu2dv8lv77pxay

# ─────────────────────────────────────────────────────────────────────────────
# Module: NAS - File System
# ─────────────────────────────────────────────────────────────────────────────
echo "[17/20] 导入 NAS 文件系统..."
terraform import 'module.nas[0].alicloud_nas_file_system.this' 291upocmqwx7azz8fqg

echo "[17.1/20] 导入 NAS Access Group..."
terraform import 'module.nas[0].alicloud_nas_access_group.this' FortiAIGateAG:standard

echo "[17.2/20] 导入 NAS Access Rule..."
terraform import 'module.nas[0].alicloud_nas_access_rule.this' FortiAIGateAG:1

echo "[17.3/20] 导入 NAS Mount Target..."
terraform import 'module.nas[0].alicloud_nas_mount_target.this' 291upocmqwx7azz8fqg:291upocmqwx7azz8fqg-slw72.cn-wulanchabu.nas.aliyuncs.com

# ─────────────────────────────────────────────────────────────────────────────
# Main Module - Kubernetes Resources
# ─────────────────────────────────────────────────────────────────────────────
echo "[18/20] 导入 Kubernetes Namespace..."
terraform import 'kubernetes_namespace.fortiaigate[0]' fortiaigate

echo "[19/20] 导入 StorageClass nas-sc..."
terraform import 'kubernetes_storage_class.nas_sc[0]' nas-sc

echo "[19.1/20] 导入 StorageClass nas-sc-db..."
terraform import 'kubernetes_storage_class.nas_sc_db[0]' nas-sc-db

# ─────────────────────────────────────────────────────────────────────────────
# Main Module - Helm Release
# ─────────────────────────────────────────────────────────────────────────────
echo "[20/20] 导入 Helm Release..."
terraform import 'helm_release.fortiaigate[0]' fortiaigate/fortiaigate

echo ""
echo "=== 导入完成！ ==="
echo ""
echo "下一步:"
echo "  1. 运行 'terraform plan' 检查差异"
echo "  2. 确认无重大差异后运行 'terraform destroy' 删除所有资源"
