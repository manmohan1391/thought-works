provider "aws" {}

resource "aws_vpc" "vpc" {
    cidr_block = "10.0.0.0/16"
    enable_dns_support   = true
    enable_dns_hostnames = true
    tags       = {
        Name = "Terraform VPC"
    }
}

resource "aws_internet_gateway" "internet_gateway" {
    vpc_id = aws_vpc.vpc.id
}

resource "aws_subnet" "pub_subnet" {
    vpc_id                  = aws_vpc.vpc.id
    cidr_block              = "10.0.0.0/24"
}

resource "aws_route_table" "public" {
    vpc_id = aws_vpc.vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.internet_gateway.id
    }
}

resource "aws_route_table_association" "route_table_association" {
    subnet_id      = aws_subnet.pub_subnet.id
    route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "thoughtworks_sg" {
    vpc_id      = aws_vpc.vpc.id

    ingress {
        from_port       = 22
        to_port         = 22
        protocol        = "tcp"
        cidr_blocks     = ["0.0.0.0/0"]
    }

    ingress {
        from_port       = 443
        to_port         = 443
        protocol        = "tcp"
        cidr_blocks     = ["0.0.0.0/0"]
    }

    ingress {
        from_port       = 8011
        to_port         = 8011
        protocol        = "tcp"
        cidr_blocks     = ["0.0.0.0/0"]
    }

    ingress {
        from_port       = 8022
        to_port         = 8022
        protocol        = "tcp"
        cidr_blocks     = ["0.0.0.0/0"]
    }

    ingress {
        from_port       = 8033
        to_port         = 8033
        protocol        = "tcp"
        cidr_blocks     = ["0.0.0.0/0"]
    }

    ingress {
        from_port       = 8044
        to_port         = 8044
        protocol        = "tcp"
        cidr_blocks     = ["0.0.0.0/0"]
    }

    ingress {
        from_port       = 8055
        to_port         = 8055
        protocol        = "tcp"
        cidr_blocks     = ["0.0.0.0/0"]
    }

    egress {
        from_port       = 0
        to_port         = 65535
        protocol        = "tcp"
        cidr_blocks     = ["0.0.0.0/0"]
    }
}

resource "aws_instance" "thoughtworks-instances" {
  ami = "ami-0dc8d444ee2a42d8a"
  instance_type = "t2.micro"
  key_name = "prometheus-pem"
  security_groups = [aws_security_group.thoughtworks_sg.id]
  subnet_id = "${aws_subnet.pub_subnet.id}"
}

resource "aws_eip" "thoughtworkip" {
  instance = aws_instance.thoughtworks-instances.id
  vpc      = true
}

output "instance_ip_addr" {
  value = "${aws_eip.thoughtworkip.public_ip}"
}

resource "null_resource" "cluster" {
  triggers = {
    always_run = "${timestamp()}"
  }
  connection {
    type = "ssh"
    user = "ubuntu"
    host = "${aws_eip.thoughtworkip.public_ip}"
    private_key = file("${var.private_ssh}")
  }
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install apt-transport-https ca-certificates curl gnupg-agent software-properties-common",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -",
      "sudo add-apt-repository \"deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\"",
      "sudo apt-get update",
      "sudo apt-get install -y docker-ce docker-ce-cli containerd.io",
      "sudo docker run -p 8044:8080 -d manmohan13912/cloud:newsfeed",
      "sudo docker run -p 8033:8080 -d manmohan13912/cloud:quotes",
      "sudo docker run -p 8011:8080 -e PUBLIC_IP=${aws_eip.thoughtworkip.public_ip} -d manmohan13912/cloud:frontend"
    ]
  }
}
