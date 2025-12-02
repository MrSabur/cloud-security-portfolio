# ------------------------------------------------------------------------------
# TRANSIT GATEWAY ATTACHMENT - OUTPUTS
# ------------------------------------------------------------------------------

output "attachment_id" {
  description = "ID of the Transit Gateway VPC attachment"
  value       = aws_ec2_transit_gateway_vpc_attachment.this.id
}

output "vpc_id" {
  description = "ID of the attached VPC"
  value       = aws_ec2_transit_gateway_vpc_attachment.this.vpc_id
}