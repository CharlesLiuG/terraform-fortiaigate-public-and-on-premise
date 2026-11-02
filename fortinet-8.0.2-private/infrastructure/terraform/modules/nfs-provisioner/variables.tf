variable "namespace" {
  description = "NFS Provisioner 命名空间"
  type        = string
  default     = "nfs-provisioner"
}

variable "nfs_server" {
  description = "NFS 服务器地址"
  type        = string
}

variable "nfs_path" {
  description = "NFS 导出路径"
  type        = string
}

variable "storage_class_name" {
  description = "StorageClass 名称"
  type        = string
  default     = "nfs-client"
}

variable "archive_on_delete" {
  description = "删除 PVC 时归档数据"
  type        = bool
  default     = true
}

variable "image_repository" {
  description = "NFS Provisioner 镜像地址（国内源）"
  type        = string
  default     = "registry.cn-hangzhou.aliyuncs.com/kubernetes-china/nfs-subdir-external-provisioner"
}

variable "image_tag" {
  description = "NFS Provisioner 镜像 Tag"
  type        = string
  default     = "v4.0.2"
}

variable "storage_class_default" {
  description = "是否将该 StorageClass 设为集群默认（is-default-class）"
  type        = bool
  default     = true
}
