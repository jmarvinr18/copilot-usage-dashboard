variable "region" {
  type    = string
  default = "ap-southeast-1"
}

variable "client" {
  type = string
}

variable "client_account_id" {
  type = string
}

variable "environment" {
  type = string
}

variable "function_name" {
  type = string
}

variable "description" {
  type    = string
}

variable "role_name" {
  type = string
}

variable "handler" {
  type    = string
  default = "lambda_function.lambda_handler"
}

variable "runtime" {
  type    = string
  default = "python3.12"
}

variable "timeout" {
  type    = number
  default = 30
}

variable "memory_size" {
  type    = number
  default = 128
}

variable "s3_bucket" {
  type        = string
  description = "S3 bucket the function is allowed to read/write."
}

variable "environment_variables" {
  type    = map(string)
  default = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable layer_filename {
  type        = string
}

variable layer_name {
  type        = string
  default     = ""
  description = "description"
}


variable compatible_runtimes  {
  type        = list(string)
  default     = ["python3.12"]
}

variable compatible_architectures  {
  type        = list(string)
  default     = ["x86_64"]
}
