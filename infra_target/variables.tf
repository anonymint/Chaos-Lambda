variable profile {
  description = "AWS profile you want to use"
  default     = "default"
}

variable "master_account" {
  description = "The master account 13 digit, having Chaos setup"
}

variable "region" {
  description = "Default region to run script"
}
