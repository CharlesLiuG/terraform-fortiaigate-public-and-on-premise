output "fortiaigate_helm_status" {
  description = "Helm release status"
  value       = var.deploy_app ? helm_release.fortiaigate[0].status : "not deployed"
}

output "eks_cluster_endpoint" {
  description = "EKS API endpoint"
  value       = local.cluster_endpoint
}

output "gpu_node_name" {
  description = "GPU node hostname used for license binding"
  value       = local.gpu_node_name
}

output "efs_id" {
  description = "EFS file system ID"
  value       = local.efs_id
}

output "namespace" {
  value = var.namespace
}
