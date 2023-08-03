terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.region
  access_key = "AKIA4C4ULQ6GDYTFQSPR"
  secret_key = "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"
}

# S3 bucket details

resource "aws_s3_bucket" "new" {
  bucket = var.bucket_name
  
  tags = {
    Name        = "My bucket"
  }
}

# VPC Creation

resource "aws_vpc" "myvpc" {
  cidr_block = var.vpc_cidr_block
  enable_dns_hostnames = true

  tags = {
    Name = "Terraform VPC"
  }
}

# Security group creation for Public
resource "aws_security_group" "public_sg" {
  name_prefix = "public-sg-"

  vpc_id = aws_vpc.myvpc.id

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH traffic"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow SSH access from any source (for demonstration purposes)
  } 
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Allow all outbound traffic
  }

  tags = {
    Name = "Public"
  }
}

# Security group creation for Private
resource "aws_security_group" "private_sg" {
  name_prefix = "private_sg"
  vpc_id = aws_vpc.myvpc.id

  ingress {
    description = "Allow SSH from Public Subnet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
  }
  ingress {
    description     = "Allow SSH from public security group"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"

  }

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Private"
  }
}

# Key Pair Details
resource "aws_key_pair" "web" {
  key_name   = "web"
  public_key = tls_private_key.rsa.public_key_openssh
}
resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "web" {
  content  = tls_private_key.rsa.private_key_pem
  filename = "private-web"
}

#Database Instance creation
resource "aws_db_subnet_group" "db" {
  name       = "my-db-subnet-group"
  subnet_ids = [aws_subnet.subnets[4].id, aws_subnet.subnets[5].id]
}

resource "aws_db_instance" "MasterDatabase" {
  identifier             = var.masterdb_identifier
  allocated_storage      = 20
  storage_type           = var.db_storage_type  
  engine                 = var.db_engine
  engine_version         = var.db_engine_version
  instance_class         = var.db_instance_class
  db_subnet_group_name   = aws_db_subnet_group.db.name
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  availability_zone      = "ap-south-1a"
  db_name                = var.masterdb_name
  username               = var.masterdb_username
  password               = var.masterdb_password
  backup_retention_period = 7
  skip_final_snapshot    = true
  multi_az               = false

  tags = {
    Name = "Master DB Instance"
  }
}

resource "aws_db_snapshot" "shot1" {
  db_instance_identifier = aws_db_instance.MasterDatabase.identifier
  db_snapshot_identifier = "snap1"  
}


resource "aws_db_instance" "ReplicaDatabase" {
  identifier             = var.replicadb_identifier
  storage_type           = var.db_storage_type
  engine                 = var.db_engine
  engine_version         = var.db_engine_version
  instance_class         = var.db_instance_class
  availability_zone      = "ap-south-1b"
  skip_final_snapshot    = true
  backup_retention_period = 7
  multi_az               = false
  replicate_source_db    = aws_db_instance.MasterDatabase.arn
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  
  tags = {
    Name = "Read Replica Database"
  }
  
}

# Internet Gateway

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "Terraform IGW"
  }
}

#Subnets creation

resource "aws_subnet" "subnets" {
  count = length(var.subnet_cidr_blocks)
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = element(var.subnet_cidr_blocks,count.index)
  availability_zone = element(var.zones,count.index)
  map_public_ip_on_launch = element(var.map_public_ip,count.index)

  tags = {
    Name = element(var.tags,count.index)
  }
}

# Public Route Table
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "Public Routable"
  }
}

resource "aws_route" "public_route" {
  count = 2
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.igw.id

}

# Route Table association - Public

resource "aws_route_table_association" "public_subnet1_association" {
  count = 2
  subnet_id      = aws_subnet.subnets[count.index].id
  route_table_id = aws_route_table.public_route_table.id
}

# Private Route Table

resource "aws_route_table" "private_route_table_1" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ngw1.id
  }
    tags = {
      Name = "Private Routable1"
  }

}

resource "aws_route_table" "private_route_table_2" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ngw2.id
  }
    tags = {
      Name = "Private Routable2"
  }

}

#Nat Gateways
resource "aws_eip" "nat1" {
  #vpc = true
}

resource "aws_nat_gateway" "ngw1" {
  allocation_id = aws_eip.nat1.id
  subnet_id     = aws_subnet.subnets[0].id
}

resource "aws_eip" "nat2" {
  #vpc = true
}

resource "aws_nat_gateway" "ngw2" {
  allocation_id = aws_eip.nat2.id
  subnet_id     = aws_subnet.subnets[1].id
}

# Route Table association - Private

resource "aws_route_table_association" "private_subnet1_association" {
  subnet_id      = aws_subnet.subnets[2].id
  route_table_id = aws_route_table.private_route_table_1.id
}


resource "aws_route_table_association" "private_subnet2_association" {
  subnet_id      = aws_subnet.subnets[4].id
  route_table_id = aws_route_table.private_route_table_1.id
}


resource "aws_route_table_association" "private_subnet3_association" {
  subnet_id      = aws_subnet.subnets[3].id
  route_table_id = aws_route_table.private_route_table_2.id
}


resource "aws_route_table_association" "private_subnet4_association" {
  subnet_id      = aws_subnet.subnets[5].id
  route_table_id = aws_route_table.private_route_table_2.id
}

