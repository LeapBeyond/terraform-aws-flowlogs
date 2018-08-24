provider "aws" {
  region  = "${var.aws_region}"
  profile = "${var.aws_profile}"
}

# --------------------------------------------------------------------------------------------------------------
# define the test VPC
# --------------------------------------------------------------------------------------------------------------

resource "aws_vpc" "test_vpc" {
  cidr_block           = "${var.vpc_cidr}"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = "${merge(map("Name", "flowlogs-vpc"), var.tags)}"
}

# seal off the default NACL
resource "aws_default_network_acl" "test_default" {
  default_network_acl_id = "${aws_vpc.test_vpc.default_network_acl_id}"
  tags                   = "${merge(map("Name", "flowlogs-default"), var.tags)}"
}

# seal off the default security group
resource "aws_default_security_group" "test_default" {
  vpc_id = "${aws_vpc.test_vpc.id}"
  tags   = "${merge(map("Name", "flowlogs-default"), var.tags)}"
}

resource "aws_internet_gateway" "testgateway" {
  vpc_id = "${aws_vpc.test_vpc.id}"
  tags   = "${merge(map("Name", "flowlogs-gateway"), var.tags)}"
}

resource "aws_subnet" "ec2" {
  vpc_id                  = "${aws_vpc.test_vpc.id}"
  cidr_block              = "${var.ec2_subnet_cidr}"
  map_public_ip_on_launch = false
  tags                    = "${merge(map("Name", "flowlogs-ec2"), var.tags)}"
}

resource "aws_subnet" "nat" {
  vpc_id                  = "${aws_vpc.test_vpc.id}"
  cidr_block              = "${var.nat_subnet_cidr}"
  map_public_ip_on_launch = true
  tags                    = "${merge(map("Name", "flowlogs-nat"), var.tags)}"
}

resource "aws_eip" "nat" {
  vpc                       = true
  associate_with_private_ip = "${var.eip_nat_ip}"
  tags                      = "${merge(map("Name", "flowlogs-eip"), var.tags)}"
}

resource "aws_nat_gateway" "gw" {
  allocation_id = "${aws_eip.nat.id}"
  subnet_id     = "${aws_subnet.nat.id}"
  tags          = "${merge(map("Name", "flowlogs-nat"), var.tags)}"
}

resource "aws_route_table" "nat" {
  vpc_id = "${aws_vpc.test_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.testgateway.id}"
  }

  tags = "${merge(map("Name", "flowlogs-nat"), var.tags)}"
}

resource "aws_route_table_association" "nat" {
  subnet_id      = "${aws_subnet.nat.id}"
  route_table_id = "${aws_route_table.nat.id}"
}

resource "aws_route_table" "ec2" {
  vpc_id = "${aws_vpc.test_vpc.id}"

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.gw.id}"
  }

  tags = "${merge(map("Name", "flowlogs-ec2"), var.tags)}"
}

resource "aws_route_table_association" "ec2" {
  subnet_id      = "${aws_subnet.ec2.id}"
  route_table_id = "${aws_route_table.ec2.id}"
}

resource "aws_network_acl" "nat" {
  vpc_id     = "${aws_vpc.test_vpc.id}"
  subnet_ids = ["${aws_subnet.nat.id}"]
  tags       = "${merge(map("Name", "flowlogs-nat"), var.tags)}"
}

