provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key

  default_tags {
    tags = {
      project = "notion-workout-creation"
    }
  }

}

resource "random_pet" "lambda_bucket_name" {
  prefix = "notion-workout-creation-lambda"
  length = 4
}

resource "aws_s3_bucket" "lambda_bucket" {
  bucket = random_pet.lambda_bucket_name.id
}

resource "aws_s3_bucket_acl" "bucket_acl" {
  bucket = aws_s3_bucket.lambda_bucket.id
  acl    = "private"
}

data "archive_file" "notion_workout_creation" {
  type       = "zip"

  source_dir  = "${path.module}/lambda_dist_pkg"
  output_path = "${path.module}/notion-workout-creation.zip"
}

resource "aws_s3_object" "notion_workout_creation" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "notion-workout-creation.zip"
  source = data.archive_file.notion_workout_creation.output_path

  etag = filemd5(data.archive_file.notion_workout_creation.output_path)
}

resource "aws_lambda_function" "notion_workout_creation" {
  function_name = "NotionWorkoutCreation"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.notion_workout_creation.key

  runtime = "python3.9"
  handler = "handler.handler"
  timeout = 60

  source_code_hash = data.archive_file.notion_workout_creation.output_base64sha256

  role = aws_iam_role.lambda_exec.arn

  environment {
    variables = {
      NOTION_ROUTINE_LOG_DATABASE_ID = var.notion_routine_log_db
      NOTION_EXERCISE_DATABASE_ID    = var.notion_exercise_db
      NOTION_INTEGRATION_TOKEN       = var.notion_integration_token
    }
  }
}

resource "aws_cloudwatch_log_group" "notion_workout_creation" {
  name = "/aws/lambda/${aws_lambda_function.notion_workout_creation.function_name}"

  retention_in_days = 30
}

resource "aws_iam_role" "lambda_exec" {
  name = "notion_workout_creation_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_event_rule" "notion_workout_creation_schedule" {
  name                = "notion_workout_creation_schedule"
  description         = "Schedule for Notion workout creation function"
  schedule_expression = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "notion_workout_creation_schedule_lambda" {
  rule      = aws_cloudwatch_event_rule.notion_workout_creation_schedule.name
  target_id = "notion_workout_creation"
  arn       = aws_lambda_function.notion_workout_creation.arn
}

resource "aws_lambda_permission" "allow_events_bridge_to_run_lambda" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.notion_workout_creation.function_name
  principal     = "events.amazonaws.com"
}
