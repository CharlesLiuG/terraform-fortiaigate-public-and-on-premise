# ─────────────────────────────────────────────────────────────────────────────
# 可选: 创建 EKS 集群 + GPU Node Group (自动创建 VPC/Subnet)
# ─────────────────────────────────────────────────────────────────────────────
module "eks" {
  count  = var.create_eks ? 1 : 0
  source = "./modules/eks"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  vpc_cidr        = var.vpc_cidr
  region          = var.aws_region
  instance_type   = var.gpu_instance_type
  desired_size    = var.gpu_node_group_desired
}

# ─────────────────────────────────────────────────────────────────────────────
# 可选: 创建 EFS 文件系统
# ─────────────────────────────────────────────────────────────────────────────
module "efs" {
  count  = var.create_efs ? 1 : 0
  source = "./modules/efs"

  vpc_id     = var.create_eks ? module.eks[0].vpc_id : data.aws_eks_cluster.this[0].vpc_config[0].vpc_id
  subnet_ids = var.create_eks ? module.eks[0].private_subnet_ids : data.aws_subnets.cluster[0].ids
  eks_security_group_id = var.create_eks ? module.eks[0].node_security_group_id : data.aws_eks_cluster.this[0].vpc_config[0].cluster_security_group_id
}

# 当使用已有 EKS 且需要创建 EFS 时，自动获取集群所在子网
data "aws_subnets" "cluster" {
  count = (!var.create_eks && var.create_efs) ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [data.aws_eks_cluster.this[0].vpc_config[0].vpc_id]
  }
  filter {
    name   = "map-public-ip-on-launch"
    values = ["false"]
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# 解析 EFS ID（从新建或已有）
# ─────────────────────────────────────────────────────────────────────────────
locals {
  efs_id = var.create_efs ? module.efs[0].efs_id : var.efs_id
}

# ─────────────────────────────────────────────────────────────────────────────
# OIDC / VPC / IAM (场景2/3: 已有集群时在根模块创建)
# ─────────────────────────────────────────────────────────────────────────────
data "tls_certificate" "eks" {
  count = (!var.create_eks && (var.install_aws_lbc || var.install_efs_csi_driver)) ? 1 : 0
  url   = data.aws_eks_cluster.this[0].identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  count           = (!var.create_eks && (var.install_aws_lbc || var.install_efs_csi_driver)) ? 1 : 0
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks[0].certificates[0].sha1_fingerprint]
  url             = data.aws_eks_cluster.this[0].identity[0].oidc[0].issuer
}

locals {
  # 统一 OIDC 信息（无论新建还是已有集群）
  oidc_provider     = var.create_eks ? replace(module.eks[0].oidc_provider_url, "https://", "") : (length(aws_iam_openid_connect_provider.eks) > 0 ? replace(aws_iam_openid_connect_provider.eks[0].url, "https://", "") : "")
  oidc_provider_arn = var.create_eks ? module.eks[0].oidc_provider_arn : (length(aws_iam_openid_connect_provider.eks) > 0 ? aws_iam_openid_connect_provider.eks[0].arn : "")
  cluster_vpc_id    = var.create_eks ? module.eks[0].vpc_id : data.aws_eks_cluster.this[0].vpc_config[0].vpc_id
  resolved_cluster_name = var.create_eks ? module.eks[0].cluster_name : var.cluster_name
}

# LBC IAM Role (场景2/3)
resource "aws_iam_policy" "lbc" {
  count  = (!var.create_eks && var.install_aws_lbc) ? 1 : 0
  name   = "${var.cluster_name}-AWSLoadBalancerControllerIAMPolicy"
  policy = file("${path.module}/modules/eks/lbc-iam-policy.json")
}

