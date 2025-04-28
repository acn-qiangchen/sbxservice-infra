output "portal_bucket_name" {
  description = "Name of the S3 bucket hosting the portal content"
  value       = aws_s3_bucket.portal.id
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.portal.domain_name
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.portal.id
} 