# HTTPS Support and SSL Termination Architecture

## Overview

This document details how HTTPS support is implemented in the sbxservice infrastructure, with SSL termination occurring at the Application Load Balancer (ALB).

## Architecture Diagram

```
                                           VPC
+----------------+     +----------------------------------------------------------+
|                |     |  +----------------+                                      |
|                |     |  | Public Subnet  |                                      |
|                |     |  | (Firewall)     |                                      |
|                |     |  +--------+-------+                                      |
|                |     |           |                                              |
|                |     |           v                                              |
|                |     |  +--------+-------+     +----------------+               |
|                |     |  | Public Subnet  |     | Private Subnet |               |
| Internet       +-----+->| (ALB)          +---->| (ECS Tasks)    |               |
| HTTPS          |     |  | SSL Termination|     |                |               |
|                |     |  +----------------+     +----------------+               |
|                |     |                                                          |
+----------------+     +----------------------------------------------------------+

Traffic Flow:
1. HTTPS Traffic from Internet -> Internet Gateway
2. Internet Gateway -> Network Firewall (in public subnet)
3. Network Firewall -> ALB (in public subnet)
4. ALB performs SSL termination, converting HTTPS to HTTP
5. ALB -> Network Firewall -> ECS Tasks (in private subnet) using HTTP
6. ECS Tasks -> Network Firewall -> ALB (for return traffic)
7. ALB encrypts traffic back to HTTPS
8. ALB -> Network Firewall -> Internet Gateway -> Internet (for return traffic)
```

## SSL Termination at ALB

SSL termination at the ALB offers several benefits:

1. **Reduced Application Complexity**: The application doesn't need to handle SSL/TLS certificates or encryption.
2. **Centralized Certificate Management**: Certificates are managed at a single point (the ALB) using AWS Certificate Manager (ACM).
3. **Improved Performance**: The ALB handles the computational overhead of SSL/TLS encryption/decryption.
4. **Enhanced Security**: The Network Firewall inspects all traffic both before and after the ALB.

## Implementation Details

### 1. SSL Certificate Configuration

SSL certificates are managed using AWS Certificate Manager (ACM). The certificate ARN is provided via the `ssl_certificate_arn` variable.

```hcl
variable "ssl_certificate_arn" {
  description = "ARN of the SSL certificate for HTTPS termination"
  type        = string
  default     = ""
}
```

### 2. HTTPS Listener Configuration

The ALB is configured with an HTTPS listener on port 443 (configurable) that terminates SSL connections:

```hcl
resource "aws_lb_listener" "https" {
  count             = var.enable_https && var.ssl_certificate_arn != "" ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = var.https_port
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.ssl_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
```

### 3. HTTP to HTTPS Redirection

For enhanced security, HTTP traffic can be automatically redirected to HTTPS:

```hcl
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = var.enable_https && var.redirect_http_to_https ? "redirect" : "forward"

    dynamic "redirect" {
      for_each = var.enable_https && var.redirect_http_to_https ? [1] : []
      content {
        port        = var.https_port
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    dynamic "forward" {
      for_each = (!var.enable_https || !var.redirect_http_to_https) ? [1] : []
      content {
        target_group {
          arn = aws_lb_target_group.app.arn
        }
      }
    }
  }
}
```

### 4. Security Group Configuration

The ALB's security group allows incoming HTTPS traffic on port 443:

```hcl
ingress {
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  description = "HTTPS access from anywhere"
}
```

## Traffic Inspection and Security

1. **Inbound Traffic**: All HTTPS traffic passes through the Network Firewall before reaching the ALB.
2. **Post-Decryption Inspection**: After SSL termination, the unencrypted HTTP traffic between the ALB and ECS tasks can be inspected by security tools.
3. **Outbound Traffic**: All traffic from the ALB to the internet passes through the Network Firewall.

## Configuration Options

The HTTPS support can be customized using the following variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `enable_https` | Whether to enable HTTPS for the ALB | `true` |
| `ssl_certificate_arn` | ARN of the SSL certificate | `""` |
| `https_port` | Port for HTTPS traffic | `443` |
| `redirect_http_to_https` | Whether to redirect HTTP to HTTPS | `true` |

## Setting Up SSL Certificates

To set up SSL certificates for HTTPS:

1. Request a certificate in AWS Certificate Manager (ACM)
2. Validate domain ownership via DNS or email
3. Once validated, use the certificate ARN in the `ssl_certificate_arn` variable

Example:
```
ssl_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
```

## Health Checks and Monitoring

The ALB performs health checks on the ECS tasks using HTTP:

```hcl
health_check {
  path                = "/actuator/health"
  interval            = 30
  timeout             = 5
  healthy_threshold   = 3
  unhealthy_threshold = 3
  matcher             = "200"
}
``` 