resource "aws_iam_role" "lbc" {
  count = (!var.create_eks && var.install_aws_lbc) ? 1 : 0
  name  = "${var.cluster_name}-aws-lbc-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Federated = local.oidc_provider_arn }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_provider}:aud" = "sts.amazonaws.com"
          "${local.oidc_provider}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lbc" {
  count      = (!var.create_eks && var.install_aws_lbc) ? 1 : 0
  policy_arn = aws_iam_policy.lbc[0].arn
  role       = aws_iam_role.lbc[0].name
}

# EFS CSI IAM Role (场景2/3)
resource "aws_iam_role" "efs_csi" {
  count = (!var.create_eks && var.install_efs_csi_driver) ? 1 : 0
  name  = "${var.cluster_name}-efs-csi-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Federated = local.oidc_provider_arn }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_provider}:aud" = "sts.amazonaws.com"
          "${local.oidc_provider}:sub" = "system:serviceaccount:kube-system:efs-csi-controller-sa"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "efs_csi" {
  count      = (!var.create_eks && var.install_efs_csi_driver) ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
  role       = aws_iam_role.efs_csi[0].name
}

locals {
  # 统一 role ARN（无论新建还是已有集群）
  lbc_role_arn     = var.create_eks ? module.eks[0].lbc_role_arn : (length(aws_iam_role.lbc) > 0 ? aws_iam_role.lbc[0].arn : "")
  efs_csi_role_arn = var.create_eks ? module.eks[0].efs_csi_role_arn : (length(aws_iam_role.efs_csi) > 0 ? aws_iam_role.efs_csi[0].arn : "")
}

# ─────────────────────────────────────────────────────────────────────────────
# GPU 节点自动发现
# 仅在 deploy_app = true 时执行（集群和节点必须已存在）
# ─────────────────────────────────────────────────────────────────────────────
variable "deploy_app" {
  description = "Set to true to deploy FortiAIGate app (requires EKS cluster and nodes to be running)"
  type        = bool
  default     = true
}

locals {
  cluster_name_resolved = var.create_eks ? var.cluster_name : var.cluster_name
}

data "aws_eks_node_groups" "all" {
  count        = var.deploy_app ? 1 : 0
  cluster_name = local.cluster_name_resolved
}

data "aws_eks_node_group" "gpu" {
  count           = var.deploy_app ? 1 : 0
  cluster_name    = local.cluster_name_resolved
  node_group_name = var.create_eks ? "${var.cluster_name}-gpu" : tolist(data.aws_eks_node_groups.all[0].names)[0]
}

data "aws_autoscaling_groups" "gpu_asg" {
  count = var.deploy_app ? 1 : 0
  filter {
    name   = "tag:eks:nodegroup-name"
    values = [data.aws_eks_node_group.gpu[0].node_group_name]
  }
  filter {
    name   = "tag:eks:cluster-name"
    values = [local.cluster_name_resolved]
  }
}

data "aws_autoscaling_group" "gpu" {
  count = var.deploy_app ? 1 : 0
  name  = data.aws_autoscaling_groups.gpu_asg[0].names[0]
}

data "aws_instances" "gpu_nodes" {
  count = var.deploy_app ? 1 : 0
  filter {
    name   = "tag:aws:autoscaling:groupName"
    values = [data.aws_autoscaling_group.gpu[0].name]
  }
  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}

data "aws_instance" "gpu_node" {
  for_each    = var.deploy_app ? toset(data.aws_instances.gpu_nodes[0].ids) : toset([])
  instance_id = each.value
}

# ─────────────────────────────────────────────────────────────────────────────
# License 文件与 GPU 节点绑定
# ─────────────────────────────────────────────────────────────────────────────
locals {
  license_dir   = "${path.module}/charts/files/licenses"
  license_files = sort(tolist(fileset(local.license_dir, "*.lic")))

  gpu_node_names = var.deploy_app ? sort([for inst in data.aws_instance.gpu_node : inst.private_dns]) : []

  node_license_map = {
    for i, node in local.gpu_node_names :
    node => "files/licenses/${local.license_files[i]}"
    if i < length(local.license_files)
  }

  gpu_node_name = var.gpu_node_name != "" ? var.gpu_node_name : (length(local.gpu_node_names) > 0 ? local.gpu_node_names[0] : "")
}

# ─────────────────────────────────────────────────────────────────────────────
# Namespace
# ─────────────────────────────────────────────────────────────────────────────
resource "kubernetes_namespace" "fortiaigate" {
  count = var.deploy_app ? 1 : 0
  metadata {
    name = var.namespace
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# EFS CSI Driver
# ─────────────────────────────────────────────────────────────────────────────
resource "helm_release" "efs_csi_driver" {
  count      = var.install_efs_csi_driver ? 1 : 0
  name       = "aws-efs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-efs-csi-driver/"
  chart      = "aws-efs-csi-driver"
  version    = "3.1.3"
  namespace  = "kube-system"

  set {
    name  = "controller.serviceAccount.create"
    value = "true"
  }
  set {
    name  = "controller.serviceAccount.name"
    value = "efs-csi-controller-sa"
  }
  set {
    name  = "controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = local.efs_csi_role_arn
  }

  depends_on = [module.eks, aws_iam_role_policy_attachment.efs_csi]
}

# ─────────────────────────────────────────────────────────────────────────────
# EFS StorageClasses
# ─────────────────────────────────────────────────────────────────────────────
resource "kubernetes_storage_class" "efs_sc" {
  count = (var.deploy_app && var.create_efs_storage_class) ? 1 : 0
  metadata { name = "efs-sc" }
  storage_provisioner    = "efs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "Immediate"
  allow_volume_expansion = true
  parameters = {
    provisioningMode = "efs-ap"
    fileSystemId     = local.efs_id
    directoryPerms   = "775"
    uid              = "10001"
    gid              = "10001"
  }
  mount_options = ["tls"]
  depends_on    = [kubernetes_namespace.fortiaigate, helm_release.efs_csi_driver]
}

resource "kubernetes_storage_class" "efs_sc_db" {
  count = (var.deploy_app && var.create_efs_storage_class) ? 1 : 0
  metadata { name = "efs-sc-db" }
  storage_provisioner    = "efs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "Immediate"
  allow_volume_expansion = true
  parameters = {
    provisioningMode = "efs-ap"
    fileSystemId     = local.efs_id
    directoryPerms   = "775"
    uid              = "1001"
    gid              = "1001"
  }
  mount_options = ["tls"]
  depends_on    = [kubernetes_namespace.fortiaigate, helm_release.efs_csi_driver]
}

# ─────────────────────────────────────────────────────────────────────────────
# AWS Load Balancer Controller
# ─────────────────────────────────────────────────────────────────────────────
resource "helm_release" "aws_lbc" {
  count      = var.install_aws_lbc ? 1 : 0
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.8.4"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = local.resolved_cluster_name
  }
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = local.lbc_role_arn
  }
  set {
    name  = "region"
    value = var.aws_region
  }
  set {
    name  = "vpcId"
    value = local.cluster_vpc_id
  }

  depends_on = [module.eks, aws_iam_role_policy_attachment.lbc]
}

# ─────────────────────────────────────────────────────────────────────────────
# NVIDIA Device Plugin
# ─────────────────────────────────────────────────────────────────────────────
resource "helm_release" "nvidia_device_plugin" {
  count      = var.install_nvidia_device_plugin ? 1 : 0
  name       = "nvidia-device-plugin"
  repository = "https://nvidia.github.io/k8s-device-plugin"
  chart      = "nvidia-device-plugin"
  version    = "0.17.0"
  namespace  = "kube-system"

  depends_on = [module.eks]
}

# ─────────────────────────────────────────────────────────────────────────────
# Helm Release
# ─────────────────────────────────────────────────────────────────────────────
resource "helm_release" "fortiaigate" {
  count     = var.deploy_app ? 1 : 0
  name      = var.helm_release_name
  namespace = var.namespace
  chart     = "${path.module}/charts"

  values = [file("${path.module}/charts/values.yaml")]

  # 动态注入所有 node:license 绑定
  dynamic "set" {
    for_each = local.node_license_map
    content {
      name  = "global.licenses.${replace(set.key, ".", "\\.")}"
      value = set.value
    }
  }

  set {
    name  = "ingress.certificateArn"
    value = var.certificate_arn
  }
  set {
    name  = "ingress.host"
    value = var.ingress_host
  }

  wait          = true
  wait_for_jobs = true
  timeout       = 900
  force_update  = true
  cleanup_on_fail = true

  # destroy 后强制清理所有资源，防止 EFS/CSI driver 被提前删导致卡住
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "Force deleting all pods in namespace ${self.namespace}..."
      kubectl delete pod --all -n ${self.namespace} --force --grace-period=0 2>/dev/null || true

      echo "Force deleting all PVCs in namespace ${self.namespace}..."
      kubectl delete pvc --all -n ${self.namespace} --force --grace-period=0 2>/dev/null || true

      echo "Waiting for PVCs to terminate..."
      for i in $(seq 1 24); do
        PVC_COUNT=$(kubectl get pvc -n ${self.namespace} --no-headers 2>/dev/null | wc -l)
        if [ "$PVC_COUNT" -eq 0 ]; then
          echo "All PVCs deleted."
          break
        fi
        if [ "$i" -eq 12 ]; then
          echo "Forcing finalizer removal on PVCs..."
          kubectl get pvc -n ${self.namespace} -o name 2>/dev/null | xargs -I {} kubectl patch {} -n ${self.namespace} -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
        fi
        echo "Still $PVC_COUNT PVC(s) remaining, waiting... ($i/24)"
        sleep 5
      done

      echo "Cleaning up bound PVs..."
      kubectl get pv -o json 2>/dev/null | \
        jq -r '.items[] | select(.spec.claimRef.namespace=="${self.namespace}") | .metadata.name' | \
        xargs -I {} kubectl patch pv {} -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
      kubectl get pv -o json 2>/dev/null | \
        jq -r '.items[] | select(.spec.claimRef.namespace=="${self.namespace}") | .metadata.name' | \
        xargs -I {} kubectl delete pv {} --force --grace-period=0 2>/dev/null || true

      echo "Cleanup complete."
    EOT
  }

  depends_on = [
    module.efs,
    kubernetes_storage_class.efs_sc,
    kubernetes_storage_class.efs_sc_db,
    helm_release.aws_lbc,
    helm_release.nvidia_device_plugin,
  ]
}
