packer {
  required_plugins {
    name = {
      version = "~> 1"
      source  = "github.com/hashicorp/proxmox"
    }
    ansible = {
      version = "~> 1"
      source = "github.com/hashicorp/ansible"
    }
  }
}


variable "proxmox_user" {
  type = string
  default = "packer"
}

variable "proxmox_token" {
    type = string
    default = null
}

variable "proxmox_url" {
    type = string
    default = null
}

variable "grub_password_crypt" {
    type = string
    default = null
}

variable "ssh_password_crypt" {
    type = string
    default = null
}

variable "ssh_password" {
    type = string
    default = null
}

source "proxmox-iso" "alma-9" {
    http_content = {
      "/ks.cfg" = templatefile("http/ks.cfg", { grub_password = var.grub_password_crypt, password_crypt = var.ssh_password_crypt })
    }
    

    boot_command = [
      "e<wait><down><down><end>",
      " inst.ks=http://{{.HTTPIP}}:{{.HTTPPort}}/ks.cfg",
      "<leftCtrlOn>x<leftCtrlOff>",
    ]


    boot_wait = "10s"

    disks {
        disk_size         = "10G"
        storage_pool      = "lab"
        type              = "virtio"
    }
    scsi_controller       = "virtio-scsi-single"

    bios  = "ovmf"
    efi_config {
        efi_storage_pool  = "lab"
        efi_type          = "4m"
        pre_enrolled_keys = true
    }

    insecure_skip_tls_verify = true

    iso_checksum            = "af5377a1d16bbe599ea91a8761ad645f2f54687075802bdc0c0703ee610182e9"
    iso_url                 = "https://repo.almalinux.org/almalinux/9.3/isos/x86_64/AlmaLinux-9.3-x86_64-boot.iso"
    iso_storage_pool        = "local"
    iso_download_pve        = true
    unmount_iso             = true
    
    network_adapters {
        bridge = "vmbr20"
        model  = "virtio"
    }

    memory               = 8192
    cores                = 4
    cpu_type             = "host"
    vm_id                = 9001

    node                 = "sorm"
    username             = "${var.proxmox_user}"
    token                = "${var.proxmox_token}"
    proxmox_url          = "${var.proxmox_url}/api2/json"
    ssh_username         = "root"
    ssh_password         = "${var.ssh_password}"
    ssh_timeout          = "15m"
    template_description = "Alma Linux 9 build by packer on ${timestamp()}"
    template_name        = "alma-9-r4"
    cloud_init           = true
    cloud_init_storage_pool = "local-lvm"
}


build {
  sources = ["source.proxmox-iso.alma-9"]
  provisioner "ansible" {
      ansible_env_vars = ["ANSIBLE_CONFIG=../../ansible/ansible.cfg", "ANSIBLE_HOST_KEY_CHECKING=False", "ANSIBLE_BECOME_PASS=${var.ssh_password}"]
      extra_arguments  = [ "--scp-extra-args", "'-O'", "-vv", "--extra-vars", "ansible_become_password=${var.ssh_password}" ]
      command          = "ansible-playbook"
      roles_path       = "../../ansible/roles"
      playbook_file    = "../../ansible/packer.yml"
  }
}
