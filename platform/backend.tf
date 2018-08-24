terraform {
  backend "s3" {
    region         = "eu-west-2"
    profile        = "adm_rhook_cli"
    dynamodb_table = "terraform-state-lock"
    bucket         = "terraform-state20180823151609662300000001"
    key            = "terraform-flowlogs-test/platform-scripts"
    encrypt        = true
    kms_key_id     = "arn:aws:kms:eu-west-2:889199313043:key/2e84e858-a65f-4e80-949f-34a6cef20870"
  }
}
