output "repository_urls" {
  description = "Map tên repository -> URL (dùng cho Jenkins push image)"
  value       = { for name, repo in aws_ecr_repository.this : name => repo.repository_url }
}

output "repository_arns" {
  description = "Map tên repository -> ARN"
  value       = { for name, repo in aws_ecr_repository.this : name => repo.arn }
}
