###############################################################################
# NFS Subdir External Provisioner 模块
# 提供 ReadWriteMany StorageClass 供 FortiAIGate 使用
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
resource "kubernetes_namespace" "nfs" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "fortiaigate-infrastructure"
    }
  }
}

# 通过 Helm 部署 NFS Subdir External Provisioner
resource "helm_release" "nfs_provisioner" {
  name       = "nfs-subdir-external-provisioner"
  namespace  = kubernetes_namespace.nfs.metadata[0].name
  repository = ""
  chart      = "${path.module}/nfs-subdir-external-provisioner-4.0.18.tgz"

  set {
    name  = "nfs.server"
    value = var.nfs_server
  }

  set {
    name  = "nfs.path"
    value = var.nfs_path
  }

  set {
    name  = "storageClass.name"
    value = var.storage_class_name
  }

  set {
    name  = "storageClass.defaultClass"
    value = tostring(var.storage_class_default)
  }

  set {
    name  = "storageClass.reclaimPolicy"
    value = "Retain"
  }

  set {
    name  = "storageClass.archiveOnDelete"
    value = tostring(var.archive_on_delete)
  }

  set {
    name  = "storageClass.accessModes"
    value = "ReadWriteMany"
  }

  # 使用国内镜像源
  set {
    name  = "image.repository"
    value = var.image_repository
  }

  set {
    name  = "image.tag"
    value = var.image_tag
  }

  wait    = true
  timeout = 300
}
