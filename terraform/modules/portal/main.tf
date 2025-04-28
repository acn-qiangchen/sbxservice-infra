# S3 bucket for static website content
resource "aws_s3_bucket" "portal" {
  bucket = "${var.project_name}-${var.environment}-portal-${random_string.bucket_suffix.result}"
  
  tags = {
    Name = "${var.project_name}-${var.environment}-portal"
  }
}

# Generate a random suffix for globally unique S3 bucket name
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# S3 bucket access block - make it private
resource "aws_s3_bucket_public_access_block" "portal" {
  bucket = aws_s3_bucket.portal.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket ownership controls
resource "aws_s3_bucket_ownership_controls" "portal" {
  bucket = aws_s3_bucket.portal.id
  
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# CloudFront Origin Access Identity (OAI)
resource "aws_cloudfront_origin_access_identity" "portal_oai" {
  comment = "OAI for ${var.project_name}-${var.environment} portal"
}

# S3 bucket policy allowing CloudFront access
resource "aws_s3_bucket_policy" "portal" {
  bucket = aws_s3_bucket.portal.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          AWS = "arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity ${aws_cloudfront_origin_access_identity.portal_oai.id}"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.portal.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.portal]
}

# Process HTML file to replace API Gateway URL
locals {
  html_content = templatefile("${path.module}/../../portal/index.html", 
    { API_GATEWAY_URL = var.api_gateway_url }
  )
}

# Upload index.html to S3
resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.portal.id
  key          = "index.html"
  content      = local.html_content
  content_type = "text/html"
  etag         = md5(local.html_content)
}

# CloudFront distribution
resource "aws_cloudfront_distribution" "portal" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  comment             = "${var.project_name}-${var.environment} portal distribution"
  
  origin {
    domain_name = aws_s3_bucket.portal.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.portal.id}"
    
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.portal_oai.cloudfront_access_identity_path
    }
  }
  
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${aws_s3_bucket.portal.id}"
    viewer_protocol_policy = "redirect-to-https"
    
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    
    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }
  
  # Standard cache policy for CloudFront
  price_class = "PriceClass_100"  # Use only North America and Europe edge locations
  
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  
  viewer_certificate {
    cloudfront_default_certificate = true
  }
  
  tags = {
    Name = "${var.project_name}-${var.environment}-portal-distribution"
  }
}

# Custom response headers policy for CORS
resource "aws_cloudfront_response_headers_policy" "cors_policy" {
  name = "${var.project_name}-${var.environment}-cors-policy"
  
  cors_config {
    access_control_allow_credentials = false
    
    access_control_allow_headers {
      items = ["*"]
    }
    
    access_control_allow_methods {
      items = ["GET", "HEAD", "OPTIONS"]
    }
    
    access_control_allow_origins {
      items = ["*"]
    }
    
    origin_override = true
  }
} 