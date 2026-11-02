#!/usr/bin/env bash
###############################################################################
# FortiAIGate 私有化环境 - 分阶段部署脚本
#
# 解决问题：
#   全新环境（deploy_k8s_cluster=true）第一次部署时，kubernetes/helm
#   provider 需要读取 ~/.kube/config，但该文件要等 K8S 集群搭建完成、
#   由 module.k8s_cluster 拉取后才存在。Terraform 的 provider 无法依赖
#   同一次 apply 中才生成的资源，因此必须分两阶段执行：
#
#     阶段1: terraform apply -target=module.k8s_cluster  → 生成 kubeconfig
#     阶段2: terraform apply                              → 部署集群内资源
#
# 本脚本自动完成上述流程：
#   - 若 deploy_k8s_cluster=true 且 kubeconfig 不存在 → 自动走两阶段
#   - 否则（连接已有集群 / kubeconfig 已存在）        → 直接单阶段 apply
#
# 用法：
#   ./deploy.sh              # 交互式部署（每阶段前需确认）
#   ./deploy.sh -auto        # 自动批准（跳过确认，等价于 -auto-approve）
#   ./deploy.sh -plan        # 仅预览计划，不实际部署
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ---------- 参数解析 ----------
AUTO_APPROVE=""
PLAN_ONLY="false"
for arg in "$@"; do
  case "$arg" in
    -auto|--auto|-auto-approve|--auto-approve) AUTO_APPROVE="-auto-approve" ;;
    -plan|--plan) PLAN_ONLY="true" ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^#//'
      exit 0
      ;;
    *) echo "未知参数: $arg（可用: -auto, -plan, -h）"; exit 1 ;;
  esac
done

# ---------- 工具函数 ----------
log()  { echo -e "\n\033[1;36m>>> $*\033[0m"; }
ok()   { echo -e "\033[1;32m  ✅ $*\033[0m"; }
warn() { echo -e "\033[1;33m  ⚠️  $*\033[0m"; }
err()  { echo -e "\033[1;31m  ❌ $*\033[0m"; }

# ---------- 读取 tfvars 关键变量 ----------
# 从 terraform.tfvars 提取 deploy_k8s_cluster 与 kubeconfig_path
TFVARS_FILE="terraform.tfvars"
if [ ! -f "$TFVARS_FILE" ]; then
  err "未找到 $TFVARS_FILE，请先复制 terraform.tfvars.example 并配置"
  exit 1
fi

# 解析 deploy_k8s_cluster（默认为 true，与 variables.tf 一致）
DEPLOY_K8S="$(grep -E '^\s*deploy_k8s_cluster\s*=' "$TFVARS_FILE" | tail -1 | sed -E 's/.*=\s*//; s/\s+#.*//; s/\s//g' || true)"
DEPLOY_K8S="${DEPLOY_K8S:-true}"

# 解析 kubeconfig_path（默认为 ~/.kube/config）
KCFG_RAW="$(grep -E '^\s*kubeconfig_path\s*=' "$TFVARS_FILE" | tail -1 | sed -E 's/.*=\s*//; s/\s+#.*//; s/"//g; s/\s//g' || true)"
KCFG_RAW="${KCFG_RAW:-~/.kube/config}"
# 展开 ~ 为 $HOME
KCFG_PATH="${KCFG_RAW/#\~/$HOME}"

log "部署配置检测"
echo "  deploy_k8s_cluster = $DEPLOY_K8S"
echo "  kubeconfig_path    = $KCFG_PATH"

# ---------- terraform init ----------
log "terraform init"
terraform init -input=false

# ---------- 决策：是否需要两阶段 ----------
NEED_TWO_PHASE="false"
if [ "$DEPLOY_K8S" = "true" ] && [ ! -f "$KCFG_PATH" ]; then
  NEED_TWO_PHASE="true"
  warn "全新环境：kubeconfig ($KCFG_PATH) 尚不存在，将执行两阶段部署"
else
  ok "kubeconfig 已存在或使用已有集群，执行单阶段部署"
fi

# ---------- 仅预览 ----------
if [ "$PLAN_ONLY" = "true" ]; then
  if [ "$NEED_TWO_PHASE" = "true" ]; then
    log "阶段1 计划预览：terraform plan -target=module.k8s_cluster"
    terraform plan -target=module.k8s_cluster -input=false
    warn "阶段2 计划无法在集群搭建前预览（provider 需要 kubeconfig）。集群部署完成后再运行 './deploy.sh -plan' 查看完整计划。"
  else
    log "计划预览：terraform plan"
    terraform plan -input=false
  fi
  exit 0
fi

# ---------- 执行部署 ----------
if [ "$NEED_TWO_PHASE" = "true" ]; then
  log "阶段 1/2：部署 K8S 集群（生成 kubeconfig）"
  terraform apply -target=module.k8s_cluster -input=false $AUTO_APPROVE

  # 校验 kubeconfig 是否已生成
  if [ ! -f "$KCFG_PATH" ]; then
    err "阶段1 完成但未找到 kubeconfig ($KCFG_PATH)，请检查 module.k8s_cluster 的 fetch_kubeconfig 输出"
    exit 1
  fi
  ok "kubeconfig 已生成：$KCFG_PATH"

  # 快速连通性检查（非阻断）
  if command -v kubectl >/dev/null 2>&1; then
    log "集群连通性检查：kubectl get nodes"
    kubectl --kubeconfig "$KCFG_PATH" get nodes -o wide || warn "kubectl 暂时无法连接，继续尝试阶段2"
  fi

  log "阶段 2/2：部署集群内资源（NFS / Ingress / GPU / 验证）"
  terraform apply -input=false $AUTO_APPROVE
else
  log "单阶段部署：terraform apply"
  terraform apply -input=false $AUTO_APPROVE
fi

log "部署完成 🎉"
echo "  后续可通过设置 deploy_fortiaigate=true 并重新运行 ./deploy.sh 部署 FortiAIGate 应用"
