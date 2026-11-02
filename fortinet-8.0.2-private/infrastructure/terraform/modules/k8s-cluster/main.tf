###############################################################################
# K8S 集群部署模块
# 使用 kubeadm 部署私有化 Kubernetes 集群
# 默认 1 Master + 1 Worker，支持扩展 N 个 Worker Node
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
# Master 节点初始化
# ============================================================
resource "null_resource" "master_init" {
  connection {
    type        = "ssh"
    host        = var.master_node.host
    user        = var.master_node.user
    private_key = var.ssh_private_key != "" ? var.ssh_private_key : null
    password    = var.ssh_password != "" ? var.ssh_password : null
    port        = var.ssh_port
  }

  # 安装基础依赖
  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo '>>> 配置系统基础环境...'",
      "sudo hostnamectl set-hostname ${var.master_node.hostname}",
      # 关闭 swap
      "sudo swapoff -a",
      "sudo sed -i '/swap/d' /etc/fstab",
      # 加载内核模块
      "cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf",
      "overlay",
      "br_netfilter",
      "EOF",
      "sudo modprobe overlay",
      "sudo modprobe br_netfilter",
      # 内核参数
      "cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf",
      "net.bridge.bridge-nf-call-iptables  = 1",
      "net.bridge.bridge-nf-call-ip6tables = 1",
      "net.ipv4.ip_forward                 = 1",
      "EOF",
      "sudo sysctl --system",
    ]
  }

  # 安装容器运行时 (containerd)
  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo '>>> 安装 containerd...'",
      "sudo apt-get update -qq",
      "sudo apt-get install -y -qq apt-transport-https ca-certificates curl gnupg lsb-release sshpass",
      # 使用阿里云 Docker 源
      "curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg --yes",
      "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
      "sudo apt-get update -qq",
      "sudo apt-get install -y -qq containerd.io",
      # 配置 containerd 使用 systemd cgroup 和国内镜像
      "sudo mkdir -p /etc/containerd",
      "containerd config default | sudo tee /etc/containerd/config.toml > /dev/null",
      "sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml",
      "sudo sed -i 's|registry.k8s.io/pause:3.8|${var.pause_image}|' /etc/containerd/config.toml",
      "sudo sed -i 's|registry.k8s.io/pause:3.9|${var.pause_image}|' /etc/containerd/config.toml",
      "sudo sed -i 's|registry.k8s.io/pause:3.10.2|${var.pause_image}|' /etc/containerd/config.toml",
      "sudo sed -i \"0,/config_path = ''/s|config_path = ''|config_path = '/etc/containerd/certs.d'|\" /etc/containerd/config.toml",
      "sudo mkdir -p /etc/containerd/certs.d/${var.private_registry}",
      "echo 'server = \"http://${var.private_registry}\"\n\n[host.\"http://${var.private_registry}\"]\n  capabilities = [\"pull\", \"resolve\", \"push\"]\n  skip_verify = true' | sudo tee /etc/containerd/certs.d/${var.private_registry}/hosts.toml",
      "sudo systemctl restart containerd",
      "sudo systemctl enable containerd",
    ]
  }

  # 安装 kubeadm/kubelet/kubectl
  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo '>>> 安装 kubeadm、kubelet、kubectl...'",
      # 使用阿里云 Kubernetes 源
      "sudo mkdir -p /etc/apt/keyrings",
      "curl -fsSL https://mirrors.aliyun.com/kubernetes-new/core/stable/${var.k8s_version_major}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg --yes",
      "echo \"deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://mirrors.aliyun.com/kubernetes-new/core/stable/${var.k8s_version_major}/deb/ /\" | sudo tee /etc/apt/sources.list.d/kubernetes.list",
      "sudo apt-get update -qq",
      "sudo apt-get install -y -qq kubelet kubeadm kubectl",
      "sudo apt-mark hold kubelet kubeadm kubectl",
      "sudo systemctl enable kubelet",
    ]
  }

  # 初始化 Master 节点
  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo '>>> 初始化 Kubernetes Master 节点...'",
      "if [ -f /etc/kubernetes/admin.conf ]; then echo '>>> kubeadm 已初始化，跳过 init'; else sudo kubeadm init --kubernetes-version=${var.k8s_version} --pod-network-cidr=${var.pod_network_cidr} --service-cidr=${var.service_cidr} --image-repository=${var.k8s_image_repository} --apiserver-advertise-address=${var.master_node.internal_ip != "" ? var.master_node.internal_ip : var.master_node.host} --apiserver-cert-extra-sans=${var.master_node.host} ${var.kubeadm_extra_args}; fi",
      # 配置 kubectl
      "mkdir -p $HOME/.kube",
      "sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config",
      "sudo chown $(id -u):$(id -g) $HOME/.kube/config",
      # 安装 CNI 网络插件 (Calico)
      "echo '>>> 安装 Calico 网络插件...'",
      "if kubectl get pods -n kube-system | grep -q calico; then echo '>>> Calico 已安装，跳过'; else wget -q https://gitee.com/mirrors/calico/raw/${var.calico_version}/manifests/calico.yaml -O /tmp/calico.yaml && sed -i 's?docker.io?${var.calico_image_mirror}?g' /tmp/calico.yaml && kubectl apply -f /tmp/calico.yaml; fi",
      # 生成 join 命令
      "echo '>>> 生成 Worker 加入命令...'",
      "kubeadm token create --print-join-command > /tmp/kubeadm_join_cmd.sh",
    ]
  }
}

