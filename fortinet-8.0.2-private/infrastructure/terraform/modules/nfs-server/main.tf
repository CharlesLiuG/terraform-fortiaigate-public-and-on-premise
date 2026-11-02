###############################################################################
# NFS Server 部署模块
# 在指定节点上安装配置 NFS Server，供 NFS Provisioner 使用
# 场景1（全新环境）和 场景3（有K8S无NFS）均需要
###############################################################################

terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

resource "null_resource" "nfs_server" {
  connection {
    type        = "ssh"
    host        = var.nfs_server_host
    user        = var.nfs_server_user
    private_key = var.ssh_private_key != "" ? var.ssh_private_key : null
    password    = var.ssh_password != "" ? var.ssh_password : null
    port        = var.ssh_port
  }

  # 安装 NFS Server
  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo '>>> 安装 NFS Server...'",
      "sudo apt-get update -qq",
      "sudo apt-get install -y -qq nfs-kernel-server",
      "echo '>>> 创建共享目录...'",
      "sudo mkdir -p ${var.nfs_export_path}",
      "sudo chown nobody:nogroup ${var.nfs_export_path}",
      "sudo chmod 777 ${var.nfs_export_path}",
      "echo '>>> 配置 NFS 导出...'",
      # 移除旧条目（如果存在）
      "sudo sed -i '\\|${var.nfs_export_path}|d' /etc/exports",
      # 添加导出配置
      "echo '${var.nfs_export_path} ${var.allowed_network}(rw,sync,no_subtree_check,no_root_squash)' | sudo tee -a /etc/exports",
      "echo '>>> 启动 NFS Server...'",
      "sudo exportfs -ra",
      "sudo systemctl restart nfs-kernel-server",
      "sudo systemctl enable nfs-kernel-server",
      "echo '>>> 验证 NFS 导出...'",
      "sudo exportfs -v",
      "echo '>>> NFS Server 部署完成!'",
    ]
  }
}

# 验证 NFS Server 可被客户端访问
resource "null_resource" "nfs_verify" {
  count      = length(var.nfs_client_hosts)
  depends_on = [null_resource.nfs_server]

  connection {
    type        = "ssh"
    host        = var.nfs_client_hosts[count.index]
    user        = var.nfs_client_user
    private_key = var.ssh_private_key != "" ? var.ssh_private_key : null
    password    = var.ssh_password != "" ? var.ssh_password : null
    port        = var.ssh_port
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo '>>> [Client-${count.index + 1}] 安装 NFS 客户端工具...'",
      "sudo apt-get update -qq",
      "sudo apt-get install -y -qq nfs-common",
      "echo '>>> [Client-${count.index + 1}] 验证能访问 NFS Server...'",
      "showmount -e ${var.nfs_server_internal_ip != "" ? var.nfs_server_internal_ip : var.nfs_server_host}",
      "echo '>>> [Client-${count.index + 1}] NFS 客户端验证通过!'",
    ]
  }
}
