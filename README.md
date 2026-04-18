# Airflow-Infra
This repository shows how to setup Airflow in production in aws cloud

## Quick Start

```bash
cd airflow-infra
terraform init
terraform plan
terraform apply
```

## Infrastructure
### Phase 1: VPC Networking (Done)

| Resource | Details |
|----------|---------|
| VPC | `10.0.0.0/16` in `us-east-1` |
| Public Subnets (3) | `10.0.1.0/24`, `10.0.2.0/24`, `10.0.3.0/24` — hosts ALB, NAT Gateway |
| Private Subnets (3) | `10.0.10.0/24`, `10.0.20.0/24`, `10.0.30.0/24` — hosts EKS nodes, RDS |
| Internet Gateway | Public subnet internet access |
| NAT Gateway | Private subnet outbound internet via Elastic IP |
| Route Tables | Public → IGW, Private → NAT |

### Phase 2: Security Groups (Done)

Module: `modules/security-groups/`. ALB fronts the **Istio ingress gateway** running inside EKS (instance/NodePort target mode). All cross-SG references are declared as standalone `aws_security_group_rule` resources to avoid Terraform dependency cycles.

| Security Group | `Name` tag | Key Rules |
|----------------|-----------|-----------|
| ALB | `airflow-alb-sg` | Ingress 80/443 from internet; egress 30000-32767 → EKS nodes (Istio NodePort) |
| EKS Cluster | `eks-cluster-sg` | Ingress 443 from nodes; egress 10250 + 1025-65535 → nodes |
| EKS Nodes | `eks-nodes-sg` | Ingress self (all); 10250 + ephemeral from cluster; 30000-32767 from ALB (Istio NodePort); egress all |
| RDS Postgres | `airflow-rds-postgres-sg` | Ingress 5432 from EKS nodes only |
| VPC Endpoints | `vpc-endpoints-sg` | Ingress 443 from VPC CIDR |

### Architecture

```
Internet
   │
   ▼
Internet Gateway
   │
┌──▼──────────────────────────────────────────────┐
│  Public Subnets (3 AZs)                         │  ← ALB (airflow-alb-sg), NAT Gateway
└──┬──────────────────────────────────────────────┘
   │ NAT              │ NodePort (30000-32767)
   │                  ▼
┌──▼──────────────────────────────────────────────┐
│  Private Subnets (3 AZs)                        │
│    ┌─────────────────┐                          │
│    │ EKS Nodes       │                          │
│    │ (eks-nodes-sg)  │                          │
│    │  ┌────────────┐ │    ┌───────────┐         │
│    │  │ Istio IGW  │ │    │  RDS      │         │
│    │  │   pods     │ │───▶│ (rds-sg)  │         │
│    │  └─────┬──────┘ │5432└───────────┘         │
│    │        │        │                          │
│    │  ┌─────▼──────┐ │                          │
│    │  │ Airflow    │ │                          │
│    │  │ pods       │ │                          │
│    │  └────────────┘ │                          │
│    └────────┬────────┘                          │
│             │ 443                               │
│    ┌────────▼────────┐                          │
│    │ EKS Control     │                          │
│    │ (eks-cluster-sg)│                          │
│    └─────────────────┘                          │
└─────────────────────────────────────────────────┘
```





