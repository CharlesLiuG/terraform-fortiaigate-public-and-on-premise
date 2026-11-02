#!/usr/bin/env bash
# deploy.sh – FortiAIGate 一键部署
# 用法: ./deploy.sh [plan|apply|destroy]
set -euo pipefail

ACTION=${1:-plan}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

for bin in terraform aws kubectl; do
  command -v "$bin" &>/dev/null || { echo "ERROR: $bin not found"; exit 1; }
done

[[ -f "$SCRIPT_DIR/terraform.tfvars" ]] || {
  echo "ERROR: terraform.tfvars not found. cp terraform.tfvars.example terraform.tfvars"
  exit 1
}

# 读取配置
CLUSTER=$(grep 'cluster_name' "$SCRIPT_DIR/terraform.tfvars" | head -1 | awk -F'"' '{print $2}')
REGION=$(grep 'aws_region' "$SCRIPT_DIR/terraform.tfvars" 2>/dev/null | awk -F'"' '{print $2}')
REGION=${REGION:-ap-northeast-1}
CREATE_EKS=$(grep 'create_eks' "$SCRIPT_DIR/terraform.tfvars" | awk '{print $NF}')

echo ">> Configuration:"
echo "   Cluster: $CLUSTER"
echo "   Region:  $REGION"
echo "   Create EKS: $CREATE_EKS"
echo ""

# 如果使用已有集群，进行前置检查
if [[ "$CREATE_EKS" == "false" ]]; then
  echo ">> Updating kubeconfig for existing cluster..."
  aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION"

  echo ">> Checking EKS worker nodes..."
  READY=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready" || true)
  [[ "$READY" -gt 0 ]] || { echo "ERROR: No Ready worker nodes found."; exit 1; }
  echo "   Found $READY Ready node(s)."

  echo ">> Checking aws-load-balancer-controller..."
  kubectl get deployment aws-load-balancer-controller -n kube-system &>/dev/null || {
    echo "ERROR: aws-load-balancer-controller not found in kube-system."
    exit 1
  }

  echo ">> Checking aws-efs-csi-driver..."
  kubectl get daemonset efs-csi-node -n kube-system &>/dev/null || {
    echo "ERROR: efs-csi-node daemonset not found."
    exit 1
  }
fi

cd "$SCRIPT_DIR"
terraform init -upgrade

case "$ACTION" in
  plan)    terraform plan -out=tfplan ;;
  apply)
    terraform apply -auto-approve
    echo ""
    # 部署后更新 kubeconfig（如果是新建集群）
    if [[ "$CREATE_EKS" == "true" ]]; then
      aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION"
    fi
    echo "✅ Deploy complete."
    echo ""
    echo "GPU Node: $(terraform output -raw gpu_node_name 2>/dev/null || echo 'N/A')"
    echo ""
    echo "ALB DNS:"
    kubectl get ingress -n fortiaigate -o jsonpath='{.items[*].status.loadBalancer.ingress[*].hostname}' 2>/dev/null || true
    echo ""
    ;;
  destroy)
    read -r -p "⚠️  Destroy all resources? Type 'yes': " c
    [[ "$c" == "yes" ]] && terraform destroy -auto-approve || echo "Aborted."
    ;;
  *)       echo "Usage: $0 [plan|apply|destroy]"; exit 1 ;;
esac
