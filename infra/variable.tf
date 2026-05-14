variable "location" {
  description = "The Azure region where the resources will be created."
  type        = string
  default     = "eastus"
}

variable "vm_size" {
  description = "The size of the virtual machine."
  type        = string
  default     = "Standard_D2s_v3" #2 vCPU, 8 GB RAM, $78.11/month
}

variable "admin_username" {
  description = "The admin username for the virtual machine."
  type        = string
  default     = "mozennou"
}