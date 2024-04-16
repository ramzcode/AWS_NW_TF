module "label_vpc" {
  source     = "cloudposse/label/null"
  version    = "0.25.0"
  context    = module.base_label.context
  name       = "vpc"
  stage      = "prod"
  attributes = ["main"]
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = module.label_vpc.tags
}

# =========================
# Create your subnets here
# =========================
module "label_subnets" {
  source     = "cloudposse/label/null"
  version    = "0.25.0"
  context    = module.base_label.context
  stage      = "prod"
  attributes = ["main"]
}

# Auto Generate public and private CIDR blocks.
locals {
  public_cidr_blocks = cidrsubnet(var.vpc_cidr, 4, 0)
  private_cidr_blocks = cidrsubnet(var.vpc_cidr, 4, 1)
}

# Internet GW for the Public Subnet to access Internet and vice versa. 
resource "aws_internet_gateway" "ig" {
  vpc_id = "${aws_vpc.main.id}"
  tags = {
    Name        = "${module.label_subnets.id}-igw"
  }
}

# Routes to handle the public & association of IGW
resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.main.id}"
  tags = {
    Name        = "${module.label_subnets.id}-public-route-table"
  }
}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = "${aws_route_table.public.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.ig.id}"
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = "${aws_route_table.public.id}"
}

# Subneting into two public and Private networks with a netmask of 24 each
resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.public_cidr_blocks
  availability_zone = "${var.aws_region}b"
  tags = merge(module.label_subnets.tags, {
    Name = "${module.label_subnets.id}-public_subnet" # Dynamically generate subnet name
  })
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_cidr_blocks
  availability_zone = "${var.aws_region}c"
  tags = merge(module.label_subnets.tags, {
    Name = "${module.label_subnets.id}-private_subnet" # Dynamically generate subnet name
  })
}