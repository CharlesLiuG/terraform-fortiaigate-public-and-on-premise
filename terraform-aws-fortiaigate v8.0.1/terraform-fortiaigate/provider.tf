terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# 仅在使用已有集群时通过 data source 获取信息
data "aws_eks_cluster" "this" {
  count = var.create_eks ? 0 : 1
  name  = var.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  count = var.deploy_app ? 1 : 0
  name  = var.create_eks ? module.eks[0].cluster_name : var.cluster_name
}

locals {
  cluster_endpoint       = var.create_eks ? (length(module.eks) > 0 ? module.eks[0].cluster_endpoint : "") : (length(data.aws_eks_cluster.this) > 0 ? data.aws_eks_cluster.this[0].endpoint : "")
  cluster_ca_certificate = var.create_eks ? (length(module.eks) > 0 ? module.eks[0].cluster_ca_certificate : "") : (length(data.aws_eks_cluster.this) > 0 ? data.aws_eks_cluster.this[0].certificate_authority[0].data : "")
  cluster_token          = length(data.aws_eks_cluster_auth.this) > 0 ? data.aws_eks_cluster_auth.this[0].token : ""
}

provider "kubernetes" {
  host                   = local.cluster_endpoint
  cluster_ca_certificate = local.cluster_ca_certificate != "" ? base64decode(local.cluster_ca_certificate) : ""
  token                  = local.cluster_token
}

provider "helm" {
  kubernetes {
    host                   = local.cluster_endpoint
    cluster_ca_certificate = local.cluster_ca_certificate != "" ? base64decode(local.cluster_ca_certificate) : ""
    token                  = local.cluster_token
  }
}
