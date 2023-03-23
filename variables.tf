variable "aws_region" {
  description = "AWS region for all resources."

  type    = string
  default = "us-east-1"
}

variable "aws_access_key_id" {
  description = "AWS access key id"
  type        = string
  sensitive   = true
}

variable "aws_secret_access_key" {
  description = "AWS secret access key"
  type        = string
  sensitive   = true
}

variable "notion_routine_log_db" {
  description = "Routine tracking notion db table."
  type    = string
}

variable "notion_exercise_db" {
  description = "Exercise tracking db table."
  type    = string
}

variable "notion_integration_token" {
  description = "Notion integration token"
  type        = string
  sensitive   = true
}
