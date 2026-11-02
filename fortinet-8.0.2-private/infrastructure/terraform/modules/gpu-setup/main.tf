###############################################################################
# GPU Setup 模块
# 在 GPU Worker 节点上安装:
#   1. NVIDIA GPU Driver 580
#   2. CUDA Toolkit 13.0
#   3. NVIDIA Container Toolkit（containerd 集成）
#   4. NVIDIA K8s Device Plugin（DaemonSet）
#   5. GPU 可用性验证
#
# 前置条件:
#   - Worker 节点已加入 K8S 集群
#   - Worker 节点有 NVIDIA GPU 硬件
#   - Worker 节点运行 Ubuntu 22.04/24.04
###############################################################################

terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# ============================================================
# 步骤 1: 在每个 GPU Worker 节点安装 NVIDIA Driver + CUDA
# ============================================================
resource "null_resource" "install_nvidia_driver" {
  count = length(var.gpu_worker_nodes)

  connection {
    type        = "ssh"
    host        = var.gpu_worker_nodes[count.index].host
    user        = var.gpu_worker_nodes[count.index].user
    private_key = var.ssh_private_key != "" ? var.ssh_private_key : null
    password    = var.ssh_password != "" ? var.ssh_password : null
    port        = var.ssh_port
    timeout     = "10m"
  }

  # 安装 NVIDIA Driver
  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo '>>> [GPU-Worker-${count.index + 1}] 检查/安装 NVIDIA Driver ${var.nvidia_driver_version}...'",

      # 检查是否已安装正确版本
      "if nvidia-smi 2>/dev/null | grep -q 'Driver Version: ${var.nvidia_driver_version}'; then",
      "  echo '  NVIDIA Driver ${var.nvidia_driver_version} 已安装，跳过'",
      "  exit 0",
      "fi",

      # 安装前置依赖
      "sudo apt-get update -qq",
      "sudo apt-get install -y -qq linux-headers-$(uname -r) build-essential dkms",

      # 添加 NVIDIA 驱动 PPA（Ubuntu）
      "sudo apt-get install -y -qq software-properties-common",
      "sudo add-apt-repository -y ppa:graphics-drivers/ppa 2>/dev/null || true",
      "sudo apt-get update -qq",

      # 安装指定版本驱动
      "echo '  安装 nvidia-driver-${var.nvidia_driver_version}-server...'",
      "sudo apt-get install -y -qq nvidia-driver-${var.nvidia_driver_version}-server",

      # 加载内核模块
      "sudo modprobe nvidia || true",

      "echo '  NVIDIA Driver ${var.nvidia_driver_version} 安装完成'",
    ]
  }

  # 安装 CUDA Toolkit
  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo '>>> [GPU-Worker-${count.index + 1}] 检查/安装 CUDA Toolkit ${var.cuda_version}...'",

      # 检查是否已安装
      "if nvcc --version 2>/dev/null | grep -q 'release ${var.cuda_version}' || /usr/local/cuda-${var.cuda_version}/bin/nvcc --version 2>/dev/null | grep -q 'release ${var.cuda_version}'; then",
      "  echo '  CUDA ${var.cuda_version} 已安装，跳过'",
      "  exit 0",
      "fi",

      # 添加 NVIDIA CUDA 仓库
      "DISTRO=$(. /etc/os-release && echo $ID$VERSION_ID | tr -d '.')",
      "ARCH=x86_64",

      # 下载并安装 CUDA keyring
      "wget -q https://developer.download.nvidia.com/compute/cuda/repos/$${DISTRO}/$${ARCH}/cuda-keyring_1.1-1_all.deb -O /tmp/cuda-keyring.deb",
      "sudo dpkg -i /tmp/cuda-keyring.deb",
      "sudo apt-get update -qq",

      # 安装 CUDA Toolkit
      "echo '  安装 cuda-toolkit-${var.cuda_package_version}...'",
      "sudo apt-get install -y -qq cuda-toolkit-${var.cuda_package_version}",

      # 配置环境变量
      "echo 'export PATH=/usr/local/cuda-${var.cuda_version}/bin:$PATH' | sudo tee /etc/profile.d/cuda.sh",
      "echo 'export LD_LIBRARY_PATH=/usr/local/cuda-${var.cuda_version}/lib64:$LD_LIBRARY_PATH' | sudo tee -a /etc/profile.d/cuda.sh",

      "echo '  CUDA Toolkit ${var.cuda_version} 安装完成'",
    ]
  }
}

