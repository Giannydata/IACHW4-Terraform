output "instance1_ip" {
  description = "The public IP of the first instance"
  value       = aws_instance.DBServer1.public_ip
}

output "instance2_ip" {
  description = "The public IP of the second instance"
  value       = aws_instance.DBServer2.public_ip
}

output "RDSendpoint" {
  description = "The endpoint of the RDS instance"
  value       = aws_db_instance.DBInstance.endpoint
}