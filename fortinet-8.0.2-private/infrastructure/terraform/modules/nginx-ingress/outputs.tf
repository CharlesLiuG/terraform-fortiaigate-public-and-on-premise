output "namespace" {
  description = "Nginx Ingress 命名空间"
  value       = kubernetes_namespace.ingress_nginx.metadata[0].name
}

output "ingress_class_name" {
  description = "Ingress Class 名称"
  value       = "nginx"
}

output "service_endpoints" {
  description = "Service 暴露信息"
  value = {
    type       = var.service_type
    http_port  = var.service_type == "NodePort" ? var.node_port_http : 80
    https_port = var.service_type == "NodePort" ? var.node_port_https : 443
  }
}