# Application Load Balancer

resource "aws_lb_target_group" "Web_target_group" {
  health_check {
    interval            = 10
    path                = "/"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }

  name        = "my-test-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.myvpc.id
}
resource "aws_lb" "my-alb" {
  name     = "my-alb"
  internal = false
  ip_address_type    = "ipv4"
  load_balancer_type = "application"

  security_groups = [aws_security_group.private_sg.id]
  subnets = [aws_subnet.subnets[2].id, aws_subnet.subnets[3].id]
  tags = {
    Name = "Web Balancer"
  }

}

resource "aws_lb_listener" "Web_listner" {
  load_balancer_arn = "${aws_lb.my-alb.arn}"
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.Web_target_group.arn
  }

tags = {
	Name = "Web Load Balancer"
}
}

# Application Autoscaling
resource "aws_launch_configuration" "Web_launch_config" {
  name_prefix          = "App-launch-config"
  image_id             = "ami-0ded8326293d3201b" 
  instance_type        = "t2.micro"  
  security_groups      = [aws_security_group.private_sg.id]
  key_name             = "web" 
  user_data            = <<EOF
    #!/bin/bash
    echo "Hi, World!" > /tmp/greeting.txt
  EOF
  # Other configuration attributes as needed
}

resource "aws_autoscaling_group" "Web_autoscaling_group" {
  name_prefix                 = "Web-asg"
  launch_configuration       = aws_launch_configuration.Web_launch_config.name
  min_size                   = 1  # Minimum number of instances in the Auto Scaling group
  max_size                   = 4  # Maximum number of instances in the Auto Scaling group
  desired_capacity           = 2  # Desired number of instances in the Auto Scaling group
  vpc_zone_identifier        = [aws_subnet.subnets[2].id, aws_subnet.subnets[4].id]
  target_group_arns          = [aws_lb_target_group.Web_target_group.arn]
  health_check_type          = "ELB"  # Use ELB health checks (ALB)

}

resource "aws_autoscaling_policy" "Web-p" {
  name                   = "project-asp"
  scaling_adjustment     = 2
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.Web_autoscaling_group.name
}

resource "aws_autoscaling_attachment" "Wlb_attachment" {
  autoscaling_group_name = aws_autoscaling_group.Web_autoscaling_group.name
  lb_target_group_arn   = aws_lb_target_group.Web_target_group.arn
}


resource "aws_cloudwatch_metric_alarm" "Web-cw-ma" {
  alarm_name          = "app-asg-cwa"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 30

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.Web_autoscaling_group.name
  }
}

# Public Load Balancer

resource "aws_lb_target_group" "Public_target_group" {
  health_check {
    interval            = 10
    path                = "/"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }

  name        = "my-Public-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.myvpc.id
}
resource "aws_lb" "public-plb" {
  name     = "public-plb"
  internal = false

  security_groups = [
    aws_security_group.public_sg.id 
    ]

  subnets = [aws_subnet.subnets[0].id, aws_subnet.subnets[1].id]
  
  tags = {
    Name = "Public Balancer"
  }

  ip_address_type    = "ipv4"
  load_balancer_type = "application"
}

resource "aws_lb_listener" "Public_listner" {
  load_balancer_arn = "${aws_lb.public-plb.arn}"
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.Public_target_group.arn
  }

tags = {
	Name = "Public Load Balancer"
}
}

# Public Autoscaling
resource "aws_launch_configuration" "Public_launch_config" {
  name_prefix          = "Public-launch-config"
  image_id             = "ami-0ded8326293d3201b" 
  instance_type        = "t2.micro"  
  security_groups      = [aws_security_group.public_sg.id]
  key_name             = "web" 
  associate_public_ip_address = true
  user_data            = <<EOF
    #!/bin/bash
    echo "Hello, World!" > /tmp/greeting.txt
  EOF
  # Other configuration attributes as needed

}

resource "aws_autoscaling_group" "Public_autoscaling_group" {
  name_prefix                 = "Public-asg"
  launch_configuration       = aws_launch_configuration.Public_launch_config.name
  min_size                   = 1  # Minimum number of instances in the Auto Scaling group
  max_size                   = 4  # Maximum number of instances in the Auto Scaling group
  desired_capacity           = 2  # Desired number of instances in the Auto Scaling group
  vpc_zone_identifier        = [aws_subnet.subnets[0].id, aws_subnet.subnets[1].id]
  target_group_arns          = [aws_lb_target_group.Public_target_group.arn]
  health_check_type          = "ELB"  # Use ELB health checks (ALB)

}

resource "aws_autoscaling_policy" "ps-p" {
  name                   = "project-psp"
  scaling_adjustment     = 2
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.Public_autoscaling_group.name
}

resource "aws_cloudwatch_metric_alarm" "Public-cw-ma" {
  alarm_name          = "app-asg-cwa"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 30

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.Public_autoscaling_group.name
  }
}

resource "aws_autoscaling_attachment" "Plb_attachment" {
  autoscaling_group_name = aws_autoscaling_group.Public_autoscaling_group.name
  lb_target_group_arn   = aws_lb_target_group.Public_target_group.arn
}
