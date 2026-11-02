#!/usr/bin/env bash
# deploy.sh – FortiAIGate 一键部署 (阿里云版本)
# 用法: ./deploy.sh [plan|apply|destroy]
set -euo pipefail

ACTION=${1:-plan}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

for bin in terraform aliyun kubectl; do
  command -v "$bin" &>/dev/null || { echo "ERROR: $bin not found"; exit 1; }
done

[[ -f "$SCRIPT_DIR/terraform.tfvars" ]] || {
  echo "ERROR: terraform.tfvars not found. cp terraform.tfvars.example terraform.tfvars"
  exit 1
}

# 读取配置
CLUSTER=$(grep 'cluster_name' "$SCRIPT_DIR/terraform.tfvars" | head -1 | awk -F'"' '{print $2}')
REGION=$(grep '^region' "$SCRIPT_DIR/terraform.tfvars" 2>/dev/null | awk -F'"' '{print $2}')
REGION=${REGION:-cn-wulanchabu}
CREATE_ACK=$(grep 'create_ack' "$SCRIPT_DIR/terraform.tfvars" | awk '{print $NF}')

echo ">> Configuration:"
echo "   Cluster: $CLUSTER"
echo "   Region:  $REGION"
echo "   Create ACK: $CREATE_ACK"
echo ""

# 如果使用已有集群，进行前置检查
if [[ "$CREATE_ACK" == "false" ]]; then
  echo ">> Fetching kubeconfig for existing cluster..."
  CLUSTER_ID=$(aliyun cs DescribeClusters --region "$REGION" 2>/dev/null | jq -r ".[] | select(.name==\"$CLUSTER\") | .cluster_id")
  [[ -n "$CLUSTER_ID" ]] || { echo "ERROR: Cluster '$CLUSTER' not found in region $REGION"; exit 1; }

  aliyun cs GET "/k8s/$CLUSTER_ID/user_config" --region "$REGION" 2>/dev/null | jq -r '.config' > ~/.kube/config
  echo "   kubeconfig updated."

  echo ">> Checking ACK worker nodes..."
  READY=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready" || true)
  [[ "$READY" -gt 0 ]] || { echo "ERROR: No Ready worker nodes found."; exit 1; }
  echo "   Found $READY Ready node(s)."
fi

cd "$SCRIPT_DIR"
terraform init -upgrade

case "$ACTION" in
  plan)    terraform plan -out=tfplan ;;
  apply)
    terraform apply -auto-approve
    echo ""
    if [[ "$CREATE_ACK" == "true" ]]; then
      echo ">> Fetching kubeconfig for new cluster..."
      CLUSTER_ID=$(aliyun cs DescribeClusters --region "$REGION" 2>/dev/null | jq -r ".[] | select(.name==\"$CLUSTER\") | .cluster_id")
      aliyun cs GET "/k8s/$CLUSTER_ID/user_config" --region "$REGION" 2>/dev/null | jq -r '.config' > ~/.kube/config
    fi
    echo "✅ Deploy complete."
    echo ""
    echo "GPU Node: $(terraform output -raw gpu_node_name 2>/dev/null || echo 'N/A')"
    echo ""
    echo "Ingress Address:"
    kubectl get ingress -n fortiaigate -o jsonpath='{.items[*].status.loadBalancer.ingress[*].ip}' 2>/dev/null || true
    echo ""
    ;;
  destroy)
    read -r -p "⚠️  Destroy all resources? Type 'yes': " c
    [[ "$c" == "yes" ]] && terraform destroy -auto-approve || echo "Aborted."
    ;;
  *)       echo "Usage: $0 [plan|apply|destroy]"; exit 1 ;;
esac
