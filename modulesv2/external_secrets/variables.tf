variable "networks" {
  type = any
}

variable "s3_secrets_bucket" {
  type = string
}

variable "wireguard_client_hosts" {
  type = any
}

variable "wireguard_client_templates" {
  type = list(string)
}

variable "addon_templates" {
  type = map(string)
}