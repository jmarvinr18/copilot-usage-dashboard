client            = "livingway"
client_account_id = "792682046440"
environment       = "production"
region            = "ap-southeast-1"

function_name = "copilot-usage-dashboard"
description   = "for automated update of copilot dashboard"
role_name     = "copilot-usage-dashboard-role"

handler     = "lambda_function.lambda_handler"
runtime     = "python3.12"
timeout     = 600
memory_size = 256

s3_bucket = "lwa-rag-documents"

environment_variables = {
  ENVIRONMENT = "production"
}

tags = {
  "Name"       = "lwaDocumentProcessor"
  "Client"     = "livingway"
  "Created-by" = "terraform-jmr"
}

layer_filename = "openpyxl-layer.zip"
layer_name = "openpyxl-layer"