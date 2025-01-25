provider "aws" {
  region = "ap-northeast-1"
  access_key = ""
  secret_key = ""
}



variable "subnet_prefix" {
  # description = "cidr block subnet"
  ## default 
  # type = any
} ## if there is no value for this var, it will be prompted to enter


## Steps to deply the web server

# 1. vcp
resource "aws_vpc" "pro-vpc" {
  cidr_block = "10.0.0.0/16"
  tags={
    Name = "production"
  }
}
# 2. internet gateway
resource "aws_internet_gateway" "pro-gw" {
  vpc_id = aws_vpc.pro-vpc.id

  tags = {
    Name = "pro-gw"
  }
}

# 3. route table

resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.pro-vpc.id

  route {
    cidr_block = "0.0.0.0/0"#default route: all traffic will sent to the internet gateway
    gateway_id = aws_internet_gateway.pro-gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.pro-gw.id
  }

  tags = {
    Name = "prod"
  }
}

# 4. subnet
resource "aws_subnet" "subnet-1"{
  vpc_id = aws_vpc.pro-vpc.id
  cidr_block = var.subnet_prefix
  availability_zone = "ap-northeast-1a"

  tags={
    Name="prod-subnet"
  }
}

# 5. associate subnet with route table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id


}

# 6. security group: 22,80,443:  only connect to the required protocals

resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web traffic: inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.pro-vpc.id

  tags = {
    Name = "allow_tls"
  }
}

# ingress
resource "aws_vpc_security_group_ingress_rule" "allow_https_ipv4" {
  security_group_id = aws_security_group.allow_web.id
  # cidr_ipv4         = aws_vpc.pro-vpc.cidr_block #which subnet can reach this box; put our own ip address of our own devices
  cidr_ipv4         = "0.0.0.0/0" # any ip adress can access it
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
  description       = "rule for https"
}

resource "aws_vpc_security_group_ingress_rule" "allow_https_ipv6" {
  security_group_id = aws_security_group.allow_web.id
  cidr_ipv6         = "::/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}


resource "aws_vpc_security_group_ingress_rule" "allow_http_ipv4" {
  security_group_id = aws_security_group.allow_web.id
  # cidr_ipv4         = aws_vpc.pro-vpc.cidr_block #which subnet can reach this box; put our own ip address of our own devices
  cidr_ipv4         = "0.0.0.0/0" # any ip adress can access it
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
  description       = "rule for http"
}

resource "aws_vpc_security_group_ingress_rule" "allow_http_ipv6" {
  security_group_id = aws_security_group.allow_web.id
  cidr_ipv6         = "::/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh_ipv4" {
  security_group_id = aws_security_group.allow_web.id
  # cidr_ipv4         = aws_vpc.pro-vpc.cidr_block #which subnet can reach this box; put our own ip address of our own devices
  cidr_ipv4         = "0.0.0.0/0" # any ip adress can access it
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
  description       = "rule for ssh"
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh_ipv6" {
  security_group_id = aws_security_group.allow_web.id
  cidr_ipv6         = "::/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}


# egress

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.allow_web.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
  tags              ={
    Name="allow-web"
  }
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv6" {
  security_group_id = aws_security_group.allow_web.id
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}



# 7. network interface with an ip in thr interface

resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"] #a list of ips
  security_groups = [aws_security_group.allow_web.id]


}
# 8. assign eip to network interface
### eip relys on internet gateway
resource "aws_eip" "one" {
  domain                    = "vpc"
  network_interface         = aws_network_interface.web-server-nic.id 
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.pro-gw]#use a list
}

# output "server_public_ip" {
#   value =aws_eip.one.public_ip
# }


# 9. create ubuntu server


resource "aws_s3_bucket" "s3_bucket" {
  bucket = "zigy-s3-trial"
  # versioning {
  #   enabled = true
  # }
  tags = {
    Name        = "My-bucket"
    
  }
}

resource "aws_instance" "web-server" {
  ami           = "ami-0a290015b99140cd1"
  instance_type = "t2.micro"
  availability_zone = "ap-northeast-1a"
  key_name = "zigy-trial-freecodecamp"

  network_interface {
    device_index=0
    network_interface_id = aws_network_interface.web-server-nic.id
  }




user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl s tart apache2
              sudo bash -c 'echo your very first web server > /var/www/html/index.html'
              EOF
  tags={
    Name="web-server"
  }
}
