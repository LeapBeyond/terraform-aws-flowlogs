provider "aws" {
  region  = "${var.aws_region}"
  profile = "${var.aws_profile}"
}

resource "aws_kms_key" "state" {
  deletion_window_in_days = 7

  tags = "${merge(map("Name", "terraform_state"), var.tags)}"
}

resource "aws_kms_alias" "a" {
  name          = "alias/terraform_state"
  target_key_id = "${aws_kms_key.state.key_id}"
}

resource "aws_dynamodb_table" "dynamodb-terraform-state-lock" {
  name           = "${var.lock_table_name}"
  hash_key       = "LockID"
  read_capacity  = 1
  write_capacity = 1

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = "${merge(map("Name", "Terraform_State_Lock"), var.tags)}"
}

resource "aws_s3_bucket" "terraform-state-storage-s3" {
  bucket_prefix = "${var.bucket_prefix}"
  acl           = "private"

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = false
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = "${aws_kms_key.state.arn}"
        sse_algorithm     = "aws:kms"
      }
    }
  }

  tags = "${merge(map("Name", "Terraform_State_Store"), var.tags)}"
}
