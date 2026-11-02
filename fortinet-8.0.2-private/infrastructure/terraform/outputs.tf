###############################################################################
# 输出
###############################################################################

# --- K8S 集群 ---
output "k8s_master_ip" {
  description = "Master 节点 IP"
  value       = var.deploy_k8s_cluster ? module.k8s_cluster[0].master_ip : "使用已有集群"
}

output "k8s_worker_count" {
  description = "Worker 节点数量"
  value       = var.deploy_k8s_cluster ? module.k8s_cluster[0].worker_count : "使用已有集群"
}

output "k8s_worker_ips" {
  description = "Worker 节点 IP 列表"
  value       = var.deploy_k8s_cluster ? module.k8s_cluster[0].worker_ips : []
}

# --- NFS ---
output "nfs_server_ip" {
  description = "NFS Server IP 地址"
  value       = var.deploy_nfs ? module.nfs_server[0].nfs_server_ip : "使用客户已有 NFS"
}

output "nfs_export_path" {
  description = "NFS 导出路径"
  value       = var.deploy_nfs ? module.nfs_server[0].nfs_export_path : "N/A"
}

output "storage_class_name" {
  description = "StorageClass 名称（供 FortiAIGate values 引用）"
  value       = var.deploy_nfs ? module.nfs_provisioner[0].storage_class_name : var.existing_storage_class
}

# --- Nginx Ingress ---
output "nginx_ingress_namespace" {
  description = "Nginx Ingress Controller 命名空间"
  value       = var.deploy_nginx_ingress ? module.nginx_ingress[0].namespace : "N/A"
}

output "nginx_ingress_class" {
  description = "Ingress Class 名称"
  value       = var.deploy_nginx_ingress ? module.nginx_ingress[0].ingress_class_name : "nginx"
}

output "nginx_service_endpoints" {
  description = "Nginx Ingress 对外端口"
  value       = var.deploy_nginx_ingress ? module.nginx_ingress[0].service_endpoints : {}
}

# --- 验证 ---
output "preflight_status" {
  description = "部署前验证状态"
  value       = module.preflight_check.status
}

# --- 部署场景 ---
output "deployment_scenario" {
  description = "当前部署场景"
  value = var.deploy_k8s_cluster ? "场景1: 全新环境（K8S + NFS + Nginx Ingress）" : (
    var.deploy_nfs ? "场景3: 有K8S无NFS（NFS + Nginx Ingress）" : "场景2: 有K8S有NFS（仅 Nginx Ingress）"
  )
}
