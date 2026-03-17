output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.postgres.address
  sensitive   = true
}

output "redis_endpoint" {
  description = "ElastiCache Redis primary endpoint"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
  sensitive   = true
}

output "s3_bucket_name" {
  description = "S3 receipts bucket name"
  value       = aws_s3_bucket.receipts.bucket
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.main.id
}

output "cognito_client_id" {
  description = "Cognito mobile app client ID"
  value       = aws_cognito_user_pool_client.mobile.id
  sensitive   = true
}

output "ecr_repositories" {
  description = "ECR repository URLs keyed by service name"
  value = {
    for k, v in aws_ecr_repository.services : k => v.repository_url
  }
}

output "sqs_queue_urls" {
  description = "SQS queue URLs"
  value = {
    for k, v in aws_sqs_queue.main : k => v.url
  }
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}