# ============================================================
# 步骤 2: 安装 NVIDIA Container Toolkit（containerd 集成）
# ============================================================
resource "null_resource" "install_container_toolkit" {
  count      = length(var.gpu_worker_nodes)
  depends_on = [null_resource.install_nvidia_driver]

  connection {
    type        = "ssh"
    host        = var.gpu_worker_nodes[count.index].host
    user        = var.gpu_worker_nodes[count.index].user
    private_key = var.ssh_private_key != "" ? var.ssh_private_key : null
    password    = var.ssh_password != "" ? var.ssh_password : null
    port        = var.ssh_port
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo '>>> [GPU-Worker-${count.index + 1}] 安装 NVIDIA Container Toolkit...'",

      # 检查是否已安装
      "if nvidia-ctk --version 2>/dev/null; then",
      "  echo '  NVIDIA Container Toolkit 已安装'",
      "else",
      "  # 添加 NVIDIA Container Toolkit 仓库",
      "  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg --yes",
      "  echo \"deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] ${var.nvidia_container_toolkit_mirror} /\" | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list",
      "  sudo apt-get update -qq",
      "  sudo apt-get install -y -qq nvidia-container-toolkit",
      "fi",

      # 配置 containerd 使用 nvidia runtime
      "echo '  配置 containerd nvidia runtime...'",
      "sudo nvidia-ctk runtime configure --runtime=containerd",

      # 设置 nvidia 为默认 runtime（确保所有 GPU 容器自动使用）
      "sudo sed -i 's/default_runtime_name = \"runc\"/default_runtime_name = \"nvidia\"/' /etc/containerd/config.toml || true",

      # 重启 containerd 使配置生效
      "sudo systemctl restart containerd",
      "sleep 5",

      # 验证 runtime 配置
      "echo '  验证 containerd nvidia runtime...'",
      "sudo ctr --namespace k8s.io run --rm --gpus 0 --runtime io.containerd.runc.v2 ${var.cuda_test_image}:${var.cuda_version}.0-base-ubuntu22.04 gpu-test nvidia-smi 2>/dev/null || echo '  (容器验证将在 Device Plugin 部署后进行)'",

      "echo '  NVIDIA Container Toolkit 配置完成'",
    ]
  }
}

# ============================================================
# 步骤 3: 部署 NVIDIA Device Plugin（K8s DaemonSet）
# 使 K8s 识别 nvidia.com/gpu 资源
# ============================================================
resource "null_resource" "deploy_device_plugin" {
  depends_on = [null_resource.install_container_toolkit]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -e
      echo ">>> 部署 NVIDIA K8s Device Plugin ${var.nvidia_device_plugin_version}..."

      KUBECONFIG_ARGS=""
      if [ -n "${var.kubeconfig_path}" ]; then
        KUBECONFIG_ARGS="--kubeconfig ${var.kubeconfig_path}"
      fi
      if [ -n "${var.kubeconfig_context}" ]; then
        KUBECONFIG_ARGS="$KUBECONFIG_ARGS --context ${var.kubeconfig_context}"
      fi

      # 检查是否已部署
      if kubectl $KUBECONFIG_ARGS get daemonset -n kube-system nvidia-device-plugin-daemonset 2>/dev/null | grep -q "nvidia"; then
        echo "  NVIDIA Device Plugin 已存在，更新中..."
        kubectl $KUBECONFIG_ARGS delete daemonset -n kube-system nvidia-device-plugin-daemonset --ignore-not-found
        sleep 5
      fi

      # 部署 Device Plugin DaemonSet
      cat <<EOF | kubectl $KUBECONFIG_ARGS apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nvidia-device-plugin-daemonset
  namespace: kube-system
  labels:
    app: nvidia-device-plugin
spec:
  selector:
    matchLabels:
      app: nvidia-device-plugin
  updateStrategy:
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: nvidia-device-plugin
    spec:
      tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
      priorityClassName: system-node-critical
      containers:
      - name: nvidia-device-plugin-ctr
        image: ${var.nvidia_device_plugin_image}:${var.nvidia_device_plugin_version}
        env:
        - name: FAIL_ON_INIT_ERROR
          value: "false"
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop: ["ALL"]
        volumeMounts:
        - name: device-plugin
          mountPath: /var/lib/kubelet/device-plugins
      volumes:
      - name: device-plugin
        hostPath:
          path: /var/lib/kubelet/device-plugins
EOF

      echo "  等待 NVIDIA Device Plugin 就绪..."
      for i in $(seq 1 30); do
        READY=$(kubectl $KUBECONFIG_ARGS get pods -n kube-system -l app=nvidia-device-plugin --no-headers 2>/dev/null | grep -c "Running" || true)
        DESIRED=$(kubectl $KUBECONFIG_ARGS get daemonset -n kube-system nvidia-device-plugin-daemonset -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo "0")
        if [ "$READY" -ge "$DESIRED" ] && [ "$DESIRED" -gt 0 ]; then
          echo "  ✅ NVIDIA Device Plugin 就绪 ($READY/$DESIRED)"
          break
        fi
        echo "  等待中... ($READY/$DESIRED Ready)"
        sleep 10
      done

      echo "  NVIDIA Device Plugin 部署完成"
    EOT
  }
}

