# =============================================================================
# Parameter Store パラメータ
# =============================================================================

resource "aws_ssm_parameter" "google_maps_api_key" {
  name        = "/${var.project_name}/${var.environment}/GOOGLE_MAPS_API_KEY"
  description = "Google Maps API Key"
  type        = "SecureString"
  value       = var.google_maps_api_key

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "channel_access_token" {
  name        = "/${var.project_name}/${var.environment}/CHANNEL_ACCESS_TOKEN"
  description = "LINE Channel Access Token"
  type        = "SecureString"
  value       = var.channel_access_token

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }

  lifecycle {
    ignore_changes = [value]
  }
}
