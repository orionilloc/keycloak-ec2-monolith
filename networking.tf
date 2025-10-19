#networking.tf

resource "aws_vpc" "vpc_keycloak" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "vpc-${var.project_name}"
    Project     = var.project_name
    Environment = "dev"
  }
}

resource "aws_internet_gateway" "igw_keycloak" {
  vpc_id = aws_vpc.vpc_keycloak.id

  tags = {
    Name        = "igw-${var.project_name}"
    Project     = var.project_name
    Environment = "dev"
  }
}

resource "aws_subnet" "subnet_keycloak_public_a" {
  vpc_id                  = aws_vpc.vpc_keycloak.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.region}a"

  tags = {
    Name        = "subnet-${var.project_name}-public-a"
    Project     = var.project_name
    Environment = "dev"
  }
}

resource "aws_route_table" "rt_keycloak_public" {
  vpc_id = aws_vpc.vpc_keycloak.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_keycloak.id
  }

  tags = {
    Name        = "rt-${var.project_name}-public"
    Project     = var.project_name
    Environment = "dev"
  }
}

resource "aws_route_table_association" "rta_keycloak_public_a" {
  subnet_id      = aws_subnet.subnet_keycloak_public_a.id
  route_table_id = aws_route_table.rt_keycloak_public.id
}


