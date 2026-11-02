###############################################################################
# 部署前验证模块 (Preflight Check)
# 验证基础设施满足 FortiAIGate 部署需求
#
# 检查项:
#   1. K8S 集群节点就绪
#   2. StorageClass 存在且可用（支持 RWX）
#   3. Nginx Ingress Controller 运行正常
#   4. 创建测试 PVC 验证存储可写
#   5. 创建测试 Ingress 验证路由可达
###############################################################################

terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

resource "null_resource" "preflight_check" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -e
      echo ""
      echo "============================================================"
      echo "  FortiAIGate 部署前验证 (Preflight Check)"
      echo "============================================================"
      echo ""

      KUBECONFIG_ARGS=""
      if [ -n "${var.kubeconfig_path}" ]; then
        KUBECONFIG_ARGS="--kubeconfig ${var.kubeconfig_path}"
      fi
      if [ -n "${var.kubeconfig_context}" ]; then
        KUBECONFIG_ARGS="$KUBECONFIG_ARGS --context ${var.kubeconfig_context}"
      fi

      PASS=0
      FAIL=0

      check_pass() {
        echo "  ✅ $1"
        PASS=$((PASS + 1))
      }

      check_fail() {
        echo "  ❌ $1"
        FAIL=$((FAIL + 1))
      }

      # ----------------------------------------------------------
      # 检查 1: 集群连接和节点状态
      # ----------------------------------------------------------
      echo "▶ 检查 1: Kubernetes 集群节点状态"
      NODE_COUNT=$(kubectl $KUBECONFIG_ARGS get nodes --no-headers 2>/dev/null | wc -l)
      READY_COUNT=$(kubectl $KUBECONFIG_ARGS get nodes --no-headers 2>/dev/null | grep -c " Ready" || true)

      if [ "$NODE_COUNT" -ge "${var.expected_nodes}" ]; then
        check_pass "节点数量满足: $NODE_COUNT 个节点（预期 >= ${var.expected_nodes}）"
      else
        check_fail "节点数量不足: $NODE_COUNT 个节点（预期 >= ${var.expected_nodes}）"
      fi

      if [ "$READY_COUNT" -eq "$NODE_COUNT" ]; then
        check_pass "所有节点状态 Ready ($READY_COUNT/$NODE_COUNT)"
      else
        check_fail "部分节点未就绪: $READY_COUNT/$NODE_COUNT Ready"
      fi

      echo ""
      kubectl $KUBECONFIG_ARGS get nodes -o wide
      echo ""

      # ----------------------------------------------------------
      # 检查 2: StorageClass 可用
      # ----------------------------------------------------------
      echo "▶ 检查 2: StorageClass 存储验证"
      SC_EXISTS=$(kubectl $KUBECONFIG_ARGS get sc ${var.storage_class_name} --no-headers 2>/dev/null | wc -l)

      if [ "$SC_EXISTS" -ge 1 ]; then
        check_pass "StorageClass '${var.storage_class_name}' 存在"
      else
        check_fail "StorageClass '${var.storage_class_name}' 不存在"
      fi

      # 创建测试 PVC 验证存储可用
      echo "  → 创建测试 PVC..."
      cat <<EOF | kubectl $KUBECONFIG_ARGS apply -f - 2>/dev/null
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: fortiaigate-preflight-test-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: ${var.storage_class_name}
  resources:
    requests:
      storage: 1Mi
