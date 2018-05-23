variable "hook_url" {
  description = "The Microsoft team hook url"
}

variable "region" {
  description = "region to run the script"
}

variable "prob" {
  description = "probability to kill instance 1 means all the time, 0.13 ~ 1/6 or once in sixth appproximately"
  default     = 0.13
}

variable "target_regions" {
  description = "List of target regions to scan and introduce chaos"
  default     = "us-east-1"
}

variable "target_accounts" {
  description = "target accounts separate by comma 12345,1232,12312 for example"
}

variable "schedule_run" {
  description = "Cron job to run in GMT time, please make sure it's valid cloudwatch schedule!"
  type        = "list"
  default     = ["cron(13 15-21 ? * MON-FRI *)"]
}
