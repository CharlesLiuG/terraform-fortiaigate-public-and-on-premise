output "fortiaigate_helm_status" {
  description = "Helm release status"
  value       = var.deploy_app ? helm_release.fortiaigate[0].status : "not deployed"
}

output "cluster_id" {
  description = "ACK cluster ID"
  value       = local.cluster_id
}

output "gpu_node_name" {
  description = "GPU node hostname used for license binding"
  value       = local.gpu_node_name
}

output "nas_id" {
  description = "NAS file system ID"
  value       = local.nas_id
}

output "namespace" {
  value = var.namespace
}
