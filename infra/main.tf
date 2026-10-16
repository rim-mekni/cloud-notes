# ---------------------------------------------------------------
# Infrastructure Azure pour Cloud Notes (approche VM)
# Commande unique : terraform apply
# ---------------------------------------------------------------

terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# 1) Groupe de ressources : le "dossier" qui contient tout
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# 2) Réseau virtuel + sous-réseau
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-cloudnotes"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "snet-app"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# 3) Adresse IP publique (pour accéder à l'app depuis Internet)
resource "azurerm_public_ip" "pip" {
  name                = "pip-cloudnotes"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# 4) Pare-feu (Network Security Group)
#    - On autorise UNIQUEMENT le port 80 (HTTP) depuis Internet.
#    - Pas de SSH (22) ouvert, pas de PostgreSQL (5432) ouvert.
#    - Le déploiement passe par l'API Azure (az vm run-command), pas par SSH.
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-cloudnotes"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

# 5) Carte réseau de la VM
resource "azurerm_network_interface" "nic" {
  name                = "nic-cloudnotes"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

resource "azurerm_network_interface_security_group_association" "nic_nsg" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# 6) Secrets générés automatiquement (jamais écrits dans Git)
resource "random_password" "db" {
  length  = 24
  special = false # évite les caractères spéciaux qui cassent l'URL de connexion
}

# Clé SSH obligatoire pour créer une VM Linux sans mot de passe.
# Le port 22 étant fermé, elle ne sert qu'en cas de dépannage (via Azure Bastion par ex.).
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# 7) La machine virtuelle Ubuntu
resource "azurerm_linux_virtual_machine" "vm" {
  name                  = var.vm_name
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  size                  = var.vm_size
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.nic.id]

  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.ssh.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # Script de démarrage (cloud-init) : installe Docker + crée le fichier .env
  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
    db_password = random_password.db.result
  }))
}
