client            = "livingway"
client_account_id = "792682046440"
environment       = "production"
region            = "ap-southeast-1"

function_name = "lwaDocumentProcessor"
description   = "Formats and enriches output from Textract, Rekognition, and Transcribe for the LWA ingestion pipeline."
role_name     = "lwa-document-processor-role"

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
