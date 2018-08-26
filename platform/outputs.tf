output "nat_ip" {
  value = "${aws_eip.nat.public_ip}"
}

output "public_dns" {
  value = "${aws_instance.bastion.public_dns}"
}

output "private_dns" {
  value = "${aws_instance.test.private_dns}"
}

output "connect_string" {
  value = "ssh -i ${var.bastion_key}.pem ${var.ec2_user}@${aws_instance.bastion.public_dns}"
}

output "log_bucket" {
  value = "${aws_s3_bucket.flow_logs.bucket}"
}

output "athena_ddl_id" {
  value = "${aws_athena_named_query.flow_logs_ddl.id}"
}

output "athena_summary_id" {
  value = "${aws_athena_named_query.flow_logs_summary.id}"
}
