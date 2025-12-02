# ------------------------------------------------------------------------------
# TRANSIT GATEWAY MODULE - OUTPUTS
# Values needed by VPC attachments and route configurations
# ------------------------------------------------------------------------------

output "transit_gateway_id" {
  description = "ID of the Transit Gateway"
  value       = aws_ec2_transit_gateway.this.id
}

output "transit_gateway_arn" {
  description = "ARN of the Transit Gateway"
  value       = aws_ec2_transit_gateway.this.arn
}

output "transit_gateway_owner_id" {
  description = "Account ID that owns the Transit Gateway"
  value       = aws_ec2_transit_gateway.this.owner_id
}

# Route table IDs - needed when attaching VPCs
output "prod_route_table_id" {
  description = "ID of the production route table"
  value       = aws_ec2_transit_gateway_route_table.prod.id
}

output "dev_route_table_id" {
  description = "ID of the development route table"
  value       = aws_ec2_transit_gateway_route_table.dev.id
}

output "shared_route_table_id" {
  description = "ID of the shared services route table"
  value       = aws_ec2_transit_gateway_route_table.shared.id
}

# RAM share ARN - needed to share with other accounts
output "ram_share_arn" {
  description = "ARN of the RAM resource share for cross-account access"
  value       = aws_ram_resource_share.transit_gateway.arn
}

# Convenience output for VPC attachment configuration
output "route_table_ids" {
  description = "Map of route table IDs by environment"
  value = {
    prod   = aws_ec2_transit_gateway_route_table.prod.id
    dev    = aws_ec2_transit_gateway_route_table.dev.id
    shared = aws_ec2_transit_gateway_route_table.shared.id
  }
}