resource "aws_ecs_cluster" "production" {
  name = "${var.ecs_cluster_name}-cluster"
}

data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

# Launch Template (replacing Launch Configuration)
resource "aws_launch_template" "ecs" {
  name = "${var.ecs_cluster_name}-cluster"

  image_id      = data.aws_ssm_parameter.ecs_ami.value 
  instance_type = var.instance_type
  key_name      = aws_key_pair.production.key_name

  update_default_version = true
  network_interfaces {
    associate_public_ip_address = true      
    security_groups             = [aws_security_group.ecs.id]
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs.name
  }

  # ECS agent configuration to register instances with cluster
  # user_data = base64encode(<<-EOF
  #   #!/bin/bash
  #   echo "ECS_CLUSTER=${var.ecs_cluster_name}-cluster" >> /etc/ecs/ecs.config
  #   echo "ECS_BACKEND_HOST=" >> /etc/ecs/ecs.config
  #   systemctl enable --now ecs
  # EOF
  # )
  user_data = base64encode(<<-EOF
  #!/bin/bash
  set -ex

  # Ensure ECS config directory exists
  mkdir -p /etc/ecs

  # Configure ECS cluster name and backend host
  echo "ECS_CLUSTER=${var.ecs_cluster_name}-cluster" > /etc/ecs/ecs.config
  echo "ECS_BACKEND_HOST=" >> /etc/ecs/ecs.config

  # Update packages (Amazon Linux 2023 uses dnf)
  dnf update -y

  # Install any required utilities (ecs-init already baked in, but safe)
  dnf install -y awslogs jq

  # Enable and start ECS service
  systemctl daemon-reload
  systemctl enable --now ecs

  # Wait and confirm ECS started successfully
  sleep 10
  systemctl status ecs || true

  # Log completion
  echo "ECS agent started successfully on $(hostname) at $(date)" >> /var/log/user-data.log
EOF
)



  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.ecs_cluster_name}-ecs-instance"
    }
  }
}


locals {
  container_definitions = templatefile("templates/django_app.json.tpl", {
    docker_image_url_django = var.docker_image_url_django
    region                  = var.region
  })
}

resource "aws_ecs_task_definition" "app" {
  family                = "django-app"
  container_definitions = local.container_definitions
}

resource "aws_ecs_service" "production" {
  name            = "${var.ecs_cluster_name}-service"
  cluster         = aws_ecs_cluster.production.id
  task_definition = aws_ecs_task_definition.app.arn
  iam_role        = aws_iam_role.ecs-service-role.arn
  desired_count   = var.app_count
  depends_on      = [aws_alb_listener.ecs-alb-http-listener, aws_iam_role_policy.ecs-service-role-policy]

  load_balancer {
    target_group_arn = aws_alb_target_group.default-target-group.arn
    container_name   = "django-app"
    container_port   = 8000
  }
}