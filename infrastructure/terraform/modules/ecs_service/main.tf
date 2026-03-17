variable "project" { type = string }
variable "service_name" { type = string }
variable "service_port" { type = number }
variable "cpu" { type = number }
variable "memory" { type = number }
variable "cluster_id" { type = string }
variable "image_uri" { type = string }
variable "subnets" { type = list(string) }
variable "security_group" { type = string }
variable "execution_role" { type = string }
variable "task_role" { type = string }
variable "alb_listener" { type = string }
variable "vpc_id" { type = string }
variable "environment_variables" {
  type = list(object({ name = string, value = string }))
  default = []
}

resource "aws_lb_target_group" "this" {
  name        = "${var.project}-${var.service_name}"
  port        = var.service_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/actuator/health"
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 10
    interval            = 30
    matcher             = "200"
  }
}

resource "aws_lb_listener_rule" "this" {
  listener_arn = var.alb_listener
  priority     = var.service_port - 8000

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  condition {
    path_pattern { values = ["/api/v1/${replace(var.service_name, "-service", "")}/*"] }
  }
}

resource "aws_ecs_task_definition" "this" {
  family                   = "${var.project}-${var.service_name}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.execution_role
  task_role_arn            = var.task_role

  container_definitions = jsonencode([{
    name      = var.service_name
    image     = var.image_uri
    essential = true

    portMappings = [{
      containerPort = var.service_port
      protocol      = "tcp"
    }]

    environment = var.environment_variables

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = "/ecs/${var.project}/${var.service_name}"
        awslogs-region        = "us-east-1"
        awslogs-stream-prefix = "ecs"
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:${var.service_port}/actuator/health || exit 1"]
      interval    = 30
      timeout     = 10
      retries     = 3
      startPeriod = 60
    }
  }])
}

resource "aws_ecs_service" "this" {
  name            = "${var.project}-${var.service_name}-service"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.subnets
    security_groups = [var.security_group]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = var.service_name
    container_port   = var.service_port
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  lifecycle {
    ignore_changes = [task_definition]
  }
}
