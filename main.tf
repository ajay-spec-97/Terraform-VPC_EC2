# Creating a VPC
resource "aws_vpc" "prod-vpc" {
  cidr_block       = "10.10.0.0/24"
  instance_tenancy = "default"
  tags = {
    Name = "Production-VPC-1"
  }
}

# Creating a Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.prod-vpc.id
  tags = {
    Name = "IGW-1"
  }
}

# Creating a Route Table in above VPC
resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    #egress_only_gateway_id = aws_egress_only_internet_gateway.igw.id
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Prod-RT"
  }
}

#Creating a Subnet
resource "aws_subnet" "subnet-1" {
  vpc_id     = aws_vpc.prod-vpc.id
  cidr_block = "10.10.0.0/28"
  availability_zone = "ap-south-1a"
  tags = {
    Name = "Subnet1"
  }
}

# Associate the above subnet "subnet-1" with Route table "prod-route-table"
resource "aws_route_table_association" "assoc-prod-route-table" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}

#Creating a security group
resource "aws_security_group" "allow_web_traffic" {
  name        = "allow_web_traffic"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description = "https traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "http traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    ingress {
    description = "SSH Access"
    from_port   = 22
    to_port     = 22
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
    Name = "Allow web traffic"
  }
}

# Create a network interface within an ip in the subnet created above
resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.10.0.10"]
  security_groups = [aws_security_group.allow_web_traffic.id]
}
# Assign Elastic IP to above network interface
resource "aws_eip" "one" {
  vpc                       = true                                      #set "true" if EIP(Elastic IP) is in the VPC else set "false"
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.10.0.10"
  depends_on = [aws_internet_gateway.igw]
}

# Create a Linux server
resource "aws_instance" "linux" {
  ami = "ami-0e306788ff2473ccb"
  instance_type = "t2.micro"
  availability_zone = "ap-south-1a"
  key_name = "Key-1"

  network_interface{
      device_index = 0
      network_interface_id = aws_network_interface.web-server-nic.id
  }
  

  user_data = <<-EOF
          #! /bin/bash
          sudo -i
          yum install httpd -y
          bash -c 'echo This is a test write for web server>  /var/www/html/index.html'
          systemctl start httpd
        EOF

  tags = {
    Name = "Linux server"
  }
}

output "server_public_ip"{
    value = aws_eip.one.public_ip
}
