output "instance_private_ip" {
  value = aws_instance.session_manager.private_ip
}

output "instance_id" {
  value = aws_instance.session_manager.id
}

# Ugly export, but this is just for test. Never output your credentials...
output "aws_access_key_id" {
  value = aws_iam_access_key.session_manager.id
}

# Ugly export, but this is just for test. Never output your credentials...
output "aws_secret_access_key" {
  value = aws_iam_access_key.session_manager.secret
}

output "instance_name" {
  value = aws_instance.session_manager.tags["Name"]
}

output "ssm_document_name" {
  value = aws_ssm_document.session_manager.name
}

output "session_manager_user_arn" {
  value = aws_iam_user.session_manager.arn
}