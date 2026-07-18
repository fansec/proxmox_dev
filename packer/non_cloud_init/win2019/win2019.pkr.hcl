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
  description = "Proxmox Server IP Address or Hostname"
  default     = ""
}

variable "proxmox_api_user" {
  type        = string
  description = "Proxmox Username"
  default     = ""
}

variable "proxmox_api_password" {
  type        = string
  description = "Proxmox Password"
  default     = ""
  sensitive   = true
}

variable "proxmox_node" {
  type        = string
  description = "Node in Proxmox Instance"
  default     = ""
}

variable "proxmox_storage" {
  type        = string
  description = "Storage to Reference"
  default     = ""
}

###############
# VM VARIABLES
###############

variable "vm_name" {
  type        = string
  description = "Name of VM Template"
  default     = ""
}

variable "os" {
  type        = string
  description = "VM Guest OS Type"
  default     = "win10"
}

variable "cores" {
  type        = string
  description = " How many CPU cores to give the virtual machine. Defaults to 1"
}

variable "cpu_type" {
  type        = string
  description = "The CPU type to emulate. See the Proxmox API documentation for the complete list of accepted values. For best performance, set this to host. Defaults to kvm64"
}

variable "sockets" {
  type        = string
  description = "How many CPU sockets to give the virtual machine. Defaults to 1"
}

variable "memory" {
  type        = string
  description = "Amount of RAM for VM"
}

variable "vm_cdrom_type" {
  type        = string
  description = "CDROM Type for VM"
  default     = ""
}

variable "disk_format" {
  type    = string
  description = "The format of the file backing the disk. Can be raw, cow, qcow, qed, qcow2, vmdk or cloop. Defaults to raw"
  default = ""
}

variable "disk_size" {
  type        = string
  description = "The size of the disk, including a unit suffix, such as 10G to indicate 10 gigabytes."
}

variable "disk_storage_pool" {
  type    = string
  description = "Name of the Proxmox storage pool to store the virtual machine disk on"
}

variable "vm_network" {
  type        = string
  description = "Desired Virtual Network to Connect VM To"
  default     = "vmbr0"
}

variable "bridge" {
  type        = string
  description = "Required. Which Proxmox bridge to attach the adapter to."
  default     = ""
}

variable "firewall" {
  type        = string
  description = "If the interface should be protected by the firewall. Defaults to false"
}

variable "vlan_tag" {
  type        = string
  description = "If the adapter should tag packets. Defaults to no tagging"
  default     = ""
}

variable "builder_username" {
  type        = string
  description = "VM Guest Username to Build With"
  default     = ""
}

variable "builder_password" {
  type        = string
  description = "VM Guest User's Password to Authenticate With"
  default     = ""
}

variable "iso_file" {
  type        = string
  description = "Path to Windows ISO"
  default     = ""
}

variable "template_description" {
  type        = string
  description = "Notes for VM Template"
  default     = "Windows 2019 Pro Template"
}

variable "template_name" {
  type        = string
  description = "Name of the template. Defaults to the generated name used during creation"
}

variable "iso_storage_pool" {
  type        = string
  description = "Proxmox storage pool onto which to upload the ISO file."
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
    insecure_skip_tls_verify = true
    
    # General Settings
    template_name            = var.template_name
    vm_name                  = var.vm_name
    vm_id                    = "122" 

    # VM Configuration Settings
    os                       = var.os
    sockets                  = var.sockets
    cores                    = var.cores
    cpu_type                 = var.cpu_type
    memory                   = var.memory
    iso_storage_pool         = var.iso_storage_pool
    scsi_controller          = "virtio-scsi-single"
    iso_file                 = var.iso_file

    network_adapters {
          bridge    = var.bridge
          firewall  = var.firewall
          model     = "rtl8139"
          vlan_tag  = var.vlan_tag
      }
    
    disks {
          disk_size    = var.disk_size
          format       = var.disk_format
          storage_pool = var.disk_storage_pool
          type         = "ide"
      }
    
    efi_config {
          efi_storage_pool  = "local-lvm"
          efi_type          = "4m"
          pre_enrolled_keys = true
      }
    
    additional_iso_files {
          unmount          = true
          device           = "ide3"
          #ide2 is used by Windows ISO
          iso_storage_pool = var.iso_storage_pool
          cd_files         = ["mount/autounattend.xml", "mount/WinRM-Config.ps1", "mount/Install-Agent.ps1"]
          cd_label         = "cidata"
    }
    
    additional_iso_files {
            unmount          = true
            device           = "sata1"
            iso_storage_pool = "storage"
            iso_file         = "storage:iso/quemu_agent.iso"
      }

    winrm_username           = var.builder_username
    winrm_password           = var.builder_password
    communicator             = "winrm"
    winrm_insecure           = true
    winrm_use_ntlm           = true
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
            "Install-WindowsFeature RSAT-ADLDS"
        ]
        }

  provisioner "windows-update" {
        search_criteria = "IsInstalled=0"  # Install updates that are not already installed
        filters = [
            "exclude:$_.Title -like '*Preview*'",
            "include:$true"
            ]
    }

  provisioner "windows-shell" {
    inline = ["shutdown /s /t 5 /f /d p:4:1 /c \"Packer Shutdown\""]
  }
}
