terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.71.0"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = "${var.proxmox_api_token_id}=${var.proxmox_api_token_secret}"
  insecure  = true
  
  # Configuration SSH pour accéder au node Proxmox
  ssh {
    agent    = false
    username = var.proxmox_ssh_user
    password = var.proxmox_ssh_password
  }
}

# VM Master
resource "proxmox_virtual_environment_vm" "k8s_master" {
  name        = "k8s-master-tf"
  node_name   = var.proxmox_node
  vm_id       = 100
  
  clone {
    vm_id = 9000  # ID du template
  }
  
  cpu {
    cores = 2
  }
  
  memory {
    dedicated = 4096
  }
  
  disk {
    datastore_id = var.proxmox_storage
    interface    = "scsi0"
    size         = 32
  }
  
  network_device {
    bridge = var.proxmox_bridge
  }
  
  initialization {
    ip_config {
      ipv4 {
        address = "x.x.x.100/24"
        gateway = "x.x.x.1"
      }
    }
    
    user_account {
      username = "ubuntu"
      password = "ubuntu"
      keys     = []
    }
  }
}

# VM Worker
resource "proxmox_virtual_environment_vm" "k8s_worker" {
  name        = "k8s-worker-tf"
  node_name   = var.proxmox_node
  vm_id       = 101
  
  clone {
    vm_id = 9000  # ID du template
  }
  
  cpu {
    cores = 2
  }
  
  memory {
    dedicated = 4096
  }
  
  disk {
    datastore_id = var.proxmox_storage
    interface    = "scsi0"
    size         = 32
  }
  
  network_device {
    bridge = var.proxmox_bridge
  }
  
  initialization {
    ip_config {
      ipv4 {
        address = "x.x.x.101/24"
        gateway = "x.x.x.1"
      }
    }
    
    user_account {
      username = "ubuntu"
      password = "ubuntu"
      keys     = []
    }
  }
}