output "instance_id" {
  value = aws_instance.this.id

  description = "The ID of the EC2 instance"
}

output "instance_public_ip" {
  value = aws_eip.this.public_ip

  description = "The public IP address of the EC2 instance"
}

output "ssh_key_file_name" {
  value = aws_key_pair.this.key_name

  description = "The name of the file that contains the private SSH key used by the EC2 instance"
}
