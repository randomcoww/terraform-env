variable "user" {
  type = string
}

variable "mtu" {
  type = number
}

variable "hosts" {
  type = any
}

variable "templates" {
  type = list(string)
}