output "prd-eus-server-01-public-ip" {
  value = azurerm_public_ip.prd-eus-server-01-pip.ip_address
}