resource "aws_network_acl_rule" "nat_http_out" {
  network_acl_id = "${aws_network_acl.nat.id}"
  rule_number    = 100
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "nat_https_out" {
  network_acl_id = "${aws_network_acl.nat.id}"
  rule_number    = 101
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "nat_http_in" {
  network_acl_id = "${aws_network_acl.nat.id}"
  rule_number    = 300
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "${var.ec2_subnet_cidr}"
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "nat_https_in" {
  network_acl_id = "${aws_network_acl.nat.id}"
  rule_number    = 301
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "${var.ec2_subnet_cidr}"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "nat_ephemeral_out" {
  network_acl_id = "${aws_network_acl.nat.id}"
  rule_number    = 200
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "${var.ec2_subnet_cidr}"
  from_port   = 1024
  to_port     = 65535
}

resource "aws_network_acl_rule" "nat_ssh_out_to_ssh" {
  count          = "${length(var.ssh_inbound)}"
  network_acl_id = "${aws_network_acl.nat.id}"
  rule_number    = "${2100 + count.index}"
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "${var.ssh_inbound[count.index]}"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "nat_ephemeral_in" {
  network_acl_id = "${aws_network_acl.nat.id}"
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port   = 1024
  to_port     = 65535
}

resource "aws_network_acl_rule" "nat_ssh_in" {
  count          = "${length(var.ssh_inbound)}"
  network_acl_id = "${aws_network_acl.nat.id}"
  rule_number    = "${200 + count.index}"
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "${var.ssh_inbound[count.index]}"
  from_port      = 22
  to_port        = 22
}

resource "aws_network_acl_rule" "nat_ssh_out" {
  network_acl_id = "${aws_network_acl.nat.id}"
  rule_number    = 300
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "${var.ec2_subnet_cidr}"
  from_port      = 22
  to_port        = 22
}

resource "aws_network_acl" "ec2" {
  vpc_id     = "${aws_vpc.test_vpc.id}"
  subnet_ids = ["${aws_subnet.ec2.id}"]
  tags       = "${merge(map("Name", "flowlogs-ec2"), var.tags)}"
}

resource "aws_network_acl_rule" "ec2_http_out" {
  network_acl_id = "${aws_network_acl.ec2.id}"
  rule_number    = 100
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "ec2_https_out" {
  network_acl_id = "${aws_network_acl.ec2.id}"
  rule_number    = 101
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "ec2_ephemeral_out" {
  network_acl_id = "${aws_network_acl.ec2.id}"
  rule_number    = 110
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "${var.nat_subnet_cidr}"
  from_port   = 1024
  to_port     = 65535
}

resource "aws_network_acl_rule" "ec2_ephemeral_in" {
  network_acl_id = "${aws_network_acl.ec2.id}"
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port   = 1024
  to_port     = 65535
}

resource "aws_network_acl_rule" "ec2_ssh_in" {
  network_acl_id = "${aws_network_acl.ec2.id}"
  rule_number    = 101
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "${var.nat_subnet_cidr}"
  from_port   = 22
  to_port     = 22
}

resource "aws_security_group" "ec2_ssh_access" {
  name        = "flowlogs-ec2-ssh"
  description = "allows ssh access to the test host"
  vpc_id      = "${aws_vpc.test_vpc.id}"
  tags        = "${merge(map("Name", "flowlogs-ec2-ssh"), var.tags)}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.nat_subnet_cidr}"]
  }
}

resource "aws_security_group" "http_out_access" {
  name        = "flowlogs-http-out"
  description = "allows instance to reach out on port 80 and 443"
  vpc_id      = "${aws_vpc.test_vpc.id}"
  tags        = "${merge(map("Name", "flowlogs-http_out_access"), var.tags)}"

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "bastion_ssh_access" {
  name        = "flowlogs-bastion-ssh-in"
  description = "allows ssh access to the bastion host"
  vpc_id      = "${aws_vpc.test_vpc.id}"
  tags        = "${merge(map("Name", "flowlogs-bastion-ssh"), var.tags)}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.ssh_inbound}"]
  }
}

resource "aws_security_group" "bastion_ssh_out" {
  name        = "flowlogs-bastion-ssh-out"
  description = "allows ssh from the bastion host"
  vpc_id      = "${aws_vpc.test_vpc.id}"
  tags        = "${merge(map("Name", "flowlogs-bastion-ssh"), var.tags)}"

  egress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.ec2_subnet_cidr}"]
  }
}

resource "aws_security_group" "bastion_http_out" {
  name        = "flowlogs-bastion-http-out"
  description = "allows http and https from the bastion host"
  vpc_id      = "${aws_vpc.test_vpc.id}"
  tags        = "${merge(map("Name", "flowlogs-bastion-ssh"), var.tags)}"

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --------------------------------------------------------------------------------------------------------------
# EC2 instances
# --------------------------------------------------------------------------------------------------------------
data "aws_ami" "target_ami" {
  most_recent = true

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["${var.ami_name}"]
  }
}

resource "aws_instance" "test" {
  ami                         = "${data.aws_ami.target_ami.id}"
  instance_type               = "${var.instance_type}"
  key_name                    = "${var.ec2_key}"
  subnet_id                   = "${aws_subnet.ec2.id}"
  associate_public_ip_address = false

  vpc_security_group_ids = [
    "${aws_security_group.ec2_ssh_access.id}",
    "${aws_security_group.http_out_access.id}",
  ]

  root_block_device = {
    volume_type = "gp2"
    volume_size = "${var.root_vol_size}"
  }

  tags        = "${merge(map("Name", "flowlogs-test"), var.tags)}"
  volume_tags = "${var.tags}"

  user_data = <<EOF
#!/bin/bash
yum update -y -q
EOF
}

resource "aws_instance" "bastion" {
  ami                         = "${data.aws_ami.target_ami.id}"
  instance_type               = "${var.instance_type}"
  key_name                    = "${var.bastion_key}"
  subnet_id                   = "${aws_subnet.nat.id}"
  associate_public_ip_address = true

  vpc_security_group_ids = [
    "${aws_security_group.bastion_ssh_access.id}",
    "${aws_security_group.bastion_ssh_out.id}",
    "${aws_security_group.bastion_http_out.id}"
  ]

  root_block_device = {
    volume_type = "gp2"
    volume_size = "${var.root_vol_size}"
  }

  tags        = "${merge(map("Name", "flowlogs-bastion"), var.tags)}"
  volume_tags = "${var.tags}"

  user_data = <<EOF
#!/bin/bash
yum update -y -q
EOF

provisioner "file" {
  source      = "${path.root}/../data/${var.ec2_key}.pem"
  destination = "/home/${var.ec2_user}/.ssh/${var.ec2_key}.pem"

  connection {
    type        = "ssh"
    user        = "${var.ec2_user}"
    private_key = "${file("${path.root}/../data/${var.bastion_key}.pem")}"
    timeout     = "5m"
  }
}

provisioner "remote-exec" {
  inline = [
    "chmod 0400 /home/${var.ec2_user}/.ssh/*.pem",
  ]

  connection {
    type        = "ssh"
    user        = "${var.ec2_user}"
    private_key = "${file("${path.root}/../data/${var.bastion_key}.pem")}"
  }
}
}
