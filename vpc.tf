
// get available zones
data "aws_availability_zones" "azs" {
    state = "available"
}

// get my home dsl ip
data "http" "myip" {
    url = "https://ipv4.icanhazip.com"
}

locals {
    // how many azs
    azs_count = length(data.aws_availability_zones.azs.names)
}

// eks vpc
resource "aws_vpc" "this" {
  cidr_block = var.vpc-primary-cidr
  enable_dns_support   = var.dns_support
  enable_dns_hostnames = var.dns_hostnames

  tags = {
    Name = var.vpc-name
  }
}

# public subnets per az
resource "aws_subnet" "publics" {
  count = var.single_az ? 1 : local.azs_count 
  
  vpc_id = aws_vpc.this.id
  map_public_ip_on_launch = "true"
  cidr_block = cidrsubnet(aws_vpc.this.cidr_block, 8, count.index)
  availability_zone = data.aws_availability_zones.azs.names[count.index]

  tags = {
    Name = "public-${count.index + 1}"
  }
}

# private subnets per az
resource "aws_subnet" "privates" {
  count = var.private_worker ? var.single_az ? 1 : local.azs_count : 0
    
  vpc_id = aws_vpc.this.id
  cidr_block = cidrsubnet(aws_vpc.this.cidr_block, 8, count.index + local.azs_count)
  availability_zone = data.aws_availability_zones.azs.names[count.index]
  tags = {
    Name = "private-${count.index + 1}"
  }
}

# igw 
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = aws_vpc.this.tags["Name"]
  }
}

# eip
resource "aws_eip" "nat_gateway" {
  count = var.private_worker ? var.single_az ? 1 : local.azs_count : 0

  vpc = true

  tags = {
    Name = "NAT Gateway IP for ${data.aws_availability_zones.azs.names[count.index]}"
  }
}

# nat-gw 
resource "aws_nat_gateway" "this" {
  count = var.private_worker ? var.single_az ? 1 : local.azs_count : 0

  allocation_id = aws_eip.nat_gateway[count.index].id
  subnet_id     = aws_subnet.publics[count.index].id

  tags = {
    Name = "NAT Gateway for ${data.aws_availability_zones.azs.names[count.index]}"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.this]
}

# public route table 
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id   
  }
  tags = {
    Name = "public"
  }
}

# private route table 
resource "aws_route_table" "private" {
  count = var.private_worker ? 1 : 0

  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.this[0].id   
  }  
  tags = {
    Name = "private"
  }
  
  depends_on = [aws_nat_gateway.this]
}

# association between public route table and subnets
resource "aws_route_table_association" "public" {
  count = var.single_az ? 1 : local.azs_count 

  subnet_id = aws_subnet.publics[count.index].id
  route_table_id  = aws_route_table.public.id
}

# association between private route table and subnets
resource "aws_route_table_association" "private" {
  count = var.private_worker ? var.single_az ? 1 : local.azs_count : 0

  subnet_id = aws_subnet.privates[count.index].id
  route_table_id  = aws_route_table.private[0].id
}

# security-group
resource "aws_security_group" "basic" {
  name = "basic" 
  description = "basic protection"
  vpc_id = aws_vpc.this.id

  egress {
    description = "internet access"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "whitelist my home dsl ip"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
  }

  ingress {
    description = "vpc internal connectivity"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [aws_vpc.this.cidr_block]
  }

  tags = {
    Name = "basic"
  }
}