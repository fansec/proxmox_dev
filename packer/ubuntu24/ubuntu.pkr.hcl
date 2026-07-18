packer {
  required_version = ">= 1.11.0"

  required_plugins {
    proxmox = {
      version = ">= 1.1.8"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

####################
# PROXMOX VARIABLES
####################

variable "proxmox_host" {
  type        = string
  description = "Proxmox server IP address or hostname (host:port)"
}

variable "proxmox_api_user" {
  type        = string
  description = "Proxmox API username"
}

variable "proxmox_api_password" {
  type        = string
  description = "Proxmox API password"
  sensitive   = true
}

variable "proxmox_node" {
  type        = string
  description = "Proxmox node to build the template on"
}

variable "proxmox_storage" {
  type        = string
  description = "Proxmox storage pool for the cloud-init drive"
  default     = "storage"
}

variable "insecure_skip_tls_verify" {
  type        = bool
  description = "Skip TLS certificate validation of the Proxmox API"
  default     = true
}

###############
# VM VARIABLES
###############

variable "vm_id" {
  type        = number
  description = "VM ID used during the build; must be unused on the node"
}

variable "vm_name" {
  type        = string
  description = "Name of the VM during the build"
}

variable "template_name" {
  type        = string
  description = "Name of the resulting template"
}

variable "template_description" {
  type        = string
  description = "Notes for the VM template"
  default     = "Ubuntu 24.04 Desktop Template"
}

variable "os" {
  type        = string
  description = "VM guest OS type"
  default     = "l26"
}

variable "cores" {
  type        = number
  description = "How many CPU cores to give the virtual machine"
  default     = 2
}

variable "sockets" {
  type        = number
  description = "How many CPU sockets to give the virtual machine"
  default     = 1
}

variable "cpu_type" {
  type        = string
  description = "The CPU type to emulate. Set to host for best performance"
  default     = "kvm64"
}

variable "memory" {
  type        = number
  description = "Amount of RAM for the VM in MiB"
  default     = 4096
}

variable "disk_size" {
  type        = string
  description = "Disk size including a unit suffix, e.g. 10G"
}

variable "disk_format" {
  type        = string
  description = "Format of the file backing the disk: raw, qcow2, vmdk, ..."
  default     = "raw"
}

variable "disk_storage_pool" {
  type        = string
  description = "Proxmox storage pool to store the virtual machine disk on"
}

variable "bridge" {
  type        = string
  description = "Proxmox bridge to attach the network adapter to"
  default     = "vmbr0"
}

variable "firewall" {
  type        = bool
  description = "Whether the network interface is protected by the firewall"
  default     = false
}

variable "iso_file" {
  type        = string
  description = "Path to the Ubuntu ISO on the Proxmox host, e.g. storage:iso/ubuntu.iso"
}

variable "iso_storage_pool" {
  type        = string
  description = "Proxmox storage pool onto which to upload the cloud-init ISO"
}

variable "builder_username" {
  type        = string
  description = "Guest username Packer connects with (must match user-data)"
}

variable "builder_password" {
  type        = string
  description = "Guest password Packer authenticates with"
  sensitive   = true
}

#########
# SOURCE
#########

source "proxmox-iso" "ubuntu" {

  # Proxmox Connection
  node                     = var.proxmox_node
  proxmox_url              = "https://${var.proxmox_host}/api2/json"
  username                 = var.proxmox_api_user
  password                 = var.proxmox_api_password
  insecure_skip_tls_verify = var.insecure_skip_tls_verify

  # General Settings
  vm_id                = var.vm_id
  vm_name              = var.vm_name
  template_name        = var.template_name
  template_description = var.template_description

  # VM Configuration Settings
  os              = var.os
  sockets         = var.sockets
  cores           = var.cores
  cpu_type        = var.cpu_type
  memory          = var.memory
  scsi_controller = "virtio-scsi-single"
  qemu_agent      = true

  # Cloud-Init Settings
  cloud_init              = true
  cloud_init_storage_pool = var.proxmox_storage

  # Boot / Install Media
  iso_file    = var.iso_file
  unmount_iso = true
  boot_wait   = "5s"

  boot_command = [
    "c<wait>",
    "linux /casper/vmlinuz",
    " net.ifnames=0",
    " autoinstall",
    "<enter><wait5s>",
    "initrd /casper/initrd",
    "<enter><wait5s>",
    "boot",
    "<enter><wait5s>",
  ]

  # Autoinstall seed ISO (ide2 is used by the Ubuntu ISO)
  additional_iso_files {
    unmount          = true
    device           = "ide3"
    iso_storage_pool = var.iso_storage_pool
    cd_files         = ["data/meta-data", "data/user-data"]
    cd_label         = "cidata"
  }

  disks {
    disk_size    = var.disk_size
    format       = var.disk_format
    storage_pool = var.disk_storage_pool
    type         = "virtio"
  }

  network_adapters {
    model    = "virtio"
    bridge   = var.bridge
    firewall = var.firewall
  }

  # Communicator
  communicator = "ssh"
  ssh_username = var.builder_username
  ssh_password = var.builder_password
  ssh_port     = 22
  ssh_timeout  = "60m"
}

########
# BUILD
########

build {
  sources = ["source.proxmox-iso.ubuntu"]

  provisioner "shell" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
      "sudo rm -f /etc/cloud/cloud.cfg.d/99-installer.cfg",
      "sudo rm -f /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg",
      "sudo cloud-init clean",
      "sudo rm -f /etc/ssh/ssh_host_*",
      "sudo truncate -s 0 /etc/machine-id",
      "sudo apt -y autoremove --purge",
      "sudo apt -y clean",
      "sudo apt -y autoclean",
      "sudo sync",
    ]
  }
}
