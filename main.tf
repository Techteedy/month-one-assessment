terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# ─────────────────────────────────────────
# KEY PAIR
# ─────────────────────────────────────────
resource "aws_key_pair" "techcorp_key" {
  key_name   = var.key_pair_name
  public_key = file("techcorp-key.pub")
}

# ─────────────────────────────────────────
# IAM ROLE FOR SSM
# ─────────────────────────────────────────
resource "aws_iam_role" "ssm_role" {
  name = "techcorp-ssm-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "techcorp-ssm-profile"
  role = aws_iam_role.ssm_role.name
}

# ─────────────────────────────────────────
# VPC
# ─────────────────────────────────────────
resource "aws_vpc" "techcorp_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "techcorp-vpc" }
}

# ─────────────────────────────────────────
# SUBNETS
# ─────────────────────────────────────────
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.techcorp_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true
  tags = { Name = "techcorp-public-subnet-1" }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.techcorp_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = true
  tags = { Name = "techcorp-public-subnet-2" }
}

resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.techcorp_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${var.region}a"
  tags = { Name = "techcorp-private-subnet-1" }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.techcorp_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "${var.region}b"
  tags = { Name = "techcorp-private-subnet-2" }
}

# ─────────────────────────────────────────
# INTERNET GATEWAY
# ─────────────────────────────────────────
resource "aws_internet_gateway" "techcorp_igw" {
  vpc_id = aws_vpc.techcorp_vpc.id
  tags = { Name = "techcorp-igw" }
}

# ─────────────────────────────────────────
# ELASTIC IPs FOR NAT GATEWAYS
# ─────────────────────────────────────────
resource "aws_eip" "nat_eip_1" {
  domain = "vpc"
  tags = { Name = "techcorp-nat-eip-1" }
}

resource "aws_eip" "nat_eip_2" {
  domain = "vpc"
  tags = { Name = "techcorp-nat-eip-2" }
}

# ─────────────────────────────────────────
# NAT GATEWAYS
# ─────────────────────────────────────────
resource "aws_nat_gateway" "nat_gw_1" {
  allocation_id = aws_eip.nat_eip_1.id
  subnet_id     = aws_subnet.public_subnet_1.id
  tags = { Name = "techcorp-nat-gw-1" }
  depends_on = [aws_internet_gateway.techcorp_igw]
}

resource "aws_nat_gateway" "nat_gw_2" {
  allocation_id = aws_eip.nat_eip_2.id
  subnet_id     = aws_subnet.public_subnet_2.id
  tags = { Name = "techcorp-nat-gw-2" }
  depends_on = [aws_internet_gateway.techcorp_igw]
}

# ─────────────────────────────────────────
# ROUTE TABLES
# ─────────────────────────────────────────
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.techcorp_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.techcorp_igw.id
  }
  tags = { Name = "techcorp-public-rt" }
}

resource "aws_route_table" "private_rt_1" {
  vpc_id = aws_vpc.techcorp_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw_1.id
  }
  tags = { Name = "techcorp-private-rt-1" }
}

resource "aws_route_table" "private_rt_2" {
  vpc_id = aws_vpc.techcorp_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw_2.id
  }
  tags = { Name = "techcorp-private-rt-2" }
}

# ─────────────────────────────────────────
# ROUTE TABLE ASSOCIATIONS
# ─────────────────────────────────────────
resource "aws_route_table_association" "public_rta_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_rta_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_rta_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_rt_1.id
}

resource "aws_route_table_association" "private_rta_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_rt_2.id
}

# ─────────────────────────────────────────
# SECURITY GROUPS
# ─────────────────────────────────────────
resource "aws_security_group" "bastion_sg" {
  name        = "techcorp-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = aws_vpc.techcorp_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "techcorp-bastion-sg" }
}

resource "aws_security_group" "web_sg" {
  name        = "techcorp-web-sg"
  description = "Security group for web servers"
  vpc_id      = aws_vpc.techcorp_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "techcorp-web-sg" }
}

resource "aws_security_group" "db_sg" {
  name        = "techcorp-db-sg"
  description = "Security group for database server"
  vpc_id      = aws_vpc.techcorp_vpc.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "techcorp-db-sg" }
}

# ─────────────────────────────────────────
# AMI DATA SOURCE (Amazon Linux 2)
# ─────────────────────────────────────────
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# ─────────────────────────────────────────
# BASTION HOST
# ─────────────────────────────────────────
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type_bastion
  subnet_id              = aws_subnet.public_subnet_1.id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  key_name               = var.key_pair_name
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name
  tags = { Name = "techcorp-bastion" }
}

resource "aws_eip" "bastion_eip" {
  instance = aws_instance.bastion.id
  domain   = "vpc"
  tags = { Name = "techcorp-bastion-eip" }
}

# ─────────────────────────────────────────
# WEB SERVERS
# ─────────────────────────────────────────
resource "aws_instance" "web_server_1" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type_web
  subnet_id              = aws_subnet.private_subnet_1.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  user_data              = file("user_data/web_server_setup.sh")
  key_name               = var.key_pair_name
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name
  tags = { Name = "techcorp-web-server-1" }
}

resource "aws_instance" "web_server_2" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type_web
  subnet_id              = aws_subnet.private_subnet_2.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  user_data              = file("user_data/web_server_setup.sh")
  key_name               = var.key_pair_name
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name
  tags = { Name = "techcorp-web-server-2" }
}

# ─────────────────────────────────────────
# DATABASE SERVER
# ─────────────────────────────────────────
resource "aws_instance" "db_server" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type_db
  subnet_id              = aws_subnet.private_subnet_1.id
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  user_data              = file("user_data/db_server_setup.sh")
  key_name               = var.key_pair_name
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name
  tags = { Name = "techcorp-db-server" }
}

# ─────────────────────────────────────────
# APPLICATION LOAD BALANCER
# ─────────────────────────────────────────
resource "aws_lb" "techcorp_alb" {
  name               = "techcorp-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
  tags = { Name = "techcorp-alb" }
}

resource "aws_lb_target_group" "techcorp_tg" {
  name     = "techcorp-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.techcorp_vpc.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200"
  }

  tags = { Name = "techcorp-tg" }
}

resource "aws_lb_listener" "techcorp_listener" {
  load_balancer_arn = aws_lb.techcorp_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.techcorp_tg.arn
  }
}

resource "aws_lb_target_group_attachment" "web_server_1_attachment" {
  target_group_arn = aws_lb_target_group.techcorp_tg.arn
  target_id        = aws_instance.web_server_1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "web_server_2_attachment" {
  target_group_arn = aws_lb_target_group.techcorp_tg.arn
  target_id        = aws_instance.web_server_2.id
  port             = 80
}
