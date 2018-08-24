output "nat_ip" {
  value = "${aws_eip.nat.public_ip}"
}

output "public_dns" {
  value = "${aws_instance.test.public_dns}"
}

output "private_dns" {
  value = "${aws_instance.test.private_dns}"
}

output "connect_string" {
  value = "ssh -i ${var.ec2_key}.pem ${var.ec2_user}@${aws_instance.test.public_dns}"
}
