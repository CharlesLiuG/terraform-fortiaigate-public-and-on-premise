output "nfs_server_ip" {
  description = "NFS Server IP 地址"
  value       = var.nfs_server_host
}

output "nfs_export_path" {
  description = "NFS 导出路径"
  value       = var.nfs_export_path
}
