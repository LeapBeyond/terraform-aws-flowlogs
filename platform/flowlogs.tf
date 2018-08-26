# -----------------------------------------------------------------------------
# policy to allow flow logs to write to cloudwatch
# -----------------------------------------------------------------------------
resource "aws_iam_role" "flowlogs_role" {
  name = "test_flowlogs"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "vpc-flow-logs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "flowlogs_policy" {
  name = "test_flowlogs"
  role = "${aws_iam_role.flowlogs_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

# -----------------------------------------------------------------------------
# enable VPC flow logs, writing to cloudwatch
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "test_log_group" {
  name = "test_log_group"
}

resource "aws_flow_log" "test_flow_log" {
  log_group_name = "${aws_cloudwatch_log_group.test_log_group.name}"
  iam_role_arn   = "${aws_iam_role.flowlogs_role.arn}"
  vpc_id         = "${aws_vpc.test_vpc.id}"
  traffic_type   = "ALL"
}

# -----------------------------------------------------------------------------
# bucket that will hold logs - note that SSE is not enabled for simplicity
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "flow_logs" {
  bucket_prefix = "test-flow-logs"
  acl           = "private"

  versioning {
    enabled = false
  }

  lifecycle {
    prevent_destroy = false
  }

  tags = "${merge(map("Name", "VPC_Flow_Logs"), var.tags)}"
}

# -----------------------------------------------------------------------------
# Kinesis firehose that delivers logs to S3
# -----------------------------------------------------------------------------
resource "aws_iam_role" "firehose_role" {
  name = "firehose_test_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "firehose.amazonaws.com"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId":"${var.aws_account_id}"
        }
      }
    }
  ]
}
EOF
}

# See https://docs.aws.amazon.com/firehose/latest/dev/controlling-access.html#using-iam-s3
# this excludes the KMS config from there, as well as permissions to use cloudwatch and lambda

resource "aws_iam_policy" "firehose_s3_policy" {
  name        = "firehose_s3_policy"
  path        = "/"
  description = "Allows kinesis to write vpc flow logs to s3"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement":
    [
        {
            "Effect": "Allow",
            "Action": [
                "s3:AbortMultipartUpload",
                "s3:GetBucketLocation",
                "s3:GetObject",
                "s3:ListBucket",
                "s3:ListBucketMultipartUploads",
                "s3:PutObject"
            ],
            "Resource": [
                "${aws_s3_bucket.flow_logs.arn}",
                "${aws_s3_bucket.flow_logs.arn}/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "kinesis:DescribeStream",
                "kinesis:GetShardIterator",
                "kinesis:GetRecords"
            ],
            "Resource": "arn:aws:firehose:${var.aws_region}:${var.aws_account_id}:deliverystream/${var.stream_name}"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "firehose_role_attch" {
    role       = "${aws_iam_role.firehose_role.name}"
    policy_arn = "${aws_iam_policy.firehose_s3_policy.arn}"
}

resource "aws_kinesis_firehose_delivery_stream" "test_stream" {
  name        = "${var.stream_name}"
  destination = "s3"

  s3_configuration {
    role_arn   = "${aws_iam_role.firehose_role.arn}"
    bucket_arn = "${aws_s3_bucket.flow_logs.arn}"
    compression_format = "GZIP"
    #kms_key_arn
  }
}

# -----------------------------------------------------------------------------
# lambda function that delivers logs to the kinesis stream
# -----------------------------------------------------------------------------
resource "aws_iam_role" "lambda_kinesis_exec_role" {
  name = "lambda_kinesis_exec_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "lambda_kinesis_exec_policy" {
  name        = "lambda_kinesis_exec_policy"
  path        = "/"
  description = "Allows lambda to send logs to kinesis"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "firehose:PutRecordBatch"
      ],
      "Resource": "arn:aws:firehose:${var.aws_region}:${var.aws_account_id}:deliverystream/${var.stream_name}"    
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_kinesis_exec_attach" {
    role       = "${aws_iam_role.lambda_kinesis_exec_role.name}"
    policy_arn = "${aws_iam_policy.lambda_kinesis_exec_policy.arn}"
}

resource "aws_iam_role_policy_attachment" "lambda_kinesis_execute" {
  role       = "${aws_iam_role.lambda_kinesis_exec_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/AWSLambdaExecute"
}

resource "null_resource" "lambda_zip" {
  provisioner "local-exec" {
    command = "zip -q VPCFlowLogsToFirehose.zip VPCFlowLogsToFirehose.py"
  }
}

resource "aws_lambda_function" "vpc_flow_logs_to_firehose" {
  depends_on = ["null_resource.lambda_zip"]

  filename         = "VPCFlowLogsToFirehose.zip"
  function_name    = "VPCFlowLogsToFirehose"
  role             = "${aws_iam_role.lambda_kinesis_exec_role.arn}"
  handler          = "VPCFlowLogsToFirehose.lambda_handler"
  source_code_hash = "${base64sha256(file("VPCFlowLogsToFirehose.zip"))}"
  runtime          = "python2.7"
  timeout          = "60"
  memory_size      = "128"

  environment {
    variables = {
      DELIVERY_STREAM_NAME = "${var.stream_name}"
    }
  }

  tags = "${merge(map("Name","FlowLogs-To-S3"), var.tags)}"
}

resource "aws_lambda_permission" "vpc_flow_logs" {
  statement_id  = "vpc_flow_logs"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.vpc_flow_logs_to_firehose.arn}"
  principal     = "logs.${var.aws_region}.amazonaws.com"
  source_arn    = "${aws_cloudwatch_log_group.test_log_group.arn}"
}

resource "aws_cloudwatch_log_subscription_filter" "vpc_flow_logs_filter" {
  depends_on      = ["aws_lambda_permission.vpc_flow_logs"]
  name            = "vpc_flow_logs_filter"
  log_group_name = "${aws_cloudwatch_log_group.test_log_group.name}"
  destination_arn = "${aws_lambda_function.vpc_flow_logs_to_firehose.arn}"
  filter_pattern  = "[version, account_id, interface_id, srcaddr != \"-\", dstaddr != \"-\", srcport != \"-\", dstport != \"-\", protocol, packets, bytes, start, end, action, log_status]"
}
