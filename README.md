# Windows 10 Pro Template Build for Proxmox

This repository contains configuration files for building a Windows 10 Pro VM template using Packer on a Proxmox server. The build automates the Windows installation and configuration process.

## Requirements

- **Packer**: Version 1.11.0 or higher
- **Proxmox**: Proxmox VE with API access
- **Proxmox Plugins**: `proxmox` (version >=1.1.8) and `windows-update` (version >=0.16.7)
- **Oscdim**: Or xorriso/mkisofts/hdiutil supported by packer (needed for building the ISO for local 'mount' files)

## Files Overview

- **`autounattend.xml`**: Automated Windows installation configuration file.
- **`WinRM-Config.ps1`**: PowerShell script to enable WinRM.
- **`Install-Agent.ps1`**: PowerShell script to install qemu-guest-agent, needed for connection. Similar to VMware tools for vSphere.
- **`win10x64.pkr.hcl`**: Packer configuration file for building the Windows 10 VM.
- **`win10x64.pkrvars.hcl`**: Variables specific to the Windows 10 VM build.
- **`proxmox.pkrvars.hcl`**: Variables for connecting to the Proxmox server.

## Setup

1. **Update Variables**: Modify the `win10x64.pkrvars.hcl` and `proxmox.pkrvars.hcl` files with your specific settings.

   - `win10x64.pkrvars.hcl`:
     ```hcl
     vm_name                     = "Win10Pro-Template"
     template_name               = "Win10Pro-Template"
     os                          = "win10"
     cores                       = 2
     sockets                     = 2
     memory                      = 4112
     cpu_type                    = "kvm64"
     vm_cdrom_type               = "sata"
     
     disk_size                   = "40G"
     disk_format                 = "raw"
     disk_storage_pool           = "local-lvm"
     iso_storage_pool            = "storage"
     
     vm_network                  = "vmbr0"
     firewall                    = "true"
     bridge                      = "vmbr0"
     
     builder_username            = "Administrator"
     builder_password            = "CHANGE_ME"
     
     iso_file                    = "local:iso/Windows-64.iso"
     ```

    ## Reusable vars
   - `proxmox.pkrvars.hcl`:
     ```hcl
     proxmox_host              = "192.168.1.1:8006"
     proxmox_node              = "dev"
     proxmox_api_user          = "root@pam"
     proxmox_api_password      = "Password"
     proxmox_storage           = "storage"
     ```

2. **Install Packer Plugins**: Ensure the required Packer plugins are installed by running:
   ```sh
   packer init .
   packer build --var-file=win10x64.pkrvars.hcl --var-file=../proxmox.pkrvars.hcl win10x64.pkr.hcl