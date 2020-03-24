resource "aws_iam_role" "lambda-ecs-scheduled-scaling" {
  name = "${var.prefix_region}-${var.prefix_env}-lambda-ecs-scheduled-scaling"
  path = "/"
  assume_role_policy = data.aws_iam_policy_document.lambda-assume-role-policy-doc.json
}

// Assume policy
data "aws_iam_policy_document" "lambda-assume-role-policy-doc" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type = "Service"
      identifiers = [
        "lambda.amazonaws.com"
      ]
    }
  }
}

/* Policy attachements */
resource "aws_iam_role_policy_attachment" "CloudWatchLogs-policy-attachment" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
  role       = aws_iam_role.lambda-ecs-scheduled-scaling.name
}


data "aws_iam_policy_document" "lambda-ecs-scheduled-scaling-policy-doc" {
  statement {
    sid = "ecsAllow"
    effect = "Allow"
    actions = [
      "ecs:ListServices",
      "ecs:UpdateService",
      "ecs:DescribeServices",
      "ecs:ListClusters"
    ]
    resources = ["*"]
  }

  statement {
    sid = "dynamoDbAllow"
    effect = "Allow"
    actions = [
      "dynamodb:ListTables",
      "dynamodb:DescribeTable",
      "dynamodb:CreateTable",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
      "dynamodb:UpdateItem"
    ]
    resources = ["arn:aws:dynamodb:${var.aws_region}:*:table/services-desiredCount"]
  }
}

resource "aws_iam_role_policy" "lambda-ecs-scheduled-scaling-policy" {
  name = "${var.prefix_region}-${var.prefix_env}-lambd-ecs-scheduled-scaling-policy"
  role       = aws_iam_role.lambda-ecs-scheduled-scaling.name
  policy = data.aws_iam_policy_document.lambda-ecs-scheduled-scaling-policy-doc.json
}

// Convert *.py to .zip because AWS Lambda need .zip
data "archive_file" "lambda-code" {
  type        = "zip"
  source_dir  = "../scripts/"
  output_path = "../aws-ecs-scheduled-scaling-resources.zip"
}

// Lambda function
resource "aws_lambda_function" "lambda-ecs-scheduled-scaling" {
  description      = "Lambda function for scheduled ECS service scaling"
  filename         = data.archive_file.lambda-code.output_path
  function_name    = "${var.prefix_region}-${var.prefix_env}-ecs-scheduled-scaling"
  handler          = "lambda_function_ecs_scaling.handler"
  role             = aws_iam_role.lambda-ecs-scheduled-scaling.arn
  runtime          = "python3.7"
  source_code_hash = data.archive_file.lambda-code.output_base64sha256
  timeout          = "900"

  environment {
    variables = {
      ECS_CLUSTER = "${var.prefix_region}-${var.prefix_env}-${var.fargate_cluster_name}"
      AWS_REGION_ENTRY  = var.aws_region
    }
  }
}

// CloudWatch events
resource "aws_cloudwatch_event_rule" "event-rule-downscaling" {
  description         = "Trigger scheduled ECS downscaling"
  name                = "ECSScheduledScaling-Down"
  schedule_expression = var.ecs_scheduled_downscaling_expression
}

resource "aws_cloudwatch_event_rule" "event-rule-upscaling" {
  description         = "Trigger scheduled ECS upscaling"
  name                = "ECSScheduledScaling-Up"
  schedule_expression = var.ecs_scheduled_upscaling_expression
}

resource "aws_cloudwatch_event_target" "event-target-downscaling" {
  arn       = aws_lambda_function.lambda-ecs-scheduled-scaling.arn
  rule      = aws_cloudwatch_event_rule.event-rule-downscaling.name
  target_id = "lambda-ecs-scheduled-scaling-downscaling"
}

resource "aws_cloudwatch_event_target" "event-target-upscaling" {
  arn       = aws_lambda_function.lambda-ecs-scheduled-scaling.arn
  rule      = aws_cloudwatch_event_rule.event-rule-upscaling.name
  target_id = "lambda-ecs-scheduled-scaling-upscaling"
}

// Lambda permission  
resource "aws_lambda_permission" "allow-cloudwatch-to-call-lambda-downscaling" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda-ecs-scheduled-scaling.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.event-rule-downscaling.arn
  statement_id  = "AllowECSDownscalingFromCloudWatch"

  depends_on = [
    aws_lambda_function.lambda-ecs-scheduled-scaling
  ]
}

resource "aws_lambda_permission" "allow-cloudwatch-to-call-lambda-upscaling" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda-ecs-scheduled-scaling.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.event-rule-upscaling.arn
  statement_id  = "AllowECSUpscalingFromCloudWatch"

  depends_on = [
    aws_lambda_function.lambda-ecs-scheduled-scaling
  ]
}
