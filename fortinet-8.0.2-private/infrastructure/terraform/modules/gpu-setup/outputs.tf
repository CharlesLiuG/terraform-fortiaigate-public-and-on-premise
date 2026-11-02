output "gpu_node_count" {
  description = "GPU 节点数量"
  value       = length(var.gpu_worker_nodes)
}

output "gpu_driver_version" {
  description = "安装的 NVIDIA 驱动版本"
  value       = var.nvidia_driver_version
}

output "cuda_version" {
  description = "安装的 CUDA 版本"
  value       = var.cuda_version
}
