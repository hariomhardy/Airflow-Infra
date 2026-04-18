output "vpc_id" {
    value = module.vpc.vpc_id
}

output "public_subnet_ids" {
    value = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
    value = module.vpc.private_subnet_ids
}

output "nat_gateway_id" {
    value = module.vpc.nat_gateway_id
}

output "alb_sg_id" {
    value = module.security_groups.alb_sg_id
}

output "eks_cluster_sg_id" {
    value = module.security_groups.eks_cluster_sg_id
}

output "eks_nodes_sg_id" {
    value = module.security_groups.eks_nodes_sg_id
}

output "rds_sg_id" {
    value = module.security_groups.rds_sg_id
}

output "vpc_endpoints_sg_id" {
    value = module.security_groups.vpc_endpoints_sg_id
}