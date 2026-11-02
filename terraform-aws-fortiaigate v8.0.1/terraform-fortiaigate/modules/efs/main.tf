variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }
variable "eks_security_group_id" { type = string }

resource "aws_security_group" "efs" {
  name_prefix = "fortiaigate-efs-"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [var.eks_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_efs_file_system" "this" {
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  encrypted        = true

  tags = { Name = "fortiaigate" }
}

resource "aws_efs_mount_target" "this" {
  count           = length(var.subnet_ids)
  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = var.subnet_ids[count.index]
  security_groups = [aws_security_group.efs.id]
}

output "efs_id" {
  value = aws_efs_file_system.this.id
}
