# ECRリポジトリ
resource "aws_ecr_repository" "line_bot" {
  name                 = "${var.project_name}-${var.environment}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# ECRライフサイクルポリシー
resource "aws_ecr_lifecycle_policy" "line_bot" {
  repository = aws_ecr_repository.line_bot.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "古いイメージを削除"
      selection = {
        tagStatus   = "untagged"
        countType   = "sinceImagePushed"
        countUnit   = "days"
        countNumber = 14
      }
      action = {
        type = "expire"
      }
    }]
  })
}
