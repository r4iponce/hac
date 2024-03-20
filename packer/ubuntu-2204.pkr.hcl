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

variable "ssh_password_crypt" {
  type    = string
  default = null
}

variable "ssh_user" {
  type = string
  default = "packer"
}

variable "ssh_password" {
  type = string
  default = null
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
    default = "localhost:8006"
}

source "proxmox-iso" "ubuntu-2204" {
    http_content = {
    "/meta-data" = file("http/meta-data")
    "/user-data" = templatefile("http/user-data", { user = var.ssh_user, password_crypt = var.ssh_password_crypt })
    }
    

    boot_command = [
      "e<wait><down><down><down><end>",
      " autoinstall ds=\"nocloud-net;seedfrom=http://{{.HTTPIP}}:{{.HTTPPort}}/\"",
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

    iso_checksum            = "45f873de9f8cb637345d6e66a583762730bbea30277ef7b32c9c3bd6700a32b2"
    iso_url                 = "https://releases.ubuntu.com/22.04.4/ubuntu-22.04.4-live-server-amd64.iso"
    iso_storage_pool        = "local"
    iso_download_pve        = true
    unmount_iso             = true
    
    network_adapters {
        bridge = "vmbr20"
        model  = "virtio"
    }

    memory               = 8192
    cores                = 4
    vm_id                = 9000

    node                 = "sorm"
    username             = "${var.proxmox_user}"
    token                = "${var.proxmox_token}"
    proxmox_url          = "${var.proxmox_url}/api2/json"
    ssh_username         = "${var.ssh_user}"
    ssh_private_key_file = "~/.ssh/id_ed25519"
    ssh_timeout          = "15m"
    template_description = "Ubuntu 22.04 build by packer on ${timestamp()}"
    template_name        = "ubuntu-2204-r4"
    cloud_init           = true
    cloud_init_storage_pool = "local-lvm"
}


build {
  sources = ["source.proxmox-iso.ubuntu-2204"]
  provisioner "ansible" {
      ansible_env_vars = ["ANSIBLE_CONFIG=../ansible/ansible.cfg", "ANSIBLE_HOST_KEY_CHECKING=False", "ANSIBLE_BECOME_PASS=${var.ssh_password}"]
      extra_arguments  = [ "--scp-extra-args", "'-O'", "-vv", "--extra-vars", "ansible_become_password=${var.ssh_password}" ]
      command          = "ansible-playbook"
      roles_path       = "../ansible/roles"
      playbook_file    = "../ansible/packer.yml"
  }

}
