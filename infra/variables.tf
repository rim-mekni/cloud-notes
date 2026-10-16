variable "subscription_id" {
  description = "ID de ta souscription Azure (az account show --query id -o tsv)"
  type        = string
}

variable "location" {
  description = "Région Azure"
  type        = string
  default     = "swedencentral"
}

variable "resource_group_name" {
  description = "Nom du groupe de ressources (doit correspondre au workflow GitHub)"
  type        = string
  default     = "rg-cloudnotes"
}

variable "vm_name" {
  description = "Nom de la VM (doit correspondre au workflow GitHub)"
  type        = string
  default     = "vm-cloudnotes"
}

variable "vm_size" {
  description = "Taille de la VM (petite = pas chère)"
  type        = string
  default     = "Standard_B1s"
}
