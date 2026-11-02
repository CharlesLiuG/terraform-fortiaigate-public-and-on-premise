# FortiAIGate Terraform Deployment

Automated deployment of FortiAIGate on AWS EKS with GPU nodes, EFS storage, and Helm chart.

## Architecture

- **EKS Cluster** with GPU node group (NVIDIA AMI, 300GB gp3 disk)
- **EFS** with 2 StorageClasses (dynamic Access Points for app and db)
- **Cluster Addons**: AWS Load Balancer Controller, EFS CSI Driver, NVIDIA Device Plugin
- **Helm Chart** deploying FortiAIGate services (Triton, scanners, API, WebUI, etc.)
- **ALB Ingress** with ACM certificate for HTTPS

## Prerequisites

- Terraform >= 1.5
- AWS CLI configured with appropriate permissions
- `kubectl` installed
- ACM certificate ARN for your domain
- License files (`.lic`) placed in `charts/files/licenses/`

### Required AWS Permissions

EKS, EC2, EFS, IAM, VPC, ACM (read), Auto Scaling, Elastic Load Balancing

## Deployment Scenarios

### Scenario 1: Full Deployment (New EKS + EFS + App)

```hcl
create_eks             = true
create_efs             = true
cluster_name           = "fortiaigate-cluster"
certificate_arn        = "arn:aws:acm:us-east-1:123456789012:certificate/xxx"
gpu_instance_type      = "g5.4xlarge"
```

### Scenario 2: Existing EKS + Existing EFS

```hcl
create_eks      = false
create_efs      = false
cluster_name    = "my-existing-cluster"
efs_id          = "fs-0123456789abcdef0"
certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/xxx"
```

### Scenario 3: Existing EKS + New EFS

```hcl
create_eks      = false
create_efs      = true
cluster_name    = "my-existing-cluster"
certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/xxx"
```

### Cluster Addons

All three scenarios default to installing cluster addons. If your existing cluster already has these components, disable them:

```hcl
install_efs_csi_driver        = false  # Skip if EFS CSI Driver already installed
install_aws_lbc               = false  # Skip if AWS Load Balancer Controller already installed
install_nvidia_device_plugin  = false  # Skip if NVIDIA Device Plugin already installed
```

## Quick Start

1. Copy and edit the variables file:

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

2. Place license files:

```bash
ls charts/files/licenses/
# FAIGCxxxxxxxx.lic  FAIGxxxxxxx.lic
```

3. Deploy (two-phase for new clusters):

```bash
terraform init

# Phase 1: Create infrastructure
terraform plan -var="deploy_app=false" --out=lg.out
terraform apply lg.out

# Update kubeconfig
aws eks update-kubeconfig --name fortiaigate-cluster --region us-east-1

# Wait for GPU nodes to be Ready
kubectl get nodes --watch

# Phase 2: Deploy application
terraform plan --out=lg.out
terraform apply lg.out
```

For existing clusters (Scenario 2 & 3), single-phase deployment works:

```bash
terraform init
terraform plan --out=lg.out
terraform apply lg.out
```

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `aws_region` | `us-east-1` | AWS region |
| `create_eks` | `false` | Create new EKS cluster |
| `create_efs` | `false` | Create new EFS file system |
| `cluster_name` | — | EKS cluster name (required) |
| `cluster_version` | `1.35` | Kubernetes version |
| `gpu_instance_type` | `g5.xlarge` | GPU instance type |
| `gpu_node_group_desired` | `1` | Number of GPU nodes |
| `vpc_cidr` | `10.0.0.0/16` | VPC CIDR (new cluster only) |
| `efs_id` | `""` | Existing EFS ID (required when `create_efs = false`) |
| `certificate_arn` | — | ACM certificate ARN (required) |
| `ingress_host` | `""` | ALB hostname |
| `gpu_node_name` | `""` | Manual GPU node name (auto-detected if empty) |
| `deploy_app` | `true` | Deploy Helm chart (set false for infra-only phase) |
| `install_efs_csi_driver` | `true` | Install AWS EFS CSI Driver |
| `install_aws_lbc` | `true` | Install AWS Load Balancer Controller |
| `install_nvidia_device_plugin` | `true` | Install NVIDIA Device Plugin |

## Outputs

| Output | Description |
|--------|-------------|
| `eks_cluster_endpoint` | EKS API server endpoint |
| `efs_id` | EFS file system ID |
| `gpu_node_name` | Detected GPU node hostname |
| `namespace` | Kubernetes namespace |
| `fortiaigate_helm_status` | Helm release status |

## License Binding

License files in `charts/files/licenses/*.lic` are automatically paired 1:1 with GPU nodes (sorted alphabetically). Ensure you have at least as many licenses as GPU nodes.

## Cleanup

```bash
terraform destroy
```

## Troubleshooting

- **Helm timeout**: Check pod status with `kubectl get pods -n fortiaigate` and events with `kubectl describe pod -n fortiaigate <pod>`
- **PVC Pending**: Verify EFS CSI driver is running: `kubectl get pods -n kube-system | grep efs`
- **GPU not detected**: Verify NVIDIA device plugin: `kubectl get pods -n kube-system | grep nvidia` and `kubectl describe node | grep nvidia`
- **Node disk full**: Default disk is 300GB gp3. Large Triton images need sufficient space.
- **Node not Ready**: GPU nodes take 3-5 min to initialize. Check with `kubectl get nodes`
- **ALB not created**: Verify LBC is running: `kubectl get pods -n kube-system | grep aws-load-balancer`
- **Destroy stuck**: If PVC stuck in Terminating, run `kubectl delete pvc --all -n fortiaigate --force --grace-period=0`
