resource "aws_ecr_repository" "frontend" {
  name                 = "frontend"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = local.env
    Project     = local.eks_name
  }
}

output "ecr_repository_url" {
  value       = aws_ecr_repository.frontend.repository_url
  description = "The URL of the ECR repository for the frontend"
}
