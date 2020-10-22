output "instance_public_ip" {
  value = aws_instance.provision_key.public_ip
}

output "my_ip" {
  value = local.ifconfig_co_json.ip
}