# ============================================================
# 步骤 4: GPU 可用性验证
# ============================================================
resource "null_resource" "gpu_validation" {
  depends_on = [null_resource.deploy_device_plugin]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -e
      echo ""
      echo "============================================================"
      echo "  GPU 部署验证"
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
      # 验证 1: 节点 GPU 资源已注册
      # ----------------------------------------------------------
      echo "▶ 验证 1: K8s 节点 GPU 资源"
      GPU_NODES=0
      TOTAL_GPUS=0

      for node in $(kubectl $KUBECONFIG_ARGS get nodes -o jsonpath='{.items[*].metadata.name}'); do
        GPU_CAP=$(kubectl $KUBECONFIG_ARGS get node $node -o jsonpath='{.status.capacity.nvidia\.com/gpu}' 2>/dev/null || echo "0")
        if [ "$GPU_CAP" != "0" ] && [ -n "$GPU_CAP" ]; then
          echo "    节点 $node: $GPU_CAP GPU(s)"
          GPU_NODES=$((GPU_NODES + 1))
          TOTAL_GPUS=$((TOTAL_GPUS + GPU_CAP))
        fi
      done

      if [ "$GPU_NODES" -ge 1 ]; then
        check_pass "检测到 $GPU_NODES 个 GPU 节点，共 $TOTAL_GPUS 块 GPU"
      else
        check_fail "未检测到任何 GPU 节点（nvidia.com/gpu 资源为 0）"
      fi
      echo ""

      # ----------------------------------------------------------
      # 验证 2: Device Plugin DaemonSet 状态
      # ----------------------------------------------------------
      echo "▶ 验证 2: NVIDIA Device Plugin 状态"
      DP_READY=$(kubectl $KUBECONFIG_ARGS get daemonset -n kube-system nvidia-device-plugin-daemonset -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
      DP_DESIRED=$(kubectl $KUBECONFIG_ARGS get daemonset -n kube-system nvidia-device-plugin-daemonset -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo "0")

      if [ "$DP_READY" -eq "$DP_DESIRED" ] && [ "$DP_DESIRED" -gt 0 ]; then
        check_pass "Device Plugin 全部就绪 ($DP_READY/$DP_DESIRED)"
      else
        check_fail "Device Plugin 未完全就绪 ($DP_READY/$DP_DESIRED)"
      fi
      echo ""

      # ----------------------------------------------------------
      # 验证 3: 运行 GPU 测试 Pod
      # ----------------------------------------------------------
      echo "▶ 验证 3: GPU 功能测试（运行 nvidia-smi Pod）"

      # 清理可能存在的旧测试 Pod
      kubectl $KUBECONFIG_ARGS delete pod gpu-test-pod -n default --ignore-not-found 2>/dev/null
      sleep 2

      # 创建测试 Pod
      cat <<EOF | kubectl $KUBECONFIG_ARGS apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: gpu-test-pod
  namespace: default
spec:
  restartPolicy: Never
  containers:
  - name: gpu-test
    image: ${var.cuda_test_image}:${var.cuda_version}.0-base-ubuntu22.04
    command: ["nvidia-smi"]
    resources:
      limits:
        nvidia.com/gpu: 1
EOF

      # 等待 Pod 完成
      echo "  等待 GPU 测试 Pod 运行..."
      POD_OK=false
      for i in $(seq 1 30); do
        STATUS=$(kubectl $KUBECONFIG_ARGS get pod gpu-test-pod -n default -o jsonpath='{.status.phase}' 2>/dev/null || echo "Pending")
        if [ "$STATUS" = "Succeeded" ]; then
          POD_OK=true
          break
        elif [ "$STATUS" = "Failed" ]; then
          break
        fi
        sleep 5
      done

      if [ "$POD_OK" = "true" ]; then
        echo ""
        echo "  --- nvidia-smi 输出 ---"
        kubectl $KUBECONFIG_ARGS logs gpu-test-pod -n default 2>/dev/null | head -30
        echo "  -----------------------"
        echo ""

        # 检查 Driver 版本
        DRIVER_VER=$(kubectl $KUBECONFIG_ARGS logs gpu-test-pod -n default 2>/dev/null | grep "Driver Version" | awk '{print $6}' || echo "unknown")
        CUDA_VER=$(kubectl $KUBECONFIG_ARGS logs gpu-test-pod -n default 2>/dev/null | grep "CUDA Version" | awk '{print $9}' || echo "unknown")

        if echo "$DRIVER_VER" | grep -q "^${var.nvidia_driver_version}"; then
          check_pass "NVIDIA Driver 版本: $DRIVER_VER (期望 ${var.nvidia_driver_version}.x)"
        else
          check_fail "NVIDIA Driver 版本不匹配: $DRIVER_VER (期望 ${var.nvidia_driver_version}.x)"
        fi

        if echo "$CUDA_VER" | grep -q "^${var.cuda_version}"; then
          check_pass "CUDA 版本: $CUDA_VER (期望 ${var.cuda_version})"
        else
          check_fail "CUDA 版本不匹配: $CUDA_VER (期望 ${var.cuda_version})"
        fi
      else
        check_fail "GPU 测试 Pod 运行失败 (状态: $STATUS)"
        echo "  Pod 事件:"
        kubectl $KUBECONFIG_ARGS describe pod gpu-test-pod -n default 2>/dev/null | grep -A 10 "Events:" || true
      fi

      # 清理测试 Pod
      kubectl $KUBECONFIG_ARGS delete pod gpu-test-pod -n default --ignore-not-found 2>/dev/null

      echo ""

      # ----------------------------------------------------------
      # 汇总
      # ----------------------------------------------------------
      echo "============================================================"
      echo "  GPU 验证结果: ✅ $PASS 通过 / ❌ $FAIL 失败"
      echo "============================================================"

      if [ "$FAIL" -gt 0 ]; then
        echo ""
        echo "⚠️  GPU 环境存在问题，Triton Inference Server 可能无法正常运行"
        echo "  请检查:"
        echo "    1. GPU 硬件是否被系统识别（lspci | grep NVIDIA）"
        echo "    2. NVIDIA Driver ${var.nvidia_driver_version} 是否正确安装（nvidia-smi）"
        echo "    3. CUDA ${var.cuda_version} 是否正确安装（nvcc --version）"
        echo "    4. containerd nvidia runtime 是否配置正确"
        echo ""
        exit 1
      fi

      echo ""
      echo "🎉 GPU 环境就绪！Worker 节点已具备 GPU 推理能力"
      echo "  - NVIDIA Driver: ${var.nvidia_driver_version}"
      echo "  - CUDA: ${var.cuda_version}"
      echo "  - nvidia.com/gpu 资源: 可调度"
      echo ""
    EOT
  }
}
