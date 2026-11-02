variable "cluster_name" { type = string }
variable "cluster_version" { type = string }
variable "vpc_cidr" { type = string }
variable "region" { type = string }
variable "instance_type" { type = string }
variable "desired_size" { type = number }

# ─────────────────────────────────────────────────────────────────────────────
# 可用区
# ─────────────────────────────────────────────────────────────────────────────
data "alicloud_zones" "available" {
  available_resource_creation = "VSwitch"
}

# ─────────────────────────────────────────────────────────────────────────────
# VPC + VSwitch
# ─────────────────────────────────────────────────────────────────────────────
resource "alicloud_vpc" "this" {
  vpc_name   = "${var.cluster_name}-vpc"
  cidr_block = var.vpc_cidr
}

resource "alicloud_vswitch" "pod" {
  count        = 2
  vpc_id       = alicloud_vpc.this.id
  cidr_block   = cidrsubnet(var.vpc_cidr, 8, count.index + 200)
  zone_id      = data.alicloud_zones.available.zones[count.index].id
  vswitch_name = "${var.cluster_name}-pod-${count.index}"
}

resource "alicloud_vswitch" "node" {
  count        = 2
  vpc_id       = alicloud_vpc.this.id
  cidr_block   = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  zone_id      = data.alicloud_zones.available.zones[count.index].id
  vswitch_name = "${var.cluster_name}-node-${count.index}"
}

# ─────────────────────────────────────────────────────────────────────────────
# NAT Gateway (节点访问公网拉取镜像)
# ─────────────────────────────────────────────────────────────────────────────
resource "alicloud_nat_gateway" "this" {
  vpc_id           = alicloud_vpc.this.id
  nat_gateway_name = "${var.cluster_name}-nat"
  payment_type     = "PayAsYouGo"
  vswitch_id       = alicloud_vswitch.node[0].id
  nat_type         = "Enhanced"
}

resource "alicloud_eip_address" "nat" {
  address_name         = "${var.cluster_name}-nat-eip"
  bandwidth            = 100
  internet_charge_type = "PayByTraffic"
  payment_type         = "PayAsYouGo"
}

resource "alicloud_eip_association" "nat" {
  allocation_id = alicloud_eip_address.nat.id
  instance_id   = alicloud_nat_gateway.this.id
  instance_type = "Nat"
}

resource "alicloud_snat_entry" "node" {
  count             = 2
  snat_table_id     = alicloud_nat_gateway.this.snat_table_ids
  source_vswitch_id = alicloud_vswitch.node[count.index].id
  snat_ip           = alicloud_eip_address.nat.ip_address
  depends_on        = [alicloud_eip_association.nat]
}

resource "alicloud_snat_entry" "pod" {
  count             = 2
  snat_table_id     = alicloud_nat_gateway.this.snat_table_ids
  source_vswitch_id = alicloud_vswitch.pod[count.index].id
  snat_ip           = alicloud_eip_address.nat.ip_address
  depends_on        = [alicloud_eip_association.nat]
}

# ─────────────────────────────────────────────────────────────────────────────
# ACK Managed Cluster
# ─────────────────────────────────────────────────────────────────────────────
resource "alicloud_cs_managed_kubernetes" "this" {
  name                 = var.cluster_name
  version              = var.cluster_version
  vswitch_ids          = alicloud_vswitch.node[*].id
  pod_vswitch_ids      = alicloud_vswitch.pod[*].id
  new_nat_gateway      = false
  service_cidr         = "192.168.0.0/16"
  slb_internet_enabled = true

  addons {
    name = "terway-eniip"
  }
  addons {
    name = "csi-plugin"
  }
  addons {
    name = "csi-provisioner"
  }
  addons {
    name     = "nginx-ingress-controller"
    disabled = true
  }
  addons {
    name = "alb-ingress-controller"
  }
  addons {
    name   = "aliyun-acr-credential-helper"
    config = jsonencode({
      "acr-registry-info" = "[{\"instanceId\":\"cri-trdfajgsnkbtpthu\",\"regionId\":\"cn-wulanchabu\"}]"
      "watch-namespace"   = "all"
      "service-account"   = "*"
    })
  }

  depends_on = [alicloud_snat_entry.node]

  delete_options {
    delete_mode   = "delete"
    resource_type = "ALB"
  }
  delete_options {
    delete_mode   = "delete"
    resource_type = "SLB"
  }

  # Destroy 前自动解绑 ACR VPC endpoint，避免 VSwitch 删除失败
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      for vsw in $(aliyun vpc DescribeVSwitches --region ${self.id != "" ? "cn-wulanchabu" : "cn-wulanchabu"} --VpcId ${self.vpc_id} | jq -r '.VSwitches.VSwitch[].VSwitchId'); do
        aliyun cr DeleteInstanceVpcEndpointLinkedVpc --region cn-wulanchabu --InstanceId cri-trdfajgsnkbtpthu --VpcId ${self.vpc_id} --VswitchId $vsw --ModuleName Registry 2>/dev/null || true
      done
      sleep 10
    EOT
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# ACR VPC Endpoint 绑定 Node Subnet（内网拉镜像）
# ─────────────────────────────────────────────────────────────────────────────
resource "alicloud_cr_vpc_endpoint_linked_vpc" "acr" {
  count       = 2
  instance_id = "cri-trdfajgsnkbtpthu"
  vpc_id      = alicloud_vpc.this.id
  vswitch_id  = alicloud_vswitch.node[count.index].id
  module_name = "Registry"

  enable_create_dns_record_in_pvzt = true

  timeouts {
    create = "10m"
    delete = "10m"
  }

  depends_on = [alicloud_cs_managed_kubernetes.this]
}

# ─────────────────────────────────────────────────────────────────────────────
# GPU Node Pool
# ─────────────────────────────────────────────────────────────────────────────
resource "alicloud_cs_kubernetes_node_pool" "gpu" {
  cluster_id     = alicloud_cs_managed_kubernetes.this.id
  node_pool_name = "${var.cluster_name}-gpu"
  vswitch_ids    = alicloud_vswitch.node[*].id

  instance_types       = [var.instance_type]
  desired_size         = var.desired_size
  system_disk_category = "cloud_essd"
  system_disk_size     = 300

  # GPU 节点标签
  labels {
    key   = "nvidia.com/gpu.present"
    value = "true"
  }
  labels {
    key   = "node.kubernetes.io/gpu"
    value = "true"
  }
  labels {
    key   = "ack.aliyun.com/nvidia-driver-version"
    value = "580.126.09"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Outputs
# ─────────────────────────────────────────────────────────────────────────────
output "cluster_id" {
  value = alicloud_cs_managed_kubernetes.this.id
}

output "cluster_name" {
  value = alicloud_cs_managed_kubernetes.this.name
}

output "vpc_id" {
  value = alicloud_vpc.this.id
}

output "vswitch_ids" {
  value = alicloud_vswitch.node[*].id
}

output "gpu_node_pool_id" {
  value = alicloud_cs_kubernetes_node_pool.gpu.node_pool_id
}