# ============================================================
# Worker 节点加入集群（支持 N 个）
# ============================================================
resource "null_resource" "worker_nodes" {
  count      = length(var.worker_nodes)
  depends_on = [null_resource.master_init]

  connection {
    type        = "ssh"
    host        = var.worker_nodes[count.index].host
    user        = var.worker_nodes[count.index].user
    private_key = var.ssh_private_key != "" ? var.ssh_private_key : null
    password    = var.ssh_password != "" ? var.ssh_password : null
    port        = var.ssh_port
  }

  # 安装基础依赖
  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo '>>> [Worker-${count.index + 1}] 配置系统基础环境...'",
      "sudo hostnamectl set-hostname ${var.worker_nodes[count.index].hostname}",
      "sudo swapoff -a",
      "sudo sed -i '/swap/d' /etc/fstab",
      "cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf",
      "overlay",
      "br_netfilter",
      "EOF",
      "sudo modprobe overlay",
      "sudo modprobe br_netfilter",
      "cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf",
      "net.bridge.bridge-nf-call-iptables  = 1",
      "net.bridge.bridge-nf-call-ip6tables = 1",
      "net.ipv4.ip_forward                 = 1",
      "EOF",
      "sudo sysctl --system",
    ]
  }

  # 安装 containerd
  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo '>>> [Worker-${count.index + 1}] 安装 containerd...'",
      "sudo apt-get update -qq",
      "sudo apt-get install -y -qq apt-transport-https ca-certificates curl gnupg lsb-release",
      "curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg --yes",
      "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
      "sudo apt-get update -qq",
      "sudo apt-get install -y -qq containerd.io",
      "sudo mkdir -p /etc/containerd",
      "containerd config default | sudo tee /etc/containerd/config.toml > /dev/null",
      "sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml",
      "sudo sed -i 's|registry.k8s.io/pause:3.8|${var.pause_image}|' /etc/containerd/config.toml",
      "sudo sed -i 's|registry.k8s.io/pause:3.9|${var.pause_image}|' /etc/containerd/config.toml",
      "sudo sed -i 's|registry.k8s.io/pause:3.10.2|${var.pause_image}|' /etc/containerd/config.toml",
      "sudo sed -i \"0,/config_path = ''/s|config_path = ''|config_path = '/etc/containerd/certs.d'|\" /etc/containerd/config.toml",
      "sudo mkdir -p /etc/containerd/certs.d/${var.private_registry}",
      "echo 'server = \"http://${var.private_registry}\"\n\n[host.\"http://${var.private_registry}\"]\n  capabilities = [\"pull\", \"resolve\", \"push\"]\n  skip_verify = true' | sudo tee /etc/containerd/certs.d/${var.private_registry}/hosts.toml",
      "sudo systemctl restart containerd",
      "sudo systemctl enable containerd",
    ]
  }

  # 安装 kubeadm/kubelet
  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo '>>> [Worker-${count.index + 1}] 安装 kubeadm、kubelet...'",
      "sudo mkdir -p /etc/apt/keyrings",
      "curl -fsSL https://mirrors.aliyun.com/kubernetes-new/core/stable/${var.k8s_version_major}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg --yes",
      "echo \"deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://mirrors.aliyun.com/kubernetes-new/core/stable/${var.k8s_version_major}/deb/ /\" | sudo tee /etc/apt/sources.list.d/kubernetes.list",
      "sudo apt-get update -qq",
      "sudo apt-get install -y -qq kubelet kubeadm",
      "sudo apt-mark hold kubelet kubeadm",
      "sudo systemctl enable kubelet",
    ]
  }

  # 从 Master 获取 join 命令并加入集群
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = var.master_node.host
      user        = var.master_node.user
      private_key = var.ssh_private_key != "" ? var.ssh_private_key : null
      password    = var.ssh_password != "" ? var.ssh_password : null
      port        = var.ssh_port
    }
    inline = [
      "cat /tmp/kubeadm_join_cmd.sh",
    ]
  }
}

