provider "aws" {
	access_key="${var.access_key}" 
	secret_key="${var.secret_key}" 
	region="${var.region}"
}

resource "aws_vpc" "EXAMPLE-vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
}


module "blueWeb" {
    source                 = "./Web"
    subnet_id              = "${aws_subnet.public.id}" #${element(aws_subnet.public.*.id, count.index)}
    key_pair_id            = "${var.key_pair_id}"
    private_key_path       = "${var.private_key_path}"
    security_group_id      = "${aws_security_group.HalfOpen.id}"

    
    count                  = 3
    group_name             = "blue"
}

module "greenWeb" {
    source                 = "./Web"
    subnet_id              = "${aws_subnet.public.id}" #${element(aws_subnet.public.*.id, count.index)}
    key_pair_id            = "${var.key_pair_id}"
    private_key_path       = "${var.private_key_path}"
    security_group_id      = "${aws_security_group.HalfOpen.id}"

    
    count                  = 3
    group_name             = "green"
}


module "blueELB" {
    name = "blueELB"
    source                 = "./ELB"
    public_subnet_id       = "${aws_subnet.public.id}"
    security_group_id      = "${aws_security_group.HalfOpen.id}"
    instance_ids           = "${module.blueWeb.instance_ids}"
    elb_prefix = "blue"
}

module "greenELB" {
    name = "greenELB"
    source                 = "./ELB"
    public_subnet_id       = "${aws_subnet.public.id}"
    security_group_id      = "${aws_security_group.HalfOpen.id}"
    instance_ids           = "${module.greenWeb.instance_ids}"
    elb_prefix = "green"
}

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.EXAMPLE-vpc.id}"
}

resource "aws_subnet" "public" {
  count = 1
  vpc_id = "${aws_vpc.EXAMPLE-vpc.id}"
  availability_zone = "${data.aws_availability_zones.available.names[0]}"
  cidr_block = "10.0.0.0/24"
  map_public_ip_on_launch = true
  tags {
    Name = "Public Subnet-0"
  }
}

resource "aws_route_table" "public-rt" {
  vpc_id = "${aws_vpc.EXAMPLE-vpc.id}"
  depends_on = ["aws_internet_gateway.igw"]
  tags {
    Name = "${terraform.workspace}-public-rt"
  }
}

resource "aws_route" "intoInstance" {
  route_table_id = "${aws_route_table.public-rt.id}"
  depends_on = ["aws_route_table.public-rt"]
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = "${aws_internet_gateway.igw.id}"
}

resource "aws_route_table_association" "public-rt" {
  subnet_id = "${aws_subnet.public.id}"
  route_table_id = "${aws_route_table.public-rt.id}"
}

resource "aws_security_group" "HalfOpen" {
  vpc_id = "${aws_vpc.EXAMPLE-vpc.id}"
  name = "HalfOpenSG"

  ingress {

      from_port = 22
      to_port   = 22
      protocol  = "tcp"
      cidr_blocks = ["67.171.25.72/32", "75.172.35.109/32"]
    }
  
  ingress{

      from_port = 443
      to_port   = 443
      protocol  = "tcp"
      cidr_blocks = ["67.171.25.72/32", "75.172.35.109/32"]
    }

  ingress{

    from_port = 9418
    to_port   = 9418
    protocol  = "tcp"
    cidr_blocks = ["67.171.25.72/32", "75.172.35.109/32"]
  }

  ingress{

    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    cidr_blocks = ["67.171.25.72/32", "75.172.35.109/32"]
  }

  ingress{

    from_port = 8000
    to_port   = 8000
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress{

    from_port = 8080
    to_port   = 8080
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "FullyOpenOUT"{
  type = "egress"
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.HalfOpen.id}"
}

data "aws_availability_zones" "available" {}

