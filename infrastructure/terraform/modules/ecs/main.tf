# ECR Repository
resource "aws_ecr_repository" "app" {
  name                 = "${var.project_name}-${var.environment}-repo"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-ecr"
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-${var.environment}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-cluster"
  }
}

# ECS Task Execution Role
resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.project_name}-${var.environment}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-execution-role"
  }
}

# Attach the AWS managed policy for ECS task execution
resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Attach App Mesh and X-Ray permissions to the execution role
resource "aws_iam_role_policy_attachment" "ecs_execution_role_appmesh_policy" {
  count      = var.service_mesh_enabled ? 1 : 0
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSAppMeshEnvoyAccess"
}

# ECS Task Role
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-${var.environment}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-task-role"
  }
}

# Create a policy for CloudWatch Logs
resource "aws_iam_policy" "task_logs_policy" {
  name        = "${var.project_name}-${var.environment}-task-logs-policy"
  description = "Allow ECS tasks to send logs to CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

# Create a policy for App Mesh
resource "aws_iam_policy" "app_mesh_policy" {
  count       = var.service_mesh_enabled ? 1 : 0
  name        = "${var.project_name}-${var.environment}-appmesh-policy"
  description = "Allow ECS tasks to use App Mesh"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "appmesh:StreamAggregatedResources",
          "servicediscovery:DiscoverInstances"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach CloudWatch logs policy to task role
resource "aws_iam_role_policy_attachment" "task_logs" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.task_logs_policy.arn
}

# Attach App Mesh policy to task role
resource "aws_iam_role_policy_attachment" "task_app_mesh" {
  count      = var.service_mesh_enabled ? 1 : 0
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.app_mesh_policy[0].arn
}

# Attach X-Ray permissions to the task role
resource "aws_iam_role_policy_attachment" "task_xray" {
  count      = var.service_mesh_enabled ? 1 : 0
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project_name}-${var.environment}"
  retention_in_days = 30

  tags = {
    Name = "${var.project_name}-${var.environment}-logs"
  }
}

# CloudWatch Log Group for App Mesh Envoy
resource "aws_cloudwatch_log_group" "envoy" {
  count             = var.service_mesh_enabled ? 1 : 0
  name              = "/ecs/${var.project_name}-${var.environment}-envoy"
  retention_in_days = 30

  tags = {
    Name = "${var.project_name}-${var.environment}-envoy-logs"
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project_name}-${var.environment}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  
  # If App Mesh is enabled, add the necessary proxy configuration
  dynamic "proxy_configuration" {
    for_each = var.service_mesh_enabled ? [1] : []
    
    content {
      type           = "APPMESH"
      container_name = "envoy"
      properties = {
        AppPorts         = var.container_port
        EgressIgnoredIPs = "169.254.170.2,169.254.169.254"
        IgnoredUID       = "1337"
        ProxyEgressPort  = 15001
        ProxyIngressPort = 15000
      }
    }
  }

  # Define container definitions with conditional App Mesh configuration
  container_definitions = var.service_mesh_enabled ? jsonencode([
    # Application container
    {
      name      = "${var.project_name}-${var.environment}-container"
      image     = "${aws_ecr_repository.app.repository_url}:latest"
      cpu       = var.task_cpu - 256 - 32 # Reserve some CPU for the Envoy proxy and X-Ray daemon
      memory    = var.task_memory - 128 - 64 # Reserve some memory for the Envoy proxy and X-Ray daemon
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}/actuator/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
      environment = [
        {
          name  = "APPMESH_VIRTUAL_NODE_NAME"
          value = "mesh/${var.mesh_name}/virtualNode/${var.virtual_node_name}"
        }
      ]
      dependsOn = [
        {
          containerName = "envoy"
          condition     = "HEALTHY"
        }
      ]
    },
    # Envoy proxy container
    {
      name      = "envoy"
      image     = "840364872350.dkr.ecr.${var.region}.amazonaws.com/aws-appmesh-envoy:v1.18.3.0-prod"
      essential = true
      cpu       = 256
      memory    = 128
      user      = "1337"
      environment = [
        {
          name  = "APPMESH_VIRTUAL_NODE_NAME"
          value = "mesh/${var.mesh_name}/virtualNode/${var.virtual_node_name}"
        },
        {
          name  = "ENABLE_ENVOY_XRAY_TRACING"
          value = "1"
        }
      ]
      healthCheck = {
        command     = ["CMD-SHELL", "curl -s http://localhost:9901/server_info | grep state | grep -q LIVE"]
        interval    = 5
        timeout     = 2
        retries     = 3
        startPeriod = 10
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.envoy[0].name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "envoy"
        }
      }
    },
    # X-Ray daemon container
    {
      name      = "xray-daemon"
      image     = "amazon/aws-xray-daemon:latest"
      essential = true
      cpu       = 32
      memory    = 64
      portMappings = [
        {
          containerPort = 2000
          hostPort      = 2000
          protocol      = "udp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "xray"
        }
      }
    }
  ]) : jsonencode([
    # Standard container without App Mesh
    {
      name      = "${var.project_name}-${var.environment}-container"
      image     = "${aws_ecr_repository.app.repository_url}:latest"
      cpu       = var.task_cpu
      memory    = var.task_memory
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}/actuator/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-${var.environment}-task-definition"
  }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.public_sg_id]
  subnets            = var.public_subnets

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-${var.environment}-alb"
  }
}

# Target Group for ALB
resource "aws_lb_target_group" "app" {
  name        = "${var.project_name}-${var.environment}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/actuator/health"
    port                = "traffic-port"
    matcher             = "200"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-target-group"
  }
}

# Listener for ALB
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# ECS Service
resource "aws_ecs_service" "app" {
  name            = "${var.project_name}-${var.environment}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.app_count
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [var.application_sg_id]
    subnets          = var.private_subnets
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "${var.project_name}-${var.environment}-container"
    container_port   = var.container_port
  }

  # Service discovery registration for App Mesh
  dynamic "service_registries" {
    for_each = var.service_mesh_enabled ? [1] : []
    content {
      registry_arn = var.service_discovery_arn
    }
  }

  depends_on = [
    aws_lb_listener.front_end
  ]

  tags = {
    Name = "${var.project_name}-${var.environment}-service"
  }
} 