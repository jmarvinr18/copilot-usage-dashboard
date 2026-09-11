data "archive_file" "this" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/.build/${var.function_name}.zip"
}

module "role" {
  source = "../../../../../../../modules/lambda/role"

  role_name = var.role_name

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
  ]

  inline_policies = [
    {
      name = "s3-read-write"
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [

              "s3:GetObject",
              "s3:PutObject",
              "s3:DeleteObject",
              "s3:ListBucket"              
            ]
            Resource = "arn:aws:s3:::${var.s3_bucket}/*"
          }
        ]
      })
    },
    {
      name = "ai-service-read"
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Sid    = "TextractRead"
            Effect = "Allow"
            Action = [
              "textract:GetDocumentTextDetection",
              "textract:GetDocumentAnalysis"
            ]
            Resource = "*"
          },
          {
            Sid    = "RekognitionRead"
            Effect = "Allow"
            Action = [
              "rekognition:GetLabelDetection",
              "rekognition:DetectLabels"
            ]
            Resource = "*"
          },
          {
            Sid    = "TranscribeRead"
            Effect = "Allow"
            Action = [
              "transcribe:GetTranscriptionJob"
            ]
            Resource = "*"
          },
          {
            Sid    = "ComprehendDetect"
            Effect = "Allow"
            Action = [
              "comprehend:DetectEntities",
              "comprehend:DetectKeyPhrases",
              "comprehend:DetectSentiment",
              "comprehend:DetectDominantLanguage",
              "comprehend:DetectPiiEntities"
            ]
            Resource = "*"
          }
        ]
      })
    },
    {
      name = "bedrock-invoke"
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Sid    = "BedrockInvoke"
            Effect = "Allow"
            Action = [
              "bedrock:InvokeModel",
              "bedrock:InvokeModelWithResponseStream"
            ]
            Resource = "arn:aws:bedrock:*::foundation-model/*"
          }
        ]
      })
    }
  ]

  tags = var.tags
}

module "function" {
  source = "../../../../../../../modules/lambda/function"

  function_name    = var.function_name
  description      = var.description
  role_arn         = module.role.arn
  handler          = var.handler
  runtime          = var.runtime
  filename         = data.archive_file.this.output_path
  source_code_hash = data.archive_file.this.output_base64sha256
  timeout          = var.timeout
  memory_size      = var.memory_size

  environment_variables = var.environment_variables

  tags = var.tags
}
