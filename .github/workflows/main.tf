provider "aws" {
  profile = ""
  region  = var.aws_region
}

// Create a security group with access to port 22 and port 80 open to serve HTTP traffic

resource "random_id" "server" {
  keepers = {
    # Generate a new id each time we switch to a new AMI id
    ami_id = "${var.ami_id}"
  }

  byte_length = 8
}

resource "aws_security_group" "github_actions" {
  name   = "${var.namespace}-${random_id.server.hex}-SG"
  vpc_id = aws_vpc.Main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Environment = "${var.environment}"
    Name        = "${var.namespace}-SG"
  }
}

// instance setup

resource "aws_instance" "testing_vm" {
  ami                         = var.ami_id
  availability_zone           = var.availability_zone
  associate_public_ip_address = true
  key_name                    = var.ami_key_pair_name # This is the key as known in the ec2 key_pairs
  instance_type               = var.instance_type
  tags                        = var.instance_tags
  vpc_security_group_ids      = [aws_security_group.github_actions.id]
  subnet_id                   = aws_subnet.Main.id
  root_block_device {
    delete_on_termination = true
  }
}

// generate inventory file
resource "local_file" "inventory" {
  filename             = "./hosts.yml"
  directory_permission = "0755"
  file_permission      = "0644"
  content              = <<EOF
    # benchmark host
    all:
      hosts:
        ${var.ami_os}:
          ansible_host: ${aws_instance.testing_vm.public_ip}
          ansible_user: ${var.ami_username}
      vars:
        setup_audit: true
        run_audit: true
        system_is_ec2: true
        skip_reboot: false
        rhel9cis_rule_5_6_6: false  # skip root passwd check and keys only
    EOF
}

