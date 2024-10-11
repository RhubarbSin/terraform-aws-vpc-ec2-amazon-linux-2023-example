resource "random_integer" "this" {
  min = 0
  max = 255
}

resource "aws_vpc" "this" {
  cidr_block = "192.168.${random_integer.this.result}.0/24"
}

resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id
}

resource "aws_vpc_security_group_egress_rule" "this" {
  security_group_id = aws_default_security_group.this.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = -1
}

resource "aws_vpc_security_group_ingress_rule" "this" {
  security_group_id = aws_default_security_group.this.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"
}

resource "aws_default_route_table" "this" {
  default_route_table_id = aws_vpc.this.default_route_table_id
}

resource "aws_internet_gateway" "this" {}

resource "aws_internet_gateway_attachment" "this" {
  internet_gateway_id = aws_internet_gateway.this.id
  vpc_id              = aws_vpc.this.id
}

resource "aws_route" "this" {
  route_table_id         = aws_vpc.this.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id

  depends_on = [aws_internet_gateway_attachment.this]
}

data "aws_availability_zones" "this" {
  state = "available"
}

resource "random_shuffle" "this" {
  input = data.aws_availability_zones.this.names

  result_count = 1
}

resource "aws_subnet" "this" {
  vpc_id = aws_vpc.this.id

  cidr_block        = aws_vpc.this.cidr_block
  availability_zone = random_shuffle.this.result.0
}

resource "aws_route_table_association" "this" {
  subnet_id      = aws_subnet.this.id
  route_table_id = aws_vpc.this.default_route_table_id
}
