# Security groups for hosting Airflow on EKS with RDS Postgres backend.
#
# Why separate aws_security_group_rule resources instead of inline ingress/egress?
#   Two SGs that reference each other (ALB ↔ nodes, cluster ↔ nodes) create a
#   dependency cycle if the references live inside inline blocks — Terraform
#   cannot build either SG until the other's ID is known.
#   Declaring SGs first (with no cross-references) and attaching rules as
#   standalone aws_security_group_rule resources breaks the cycle.


# ALB — public entry point that fronts the Istio ingress gateway in EKS.
# Receives HTTP/HTTPS from the internet and forwards to worker nodes on a
# Kubernetes NodePort (instance-target mode). kube-proxy routes that NodePort
# to the istio-ingressgateway Service, which in turn routes to Airflow pods
# via Istio VirtualService/Gateway rules.
resource "aws_security_group" "alb" {
    name        = "airflow-alb-sg"
    description = "Public ALB fronting the Airflow webserver"
    vpc_id      = var.vpc_id

    tags = {
        Name = "airflow-alb-sg"
    }
}

# EKS control plane — additional SG attached to the cluster's ENIs via
# vpc_config.security_group_ids. AWS also auto-creates a "cluster security
# group"; this one supplements it, not replaces it.
resource "aws_security_group" "eks_cluster" {
    name        = "eks-cluster-sg"
    description = "Additional SG attached to the EKS control plane ENIs"
    vpc_id      = var.vpc_id

    tags = {
        Name = "eks-cluster-sg"
    }
}

# EKS worker nodes — attached to every worker node ENI.
# Hosts Airflow pods (scheduler, webserver, workers, triggerer).
resource "aws_security_group" "eks_nodes" {
    name        = "eks-nodes-sg"
    description = "SG attached to EKS worker node ENIs"
    vpc_id      = var.vpc_id

    tags = {
        Name = "eks-nodes-sg"
    }
}

# RDS Postgres — metadata DB for Airflow.
# Only the EKS nodes SG is allowed to reach it on 5432 (tight lockdown).
resource "aws_security_group" "rds" {
    name        = "airflow-rds-postgres-sg"
    description = "SG for RDS Postgres serving the Airflow metadata DB"
    vpc_id      = var.vpc_id

    tags = {
        Name = "airflow-rds-postgres-sg"
    }
}

# VPC interface endpoints — lets pods reach AWS APIs (ECR, STS, Secrets
# Manager, etc.) privately without going through the NAT Gateway.
# Saves NAT data-processing cost and keeps traffic on the AWS backbone.
resource "aws_security_group" "vpc_endpoints" {
    name        = "vpc-endpoints-sg"
    description = "SG for interface VPC endpoints (ECR, STS, Secrets Manager, etc.)"
    vpc_id      = var.vpc_id

    tags = {
        Name = "vpc-endpoints-sg"
    }
}


# ALB rules
# 80/443 from the internet; egress narrowed to the webserver port on nodes.
resource "aws_security_group_rule" "alb_ingress_http" {
    type              = "ingress"
    security_group_id = aws_security_group.alb.id
    from_port         = 80
    to_port           = 80
    protocol          = "tcp"
    cidr_blocks       = var.alb_ingress_cidrs
    description       = "HTTP from internet"
}

resource "aws_security_group_rule" "alb_ingress_https" {
    type              = "ingress"
    security_group_id = aws_security_group.alb.id
    from_port         = 443
    to_port           = 443
    protocol          = "tcp"
    cidr_blocks       = var.alb_ingress_cidrs
    description       = "HTTPS from internet"
}

# NodePort range (30000-32767 by default) — the Kubernetes-assigned NodePort
# for the istio-ingressgateway Service falls in this range and may change on
# Service recreation, so the full range is opened (from the ALB SG only).
resource "aws_security_group_rule" "alb_egress_to_nodes_nodeport" {
    type                     = "egress"
    security_group_id        = aws_security_group.alb.id
    from_port                = var.nodeport_range_from
    to_port                  = var.nodeport_range_to
    protocol                 = "tcp"
    source_security_group_id = aws_security_group.eks_nodes.id
    description              = "Forward to Istio ingress gateway NodePort on worker nodes"
}


# EKS control-plane rules
# Nodes talk to the API server on 443.
# Control plane reaches kubelet on 10250 and the ephemeral/NodePort range.
resource "aws_security_group_rule" "cluster_ingress_from_nodes_https" {
    type                     = "ingress"
    security_group_id        = aws_security_group.eks_cluster.id
    from_port                = 443
    to_port                  = 443
    protocol                 = "tcp"
    source_security_group_id = aws_security_group.eks_nodes.id
    description              = "Worker nodes to API server"
}

