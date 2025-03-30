terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-1"
}

/*
Creating resources- the resources will consist of 
- VPC
- Subnets (2 public and 2 private)
- Security groups public
- Security groups private
- Route tables
- Internet Gateway
- NAT Gateway
- RDS instance
*/
resource "aws_vpc" "DBvpc" {

  cidr_block = "10.0.0.0/16"

  tags = {
    name = "DBVPC"
  }

}

resource "aws_internet_gateway" "DBigw" {

  vpc_id = aws_vpc.DBvpc.id

  tags = {
    Name = "IGW"
  }

}

## For this assignment, 10.0.*.0/24 will be CDR for subnets - * odd for public 
## and * even for private
resource "aws_subnet" "PublicSubnet1" {

  vpc_id            = aws_vpc.DBvpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "ServerSubnet1"
  }

}

resource "aws_subnet" "PublicSubnet2" {

  vpc_id            = aws_vpc.DBvpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "ServerSubnet2"
  }

}

resource "aws_subnet" "PrivateSubnet1" {

  vpc_id            = aws_vpc.DBvpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "DBsubnet1"
  }

}

resource "aws_subnet" "PrivateSubnet2" {

  vpc_id            = aws_vpc.DBvpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "DBsubnet2"
  }

}

#Next, route tables are creted for public and private subnets
resource "aws_route_table" "PublicRouteTable" {

  vpc_id = aws_vpc.DBvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.DBigw.id
  }

}

resource "aws_route_table_association" "PublicRouteTableAssoc" {

  count          = 2
  #Count is used to create two route tables for public subnets
  #The count.index is used to create two route tables for public subnets
  subnet_id      = [aws_subnet.PublicSubnet1.id, aws_subnet.PublicSubnet2.id][count.index]
  route_table_id = aws_route_table.PublicRouteTable.id

}

resource "aws_route_table" "PrivateRouteTable" {

  vpc_id = aws_vpc.DBvpc.id

}

resource "aws_route_table_association" "PrivateRouteTableAssoc" {

  count          = 2
  #Count is used to create two route tables for private subnets
  #The count.index is used to create two route tables for private subnets
  subnet_id      = [aws_subnet.PrivateSubnet1.id, aws_subnet.PrivateSubnet2.id][count.index]
  route_table_id = aws_route_table.PrivateRouteTable.id

}

#Next, security groups are created for public and private subnets
resource "aws_security_group" "ServerSG" {

  description = "Allow inbound traffic on port 80"
  vpc_id      = aws_vpc.DBvpc.id

  ingress {
    description = "Allow traffic to DB servers on port 80"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow traffic from servers to anywhere"
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # all protocols
  }

  tags = {
    name = "PublicServerSG"
  }

}

resource "aws_security_group" "DBSG" {

  description = "Allow inbound traffic on port 80"
  vpc_id      = aws_vpc.DBvpc.id

  ingress {
    description     = "Allow traffic only from servers to DB on port 3306"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ServerSG.id]
  }

  tags = {
    name = "PrivateDBSG"
  }

}

#Defining EC2 instance as DB servers

resource "aws_instance" "DBServer1" {

  ami                         = "ami-071226ecf16aa7d96"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.PublicSubnet1.id
  vpc_security_group_ids      = [aws_security_group.ServerSG.id]
  associate_public_ip_address = true

  tags = {
    name = var.instance1_name
  }

}

resource "aws_instance" "DBServer2" {

  ami                         = "ami-071226ecf16aa7d96"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.PublicSubnet2.id
  vpc_security_group_ids      = [aws_security_group.ServerSG.id]
  associate_public_ip_address = true

  tags = {
    name = var.instance2_name
  }

}

#Finally, creating RDS subgroup and instance
resource "aws_db_subnet_group" "DBSubnetGroup" {

  description = "DB subnet group to place DB in private subnets"
  subnet_ids  = [aws_subnet.PrivateSubnet1.id, aws_subnet.PrivateSubnet2.id]

}

resource "aws_db_instance" "DBInstance" {

  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "mysql"
  username               = "gianny" #could be a variable
  password               = "gianny123" #could be added to a secrets file
  instance_class         = "db.t3.micro"
  db_subnet_group_name   = aws_db_subnet_group.DBSubnetGroup.name
  vpc_security_group_ids = [aws_security_group.DBSG.id]
  skip_final_snapshot = true #Required to destory the RDS instance

  tags = {
    name = "ApplicationDB"
  }

}







