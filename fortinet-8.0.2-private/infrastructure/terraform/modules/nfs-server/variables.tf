variable "nfs_server_host" {
  description = "NFS Server 部署的目标节点 IP"
  type        = string
}

variable "nfs_server_user" {
  description = "NFS Server 节点 SSH 用户"
  type        = string
  default     = "root"
}

variable "nfs_export_path" {
  description = "NFS 导出共享目录路径"
  type        = string
  default     = "/data/nfs/fortiaigate"
}

variable "allowed_network" {
  description = "允许挂载 NFS 的网段（CIDR 格式）"
  type        = string
  default     = "192.168.1.0/24"
}

variable "nfs_client_hosts" {
  description = "需要安装 NFS 客户端的节点 IP 列表（通常是所有 K8S Worker 节点）"
  type        = list(string)
  default     = []
}

variable "nfs_client_user" {
  description = "NFS 客户端节点 SSH 用户"
  type        = string
  default     = "root"
}

variable "ssh_private_key" {
  description = "SSH 私钥"
  type        = string
  default     = ""
  sensitive   = true
}

variable "ssh_password" {
  description = "SSH 密码"
  type        = string
  default     = ""
  sensitive   = true
}

variable "ssh_port" {
  description = "SSH 端口"
  type        = number
  default     = 22
}

variable "nfs_server_internal_ip" {
  description = "NFS Server 内网 IP（用于客户端验证和挂载）"
  type        = string
  default     = ""
}
