packer {
  required_version = ">= 1.11.0"

  required_plugins {
    proxmox = {
      version = ">= 1.1.8"
      source  = "github.com/hashicorp/proxmox"
    }

    windows-update = {
      version = "0.16.7"
      source  = "github.com/rgl/windows-update"
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
  description = "Proxmox storage pool for the EFI and cloud-init drives"
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
  default     = "Windows Server 2019 Template"
}

variable "os" {
  type        = string
  description = "VM guest OS type"
  default     = "win10"
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
  description = "Disk size including a unit suffix, e.g. 30G"
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

variable "vlan_tag" {
  type        = string
  description = "VLAN tag for the adapter. Defaults to no tagging"
  default     = ""
}

variable "iso_file" {
  type        = string
  description = "Path to the Windows ISO on the Proxmox host, e.g. storage:iso/win2019.iso"
}

variable "iso_storage_pool" {
  type        = string
  description = "Proxmox storage pool onto which to upload the provisioning ISO"
}

variable "agent_iso_file" {
  type        = string
  description = "Path to the ISO with the QEMU guest agent / VirtIO drivers"
  default     = "storage:iso/quemu_agent.iso"
}

variable "builder_username" {
  type        = string
  description = "Guest username Packer connects with (must match autounattend.xml)"
}

variable "builder_password" {
  type        = string
  description = "Guest password Packer authenticates with"
  sensitive   = true
}

#########
# SOURCE
#########

source "proxmox-iso" "win2019" {

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

  # Cloud-Init Settings
  cloud_init              = true
  cloud_init_storage_pool = var.proxmox_storage

  # Boot / Install Media
  iso_storage_pool = var.iso_storage_pool
  iso_file         = var.iso_file
  unmount_iso      = true

  network_adapters {
    bridge   = var.bridge
    firewall = var.firewall
    model    = "rtl8139"
    vlan_tag = var.vlan_tag
  }

  disks {
    disk_size    = var.disk_size
    format       = var.disk_format
    storage_pool = var.disk_storage_pool
    type         = "ide"
  }

  efi_config {
    efi_storage_pool  = var.proxmox_storage
    efi_type          = "4m"
    pre_enrolled_keys = true
  }

  # Provisioning files (ide2 is used by the Windows ISO)
  additional_iso_files {
    unmount          = true
    device           = "ide3"
    iso_storage_pool = var.iso_storage_pool
    cd_label         = "cidata"
    cd_files = [
      "mount/autounattend.xml",
      "mount/WinRM-Config.ps1",
      "mount/Install-Agent.ps1",
      "mount/cloudbase/cloudbase.ps1",
      "mount/cloudbase/cloudbase-init.conf",
    ]
  }

  additional_iso_files {
    unmount          = true
    device           = "sata1"
    iso_storage_pool = var.proxmox_storage
    iso_file         = var.agent_iso_file
  }

  # Communicator
  communicator   = "winrm"
  winrm_username = var.builder_username
  winrm_password = var.builder_password
  winrm_insecure = true
  winrm_use_ntlm = true
  winrm_timeout  = "60m"
}

########
# BUILD
########

build {
  sources = ["source.proxmox-iso.win2019"]

  provisioner "powershell" {
    inline = [
      "Install-WindowsFeature AD-Domain-Services",
      "Install-WindowsFeature RSAT-AD-AdminCenter",
      "Install-WindowsFeature RSAT-ADDS-Tools",
      "Install-WindowsFeature RSAT-ADLDS",
    ]
  }

  #provisioner "windows-update" {
  #  search_criteria = "IsInstalled=0" # Install updates that are not already installed
  #  filters = [
  #    "exclude:$_.Title -like '*Preview*'",
  #    "include:$true",
  #  ]
  #}

  provisioner "windows-shell" {
    inline = ["shutdown /s /t 5 /f /d p:4:1 /c \"Packer Shutdown\""]
  }
}