# 通过 Master 远程执行 join 命令到每个 Worker
resource "null_resource" "worker_join" {
  count      = length(var.worker_nodes)
  depends_on = [null_resource.worker_nodes]

  # 从 Master SSH 到 Worker 执行 join
  connection {
    type        = "ssh"
    host        = var.master_node.host
    user        = var.master_node.user
    private_key = var.ssh_private_key != "" ? var.ssh_private_key : null
    password    = var.ssh_password != "" ? var.ssh_password : null
    port        = var.ssh_port
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo '>>> 将 Worker-${count.index + 1} (${var.worker_nodes[count.index].host}) 加入集群...'",
      "JOIN_CMD=$(cat /tmp/kubeadm_join_cmd.sh)",
      "sshpass -p '${var.ssh_password}' ssh -o StrictHostKeyChecking=no -p ${var.ssh_port} ${var.worker_nodes[count.index].user}@${var.worker_nodes[count.index].internal_ip != "" ? var.worker_nodes[count.index].internal_ip : var.worker_nodes[count.index].host} \"sudo $JOIN_CMD\"",
    ]
  }
}

# ============================================================
# Worker 节点打标签
# ============================================================
resource "null_resource" "label_workers" {
  count      = length(var.worker_nodes)
  depends_on = [null_resource.worker_join]

  connection {
    type        = "ssh"
    host        = var.master_node.host
    user        = var.master_node.user
    private_key = var.ssh_private_key != "" ? var.ssh_private_key : null
    password    = var.ssh_password != "" ? var.ssh_password : null
    port        = var.ssh_port
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo '>>> 等待 Worker-${count.index + 1} 节点就绪...'",
      "for i in $(seq 1 60); do kubectl get node ${var.worker_nodes[count.index].hostname} 2>/dev/null && break || sleep 5; done",
      "kubectl label node ${var.worker_nodes[count.index].hostname} node-role.kubernetes.io/worker=worker --overwrite",
      var.worker_nodes[count.index].labels != "" ? "kubectl label node ${var.worker_nodes[count.index].hostname} ${var.worker_nodes[count.index].labels} --overwrite" : "echo 'No extra labels'",
    ]
  }
}

# ============================================================
# 拉取 kubeconfig 到本地
# ============================================================
resource "null_resource" "fetch_kubeconfig" {
  depends_on = [null_resource.label_workers]

  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ~/.kube
      sshpass -p '${var.ssh_password}' scp -o StrictHostKeyChecking=no -P ${var.ssh_port} ${var.master_node.user}@${var.master_node.host}:~/.kube/config ~/.kube/config
      sed -i 's|https://${var.master_node.internal_ip != "" ? var.master_node.internal_ip : "172.16.0.169"}:6443|https://${var.master_node.host}:6443|' ~/.kube/config
      echo ">>> kubeconfig 已保存到 ~/.kube/config"
    EOT
  }
}
