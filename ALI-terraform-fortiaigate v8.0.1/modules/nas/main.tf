variable "vpc_id" { type = string }
variable "vswitch_id" { type = string }

resource "alicloud_nas_file_system" "this" {
  protocol_type = "NFS"
  storage_type  = "Capacity"
  description   = "fortiaigate"
  encrypt_type  = 1
}

resource "alicloud_nas_access_group" "this" {
  access_group_name = "FortiAIGateAG"
  access_group_type = "Vpc"
  file_system_type  = "standard"
  description       = "FortiAIGate"
}

resource "alicloud_nas_access_rule" "this" {
  access_group_name = alicloud_nas_access_group.this.access_group_name
  source_cidr_ip    = "0.0.0.0/0"
  rw_access_type    = "RDWR"
  user_access_type  = "no_squash"
  priority          = 1
}

resource "alicloud_nas_mount_target" "this" {
  file_system_id    = alicloud_nas_file_system.this.id
  access_group_name = alicloud_nas_access_group.this.access_group_name
  vswitch_id        = var.vswitch_id
  network_type      = "Vpc"
}

output "nas_id" {
  value = alicloud_nas_file_system.this.id
}

output "mount_target_domain" {
  value = alicloud_nas_mount_target.this.mount_target_domain
}
