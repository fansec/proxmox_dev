# VM settings
vm_name                     = "Ubuntu24.04.Desktop"
template_name               = "Ubuntu24.04.Desktop"
os                          = "l26"
cores                       = 2
sockets                     = 2
memory                      = 4 * 1024
cpu_type                    = "kvm64"
vm_cdrom_type               = "sata"

# Disk
disk_size                   = "8G"
disk_format                 = "raw"
disk_storage_pool           = "storage"
iso_storage_pool            = "storage"

# Network
vm_network                  = "vmbr0"
firewall                    = "true"
bridge                      = "vmbr0"

# Windows settings
builder_username            = "fansec"
builder_password            = "ubuntu"

# Path to Windows 10 ISO on Proxmox host
iso_file                    = "storage:iso/ubuntu24_04.iso"


#packer build --var-file=ubuntu.pkrvars.hcl --var-file=../proxmox.pkrvars.hcl ubuntu.pkr.hcl 