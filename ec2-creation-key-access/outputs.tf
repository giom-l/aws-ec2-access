output "instance_public_ip" {
  value = aws_instance.simple_ec2.public_ip
}

output "my_ip" {
  value = local.ifconfig_co_json.ip
}