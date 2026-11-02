output "master_ip" {
  description = "Master 节点 IP"
  value       = var.master_node.host
}

output "worker_count" {
  description = "Worker 节点数量"
  value       = length(var.worker_nodes)
}

output "worker_ips" {
  description = "所有 Worker 节点 IP 列表"
  value       = [for w in var.worker_nodes : w.host]
}

output "kubeconfig_hint" {
  description = "获取 kubeconfig 的命令"
  value       = "scp ${var.master_node.user}@${var.master_node.host}:~/.kube/config ~/.kube/config"
}
