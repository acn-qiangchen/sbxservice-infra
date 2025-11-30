# Security group for public-facing resources (e.g., ALB)
resource "aws_security_group" "public" {
  name        = "sbxservice-${var.environment}-public-sg"
  description = "Security group for public-facing resources"
  vpc_id      = var.vpc_id

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access from anywhere"
  }

  # HTTPS access from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access from anywhere"
  }

  # Kong Admin GUI access from anywhere (port 8002)
  ingress {
    from_port   = 8002
    to_port     = 8002
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Kong Admin GUI access from anywhere"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "sbxservice-${var.environment}-public-sg"
  }
}

# Security group for application services
resource "aws_security_group" "application" {
  name        = "sbxservice-${var.environment}-app-sg"
  description = "Security group for application services"
  vpc_id      = var.vpc_id

  # Allow traffic from the public security group
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.public.id]
    description     = "Allow traffic from the public security group"
  }

  # Allow internal traffic within this security group
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    description = "Allow internal traffic within this security group"
  }

  # Allow all traffic from within the VPC
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
    description = "Allow all traffic from within the VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "sbxservice-${var.environment}-app-sg"
  }
}

# Security group for databases
resource "aws_security_group" "database" {
  name        = "sbxservice-${var.environment}-db-sg"
  description = "Security group for database instances"
  vpc_id      = var.vpc_id

  # Allow traffic from the application security group
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.application.id]
    description     = "Allow traffic from the application security group"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "sbxservice-${var.environment}-db-sg"
  }
} 