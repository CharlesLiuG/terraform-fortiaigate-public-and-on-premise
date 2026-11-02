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

locals {
  cluster_endpoint       = var.create_eks ? (length(module.eks) > 0 ? module.eks[0].cluster_endpoint : "") : (length(data.aws_eks_cluster.this) > 0 ? data.aws_eks_cluster.this[0].endpoint : "")
  cluster_ca_certificate = var.create_eks ? (length(module.eks) > 0 ? module.eks[0].cluster_ca_certificate : "") : (length(data.aws_eks_cluster.this) > 0 ? data.aws_eks_cluster.this[0].certificate_authority[0].data : "")
}

# 使用 exec 在每次调用时动态执行 `aws eks get-token`，获取未过期的短期 token。
# 这样可避免 data.aws_eks_cluster_auth 在 plan 阶段固化 token、在 apply 时已过期
# （15 分钟有效期）而导致 "the server has asked for the client to provide credentials"。
provider "kubernetes" {
  host                   = local.cluster_endpoint
  cluster_ca_certificate = local.cluster_ca_certificate != "" ? base64decode(local.cluster_ca_certificate) : ""

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.aws_region]
  }
}

provider "helm" {
  kubernetes {
    host                   = local.cluster_endpoint
    cluster_ca_certificate = local.cluster_ca_certificate != "" ? base64decode(local.cluster_ca_certificate) : ""

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.aws_region]
    }
  }
}