resource "aws_security_group_rule" "cluster_egress_to_nodes_kubelet" {
    type                     = "egress"
    security_group_id        = aws_security_group.eks_cluster.id
    from_port                = 10250
    to_port                  = 10250
    protocol                 = "tcp"
    source_security_group_id = aws_security_group.eks_nodes.id
    description              = "Control plane to kubelet"
}

resource "aws_security_group_rule" "cluster_egress_to_nodes_ephemeral" {
    type                     = "egress"
    security_group_id        = aws_security_group.eks_cluster.id
    from_port                = 1025
    to_port                  = 65535
    protocol                 = "tcp"
    source_security_group_id = aws_security_group.eks_nodes.id
    description              = "Control plane to node ephemeral/NodePort range"
}


# EKS worker node rules
# self = true allows pod-to-pod traffic across nodes (CNI, kube-proxy, DNS).
# Using source_security_group_id = aws_security_group.eks_nodes.id here would
# also work but self=true is the idiomatic form and avoids a quirky AWS
# provider self-dependency issue.
resource "aws_security_group_rule" "nodes_ingress_self_all" {
    type              = "ingress"
    security_group_id = aws_security_group.eks_nodes.id
    from_port         = 0
    to_port           = 0
    protocol          = "-1"
    self              = true
    description       = "Node-to-node all traffic (pod networking)"
}

resource "aws_security_group_rule" "nodes_ingress_from_cluster_kubelet" {
    type                     = "ingress"
    security_group_id        = aws_security_group.eks_nodes.id
    from_port                = 10250
    to_port                  = 10250
    protocol                 = "tcp"
    source_security_group_id = aws_security_group.eks_cluster.id
    description              = "Kubelet from control plane"
}

resource "aws_security_group_rule" "nodes_ingress_from_cluster_ephemeral" {
    type                     = "ingress"
    security_group_id        = aws_security_group.eks_nodes.id
    from_port                = 1025
    to_port                  = 65535
    protocol                 = "tcp"
    source_security_group_id = aws_security_group.eks_cluster.id
    description              = "Ephemeral/NodePort from control plane"
}

resource "aws_security_group_rule" "nodes_ingress_from_alb_nodeport" {
    type                     = "ingress"
    security_group_id        = aws_security_group.eks_nodes.id
    from_port                = var.nodeport_range_from
    to_port                  = var.nodeport_range_to
    protocol                 = "tcp"
    source_security_group_id = aws_security_group.alb.id
    description              = "Istio ingress gateway NodePort traffic from ALB"
}

# Nodes need broad egress to pull images, call AWS APIs, and reach DAG
# dependencies on the public internet (via NAT Gateway).
resource "aws_security_group_rule" "nodes_egress_all" {
    type              = "egress"
    security_group_id = aws_security_group.eks_nodes.id
    from_port         = 0
    to_port           = 0
    protocol          = "-1"
    cidr_blocks       = ["0.0.0.0/0"]
    description       = "All outbound"
}


# RDS rules
# Only the EKS nodes SG can reach Postgres. Any other resource in the VPC
# (even in the same subnet) is blocked. Default egress is left in place — RDS
# does not initiate outbound connections so it is effectively unused.
resource "aws_security_group_rule" "rds_ingress_from_nodes_postgres" {
    type                     = "ingress"
    security_group_id        = aws_security_group.rds.id
    from_port                = var.postgres_port
    to_port                  = var.postgres_port
    protocol                 = "tcp"
    source_security_group_id = aws_security_group.eks_nodes.id
    description              = "Postgres from EKS worker nodes"
}


# VPC endpoints rules
# Any resource inside the VPC CIDR can reach interface endpoints over HTTPS.
# Consumed by endpoints like com.amazonaws.us-east-1.ecr.dkr, .ecr.api, .sts,
# .secretsmanager, .logs — all needed by EKS and Airflow pods.
resource "aws_security_group_rule" "endpoints_ingress_https_vpc_cidr" {
    type              = "ingress"
    security_group_id = aws_security_group.vpc_endpoints.id
    from_port         = 443
    to_port           = 443
    protocol          = "tcp"
    cidr_blocks       = [var.vpc_cidr]
    description       = "HTTPS from within the VPC to interface endpoints"
}
