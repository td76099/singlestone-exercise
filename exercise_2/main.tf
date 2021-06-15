provider "aws" {
    region = "us-east-1"
}

resource "aws_security_group" "web-server-sg" {
  name = "web-server-sg"
  description = "Allow TLS inbound traffic"

  ingress {
    description = "web traffic"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description = "ssh"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_security_group" "web-lb-sg" {
  name = "web-lb-sg"
  description = "Allow TLS inbound traffic"

  ingress {
    description = "web traffic"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_launch_configuration" "web-conf" {
  name_prefix   = "web-"
  image_id      = "ami-09d8b5222f2b93bf0"
  instance_type = "t2.micro"
  security_groups = [aws_security_group.web-server-sg.id]
  associate_public_ip_address = true

  user_data = <<-EOF
    #! /bin/bash
    yum update
    yum -y install nginx
    echo "$(curl https://raw.githubusercontent.com/td76099/singlestone-exercise/main/exercise_2/frontend/index.html)" > /usr/share/nginx/html/index.html
    chkconfig nginx on
    service nginx start
    EOF
  

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "web-as" {
  name = "web-as"
  #launch_configuration = aws_launch_configuration.web-conf
  min_size = 1
  desired_capacity = 2
  max_size = 3
  load_balancers = [aws_elb.web-lb.id]
  launch_configuration = aws_launch_configuration.web-conf.name

  availability_zones = ["us-east-1a", "us-east-1b"]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_policy" "web_policy_up" {
    name = "web_policy_up"
    scaling_adjustment = 1
    adjustment_type = "ChangeInCapacity"
    cooldown = 300
    autoscaling_group_name = aws_autoscaling_group.web-as.name
}

resource "aws_autoscaling_policy" "web_policy_down" {
    name = "web_policy_down"
    scaling_adjustment = -1
    adjustment_type = "ChangeInCapacity"
    cooldown = 300
    autoscaling_group_name = aws_autoscaling_group.web-as.name
}

resource "aws_elb" "web-lb" {
  name = "web-lb"
  internal = false
  security_groups = [aws_security_group.web-lb-sg.id]
  
  subnets = [
      "subnet-0d1b562c",
      "subnet-19180f54"
  ]

  listener{
      lb_port = 80
      lb_protocol = "http"
      instance_port = 80
      instance_protocol = "http"
  }
}