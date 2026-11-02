###############################################################################
# Nginx Ingress Controller 模块
# 私有化环境入口控制器，支持 NodePort / HostNetwork 模式
###############################################################################

terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    helm = {
      source = "hashicorp/helm"
    }
  }
}

# 创建命名空间
resource "kubernetes_namespace" "ingress_nginx" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "fortiaigate-infrastructure"
    }
  }
}

# 通过 Helm 部署 Nginx Ingress Controller
resource "helm_release" "nginx_ingress" {
  name       = "ingress-nginx"
  namespace  = kubernetes_namespace.ingress_nginx.metadata[0].name
  repository = ""
  chart      = "${path.module}/ingress-nginx-4.12.1.tgz"

  # 副本数
  set {
    name  = "controller.replicaCount"
    value = var.replica_count
  }

  # Service 类型
  set {
    name  = "controller.service.type"
    value = var.service_type
  }

  # NodePort 配置
  dynamic "set" {
    for_each = var.service_type == "NodePort" ? [1] : []
    content {
      name  = "controller.service.nodePorts.http"
      value = var.node_port_http
    }
  }

  dynamic "set" {
    for_each = var.service_type == "NodePort" ? [1] : []
    content {
      name  = "controller.service.nodePorts.https"
      value = var.node_port_https
    }
  }

  # HostNetwork 模式（直接绑定宿主机端口）
  set {
    name  = "controller.hostNetwork"
    value = tostring(var.host_network)
  }

  dynamic "set" {
    for_each = var.host_network ? [1] : []
    content {
      name  = "controller.dnsPolicy"
      value = "ClusterFirstWithHostNet"
    }
  }

  # Ingress Class 配置
  set {
    name  = "controller.ingressClassResource.name"
    value = "nginx"
  }

  set {
    name  = "controller.ingressClassResource.default"
    value = "true"
  }

  # 使用国内镜像源
  set {
    name  = "controller.image.registry"
    value = var.image_registry
  }

  set {
    name  = "controller.image.image"
    value = var.controller_image
  }

  set {
    name  = "controller.image.tag"
    value = var.controller_image_tag
  }

  set {
    name  = "controller.image.digest"
    value = ""
  }

  set {
    name  = "controller.admissionWebhooks.patch.image.registry"
    value = var.image_registry
  }

  set {
    name  = "controller.admissionWebhooks.patch.image.image"
    value = var.kube_webhook_certgen_image
  }

  set {
    name  = "controller.admissionWebhooks.patch.image.tag"
    value = var.kube_webhook_certgen_tag
  }

  set {
    name  = "controller.admissionWebhooks.patch.image.digest"
    value = ""
  }

  # 允许不安全的 TLS 版本（私有环境内部通信）
  set {
    name  = "controller.config.ssl-protocols"
    value = "TLSv1.2 TLSv1.3"
  }

  # 代理超时配置（与 FortiAIGate values 对齐）
  set {
    name  = "controller.config.proxy-connect-timeout"
    value = "900"
  }

  set {
    name  = "controller.config.proxy-read-timeout"
    value = "900"
  }

  set {
    name  = "controller.config.proxy-send-timeout"
    value = "900"
  }

  # 大请求体支持（LLM 请求内容可能较大）
  set {
    name  = "controller.config.proxy-body-size"
    value = "50m"
  }

  # 允许后端使用 HTTPS
  set {
    name  = "controller.config.use-forwarded-headers"
    value = "true"
  }

  # 关闭 Admission Webhook（简化私有环境部署）
  set {
    name  = "controller.admissionWebhooks.enabled"
    value = "false"
  }

  # 指标（可选）
  set {
    name  = "controller.metrics.enabled"
    value = "true"
  }

  wait    = true
  timeout = 600
}
