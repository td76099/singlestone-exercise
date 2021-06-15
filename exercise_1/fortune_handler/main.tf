provider "aws" {
    region = "us-east-1"
}

data "archive_file" "pythonstuff" {
    type = "zip"
    source_dir = "./pythonstuff/"
    output_path = "./pythonstuff.zip"
}

resource "aws_iam_role" "fortune-lambda-iam" {
  name = "fortune-lambda-iam"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_lambda_function" "fortune-handler" {
  depends_on = [aws_iam_role.fortune-lambda-iam]
  filename = "pythonstuff.zip"
  function_name = "app"
  role = aws_iam_role.fortune-lambda-iam.arn
  handler = "app.lambda_handler"

  source_code_hash = filebase64sha256("./pythonstuff.zip")

  runtime = "python3.8"
}

################LB below#####################

resource "aws_security_group" "fortune-lb-sg" {
  name = "fortune-lb-sg"
  description = "Allow TLS inbound traffic"

  ingress {
    description = "security group for fortune LB"
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

resource "aws_lb_target_group" "fortune-lb-target-group" {
  name = "fortune-lb-target-group"
  target_type = "lambda"
}

resource "aws_lambda_permission" "fortune-lambda-permission" {
  statement_id  = "AllowExecutionFromlb"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fortune-handler.arn
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.fortune-lb-target-group.arn
}

resource "aws_lb_target_group_attachment" "fortune-target-group-attachment" {
  depends_on = [aws_lambda_permission.fortune-lambda-permission]
  target_group_arn = aws_lb_target_group.fortune-lb-target-group.arn
  target_id = aws_lambda_function.fortune-handler.arn
}

resource "aws_lb_listener" "fortune-lb-listener" {
  load_balancer_arn = aws_lb.fortune-lb-listener.arn
  port = "80"
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.fortune-lb-target-group.arn
  }
}

resource "aws_lb" "fortune-lb-listener" {
  name = "fortune-lb-listener"
  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.fortune-lb-sg.id]
  
  subnet_mapping{
      subnet_id = "subnet-0d1b562c"
  }
  subnet_mapping{
      subnet_id = "subnet-19180f54"
  }

  enable_deletion_protection = false

}