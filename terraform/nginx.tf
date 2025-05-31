### IAM Roles for ECS Task Execution and Task ###
locals {
  appName = "nginx"
}

resource "aws_iam_role" "task_execution_role" {
  name = "${local.appName}-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role" "task_role" {
  name = "${local.appName}-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })
}  

### attach policy AmazonECSTaskExecutionRolePolicy ###
resource "aws_iam_role_policy_attachment" "task_execution_policy" {
  role       = aws_iam_role.task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  depends_on = [ aws_iam_role.task_execution_role ]
}

### attach policy AmazonSSMManagedInstanceCore ###
resource "aws_iam_role_policy_attachment" "task_role_policy" {
  role       = aws_iam_role.task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  depends_on = [ aws_iam_role.task_role ]
}


### ECS Task Definition for Service ###

resource "aws_ecs_task_definition" "nginx" {
  family = "nginx"
  network_mode = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu = "256"
  memory = "512"
  execution_role_arn = aws_iam_role.task_execution_role.arn
  task_role_arn = aws_iam_role.task_role.arn
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture = "X86_64"
  }
  container_definitions = jsonencode([
    {
      "name": "nginx",
      "image": "nginx:latest",
      "cpu": 0,
      "portMappings": [
        {
          "containerPort": 80,
          "hostPort": 80,
          "protocol": "tcp",
          "name": "nginx-80-tcp",
          "appProtocol": "http"
        }
      ],
      "essential": true,
      "environment": [],
      "environmentFiles": [],
      "mountPoints": [],
      "volumesFrom": [],
      "ulimits": [],
      "systemControls": [],
    }
  ])
}

### nginx Security Group ###
resource "aws_security_group" "nginx_sg" {
  name        = "nginx-sg"
  description = "Security group for Nginx ECS service"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP traffic"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }
}

### ECS Service for Nginx ###
resource "aws_ecs_service" "nginx" {
  name            = "nginx"
  cluster         = module.ecs_cluster.cluster_id 
  task_definition = aws_ecs_task_definition.nginx.arn 
  desired_count   = 1
  enable_execute_command = true
  
  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
  
  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.nginx_sg.id]
    assign_public_ip = false 
  }
}