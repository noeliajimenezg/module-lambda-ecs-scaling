variable "aws_region" {
  description = "Region of AWS Cloud"
  default     = "eu-west-1" // UE (Ireland)
}

variable "prefix_region" {
  description = "Prefix of the region for naming conventions"
  default     = "eu"
}

variable "prefix_env" {
  description = "Prefix of the environment for naming conventions"
  default     = "dev"
}

variable "fargate_cluster_name" {
  description = "Name of the Fargate cluster (ECS)"
  default     = ""
}

variable "ecs_scheduled_downscaling_expression" {
  description = "The scheduling expression for the CloudWatch rule that triggers scheduled ECS Service downscaling (GMT)"
  default     = "cron(00 21 ? * MON-FRI *)"
}

variable "ecs_scheduled_upscaling_expression" {
  description = "The scheduling expression for the CloudWatch rule that triggers scheduled ECS Service upscalin (GMT)"
  default     = "cron(00 5 ? * MON-FRI *)"
}
