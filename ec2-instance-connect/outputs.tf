output "instance_public_ip" {
  value = aws_instance.instance_connect.public_ip
}

output "my_ip" {
  value = local.ifconfig_co_json.ip
}

# Ugly export, but this is just for test. Never output your credentials...
output "aws_access_key_id" {
  value = aws_iam_access_key.instance_connect.id
}

# Ugly export, but this is just for test. Never output your credentials...
output "aws_secret_access_key" {
  value = aws_iam_access_key.instance_connect.secret
}

output "instance_id" {
  value = aws_instance.instance_connect.id
}

output "instance_az" {
  value = aws_instance.instance_connect.availability_zone
}

output "instance_connect_user" {
  value = aws_iam_user.instance_connect.name
}

output "instance_name" {
  value = aws_instance.instance_connect.tags["Name"]
}