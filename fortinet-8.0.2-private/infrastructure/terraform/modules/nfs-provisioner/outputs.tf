output "storage_class_name" {
  description = "创建的 StorageClass 名称"
  value       = var.storage_class_name
}

output "namespace" {
  description = "NFS Provisioner 命名空间"
  value       = kubernetes_namespace.nfs.metadata[0].name
}
