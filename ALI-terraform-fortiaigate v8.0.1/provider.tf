terraform {
  required_version = ">= 1.5"
  required_providers {
    alicloud = {
      source  = "aliyun/alicloud"
      version = "~> 1.230"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
  }
}

provider "alicloud" {
  region                  = var.region
  shared_credentials_file = pathexpand("~/.aliyun/config.json")
  profile                 = "default"
}

# 仅在使用已有集群时通过 data source 获取信息
data "alicloud_cs_clusters" "this" {
  count      = var.create_ack ? 0 : 1
  name_regex = "^${var.cluster_name}$"
}

locals {
  cluster_id = var.create_ack ? module.ack[0].cluster_id : data.alicloud_cs_clusters.this[0].clusters[0].id
}

# 获取集群连接凭据
data "alicloud_cs_cluster_credential" "this" {
  count                    = var.deploy_app ? 1 : 0
  cluster_id               = local.cluster_id
  temporary_duration_minutes = 480
  output_file              = "${path.module}/.kubeconfig"
}

provider "kubernetes" {
  config_path = fileexists("${path.module}/.kubeconfig") ? "${path.module}/.kubeconfig" : null
}

provider "helm" {
  kubernetes {
    config_path = fileexists("${path.module}/.kubeconfig") ? "${path.module}/.kubeconfig" : null
  }
}
