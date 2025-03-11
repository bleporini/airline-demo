provider "aws" {
  region = var.region
  default_tags {
    tags = {
      owner = var.owner
    }
  }
}


data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "lambda.mjs"
  output_path = "lambda_function_payload.zip"
}

resource "aws_lambda_function" "carrier-api" {
  filename      = "lambda_function_payload.zip"
  function_name = "carrier-external-api"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "lambda.handler"

  source_code_hash = data.archive_file.lambda.output_base64sha256

  runtime = "nodejs18.x"

}

resource "aws_lambda_function_url" "carrier-api-url" {
  function_name      = aws_lambda_function.carrier-api.function_name
  authorization_type = "NONE"
}

output "lambda-url" {
  value = "${aws_lambda_function_url.carrier-api-url.url_id}.lambda-url.${var.region}.on.aws:443:TCP"
}
