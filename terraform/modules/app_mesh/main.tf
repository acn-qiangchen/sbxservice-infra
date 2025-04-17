# App Mesh Service Mesh
resource "aws_appmesh_mesh" "service_mesh" {
  name = "${var.project_name}-${var.environment}-mesh"

  spec {
    egress_filter {
      type = "ALLOW_ALL"
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-mesh"
  }
}

# App Mesh Virtual Node for the main service
resource "aws_appmesh_virtual_node" "service" {
  name      = "${var.project_name}-${var.environment}-node"
  mesh_name = aws_appmesh_mesh.service_mesh.id

  spec {
    listener {
      port_mapping {
        port     = var.container_port
        protocol = "http"
      }

      health_check {
        protocol            = "http"
        path                = "/actuator/health"
        healthy_threshold   = 2
        unhealthy_threshold = 2
        timeout_millis      = 2000
        interval_millis     = 5000
      }
    }

    service_discovery {
      aws_cloud_map {
        service_name   = var.project_name
        namespace_name = aws_service_discovery_private_dns_namespace.service_discovery.name
      }
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-node"
  }
}

# App Mesh Virtual Router for routing traffic
resource "aws_appmesh_virtual_router" "router" {
  name      = "${var.project_name}-${var.environment}-router"
  mesh_name = aws_appmesh_mesh.service_mesh.id

  spec {
    listener {
      port_mapping {
        port     = var.container_port
        protocol = "http"
      }
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-router"
  }
}

# App Mesh Route for the service
resource "aws_appmesh_route" "service_route" {
  name                = "${var.project_name}-${var.environment}-route"
  mesh_name           = aws_appmesh_mesh.service_mesh.id
  virtual_router_name = aws_appmesh_virtual_router.router.name

  spec {
    http_route {
      match {
        prefix = "/"
      }

      action {
        weighted_target {
          virtual_node = aws_appmesh_virtual_node.service.name
          weight       = 100
        }
      }
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-route"
  }
}

# App Mesh Virtual Service to tie everything together
resource "aws_appmesh_virtual_service" "service" {
  name      = "${var.project_name}.${aws_service_discovery_private_dns_namespace.service_discovery.name}"
  mesh_name = aws_appmesh_mesh.service_mesh.id

  spec {
    provider {
      virtual_router {
        virtual_router_name = aws_appmesh_virtual_router.router.name
      }
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-virtual-service"
  }
}

# AWS Cloud Map Private DNS Namespace for service discovery
resource "aws_service_discovery_private_dns_namespace" "service_discovery" {
  name        = "${var.project_name}.${var.environment}.local"
  description = "Service discovery namespace for ${var.project_name} in ${var.environment}"
  vpc         = var.vpc_id

  tags = {
    Name = "${var.project_name}-${var.environment}-dns-namespace"
  }
}

# AWS Cloud Map Service for service discovery
resource "aws_service_discovery_service" "service" {
  name = var.project_name

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.service_discovery.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-discovery-service"
  }
} 