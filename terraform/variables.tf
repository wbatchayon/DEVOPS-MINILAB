variable "proxmox_api_url" {
  description = "URL de l'API Proxmox"
  type        = string
}

variable "proxmox_api_token_id" {
  description = "Proxmox API Token ID"
  type        = string
  sensitive   = true
  default     = "Your_Proxmox_Token_ID"
}

variable "proxmox_api_token_secret" {
  description = "Proxmox API Token Secret"
  type        = string
  sensitive   = true
}

variable "proxmox_ssh_user" {
  description = "SSH user pour Proxmox"
  type        = string
  default     = "root"
}

variable "proxmox_ssh_password" {
  description = "SSH password pour Proxmox"
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Nom du node Proxmox"
  type        = string
  default     = "pve"
}

variable "proxmox_storage" {
  description = "Storage Proxmox"
  type        = string
  default     = "local-lvm"
}

variable "proxmox_bridge" {
  description = "Bridge réseau Proxmox"
  type        = string
  default     = "vmbr0"
}

variable "ubuntu_iso" {
  description = "Nom de l'ISO Ubuntu"
  type        = string
  default     = "ubuntu-24.04.3-live-server-amd64.iso"
}