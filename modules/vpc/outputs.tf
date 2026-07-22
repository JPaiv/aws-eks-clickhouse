output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.this.cidr_block
}

output "private_subnet_ids" {
  description = "IDs of the private subnets (nodes and pods)"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets (load balancers, NAT)"
  value       = aws_subnet.public[*].id
}

output "private_route_table_ids" {
  description = "IDs of the per-AZ private route tables"
  value       = aws_route_table.private[*].id
}

output "nat_gateway_public_ips" {
  description = "Public IPs egress traffic leaves through"
  value       = aws_eip.nat[*].public_ip
}
