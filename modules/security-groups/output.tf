output "alb_sg_id" {
    description = "Security group ID for the public ALB"
    value       = aws_security_group.alb.id
}

output "eks_cluster_sg_id" {
    description = "Security group ID attached to the EKS control plane"
    value       = aws_security_group.eks_cluster.id
}

output "eks_nodes_sg_id" {
    description = "Security group ID attached to EKS worker nodes"
    value       = aws_security_group.eks_nodes.id
}

output "rds_sg_id" {
    description = "Security group ID for the Airflow RDS Postgres instance"
    value       = aws_security_group.rds.id
}

output "vpc_endpoints_sg_id" {
    description = "Security group ID for interface VPC endpoints"
    value       = aws_security_group.vpc_endpoints.id
}