EOF

      # 等待 PVC Bound（最多 60 秒）
      BOUND=false
      for i in $(seq 1 12); do
        STATUS=$(kubectl $KUBECONFIG_ARGS get pvc fortiaigate-preflight-test-pvc -n default -o jsonpath='{.status.phase}' 2>/dev/null || echo "Pending")
        if [ "$STATUS" = "Bound" ]; then
          BOUND=true
          break
        fi
        sleep 5
      done

      if [ "$BOUND" = "true" ]; then
        check_pass "测试 PVC 绑定成功 (ReadWriteMany)"
      else
        check_fail "测试 PVC 未能绑定 (当前状态: $STATUS)"
      fi

      # 清理测试 PVC
      kubectl $KUBECONFIG_ARGS delete pvc fortiaigate-preflight-test-pvc -n default --ignore-not-found 2>/dev/null
      echo ""

      # ----------------------------------------------------------
      # 检查 3: Nginx Ingress Controller 状态
      # ----------------------------------------------------------
      echo "▶ 检查 3: Nginx Ingress Controller 状态"
      INGRESS_PODS=$(kubectl $KUBECONFIG_ARGS get pods -n ingress-nginx -l app.kubernetes.io/component=controller --no-headers 2>/dev/null | grep -c "Running" || true)

      if [ "$INGRESS_PODS" -ge 1 ]; then
        check_pass "Nginx Ingress Controller 运行中 ($INGRESS_PODS 个 Pod)"
      else
        check_fail "Nginx Ingress Controller 未运行"
      fi

      # 检查 IngressClass
      IC_EXISTS=$(kubectl $KUBECONFIG_ARGS get ingressclass ${var.ingress_class_name} --no-headers 2>/dev/null | wc -l)
      if [ "$IC_EXISTS" -ge 1 ]; then
        check_pass "IngressClass '${var.ingress_class_name}' 已注册"
      else
        check_fail "IngressClass '${var.ingress_class_name}' 未找到"
      fi

      echo ""

      # ----------------------------------------------------------
      # 检查 4: 集群资源容量
      # ----------------------------------------------------------
      echo "▶ 检查 4: 集群资源概览"
      kubectl $KUBECONFIG_ARGS top nodes 2>/dev/null || echo "  (metrics-server 未安装，跳过资源用量检查)"
      echo ""

      # ----------------------------------------------------------
      # 检查 5: GPU 环境验证（如启用）
      # ----------------------------------------------------------
      if [ "${var.check_gpu}" = "true" ]; then
        echo "▶ 检查 5: GPU 环境状态"

        # 5a. NVIDIA Device Plugin DaemonSet
        DP_READY=$(kubectl $KUBECONFIG_ARGS get daemonset -n kube-system nvidia-device-plugin-daemonset -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
        DP_DESIRED=$(kubectl $KUBECONFIG_ARGS get daemonset -n kube-system nvidia-device-plugin-daemonset -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo "0")

        if [ "$DP_READY" -eq "$DP_DESIRED" ] && [ "$DP_DESIRED" -gt 0 ]; then
          check_pass "NVIDIA Device Plugin 就绪 ($DP_READY/$DP_DESIRED)"
        else
          check_fail "NVIDIA Device Plugin 异常 ($DP_READY/$DP_DESIRED)"
        fi

        # 5b. 节点 nvidia.com/gpu 资源
        GPU_TOTAL=0
        for node in $(kubectl $KUBECONFIG_ARGS get nodes -o jsonpath='{.items[*].metadata.name}'); do
          GPU_CAP=$(kubectl $KUBECONFIG_ARGS get node $node -o jsonpath='{.status.capacity.nvidia\.com/gpu}' 2>/dev/null || echo "0")
          if [ "$GPU_CAP" != "0" ] && [ -n "$GPU_CAP" ]; then
            GPU_TOTAL=$((GPU_TOTAL + GPU_CAP))
          fi
        done

        if [ "$GPU_TOTAL" -ge 1 ]; then
          check_pass "集群 GPU 总数: $GPU_TOTAL (nvidia.com/gpu)"
        else
          check_fail "集群未检测到可调度 GPU 资源"
        fi

        # 5c. GPU 功能验证（快速 nvidia-smi Pod）
        kubectl $KUBECONFIG_ARGS delete pod preflight-gpu-check -n default --ignore-not-found 2>/dev/null
        sleep 2

        cat <<EOF | kubectl $KUBECONFIG_ARGS apply -f - 2>/dev/null
apiVersion: v1
kind: Pod
metadata:
  name: preflight-gpu-check
  namespace: default
spec:
  restartPolicy: Never
  containers:
  - name: gpu-check
    image: nvcr.io/nvidia/cuda:${var.cuda_version}.0-base-ubuntu22.04
    command: ["nvidia-smi"]
    resources:
      limits:
        nvidia.com/gpu: 1
EOF

        GPU_POD_OK=false
        for i in $(seq 1 24); do
          POD_STATUS=$(kubectl $KUBECONFIG_ARGS get pod preflight-gpu-check -n default -o jsonpath='{.status.phase}' 2>/dev/null || echo "Pending")
          if [ "$POD_STATUS" = "Succeeded" ]; then
            GPU_POD_OK=true
            break
          elif [ "$POD_STATUS" = "Failed" ]; then
            break
          fi
          sleep 5
        done

        if [ "$GPU_POD_OK" = "true" ]; then
          # 验证 Driver 和 CUDA 版本
          DETECTED_DRIVER=$(kubectl $KUBECONFIG_ARGS logs preflight-gpu-check -n default 2>/dev/null | grep "Driver Version" | awk '{print $6}' || echo "unknown")
          DETECTED_CUDA=$(kubectl $KUBECONFIG_ARGS logs preflight-gpu-check -n default 2>/dev/null | grep "CUDA Version" | awk '{print $9}' || echo "unknown")

          if echo "$DETECTED_DRIVER" | grep -q "^${var.gpu_driver_version}"; then
            check_pass "GPU Driver 版本正确: $DETECTED_DRIVER (期望 ${var.gpu_driver_version}.x)"
          else
            check_fail "GPU Driver 版本不匹配: $DETECTED_DRIVER (期望 ${var.gpu_driver_version}.x)"
          fi

          if echo "$DETECTED_CUDA" | grep -q "^${var.cuda_version}"; then
            check_pass "CUDA 版本正确: $DETECTED_CUDA (期望 ${var.cuda_version})"
          else
            check_fail "CUDA 版本不匹配: $DETECTED_CUDA (期望 ${var.cuda_version})"
          fi

          check_pass "GPU Pod nvidia-smi 运行成功"
        else
          check_fail "GPU 测试 Pod 运行失败（状态: $POD_STATUS）"
        fi

        # 清理
        kubectl $KUBECONFIG_ARGS delete pod preflight-gpu-check -n default --ignore-not-found 2>/dev/null
        echo ""
      fi

      # ----------------------------------------------------------
      # 汇总
      # ----------------------------------------------------------
      echo "============================================================"
      echo "  验证结果: ✅ $PASS 通过 / ❌ $FAIL 失败"
      echo "============================================================"

      if [ "$FAIL" -gt 0 ]; then
        echo ""
        echo "⚠️  存在未通过的检查项，请修复后再部署 FortiAIGate"
        echo ""
        exit 1
      fi

      echo ""
      echo "🎉 所有检查通过！可以开始部署 FortiAIGate:"
      echo ""
      echo "  helm install fortiaigate ./fortiaigate \\"
      echo "    -f fortiaigate/values-private.yaml \\"
      echo "    -n fortiaigate --create-namespace"
      echo ""
    EOT
  }
}
