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

### Architecture

```
Internet
   │
   ▼
Internet Gateway
   │
┌──▼──────────────────────┐
│  Public Subnets (3 AZs) │  ← ALB, NAT Gateway
└──┬──────────────────────┘
   │ NAT
┌──▼──────────────────────┐
│  Private Subnets (3 AZs)│  ← EKS Nodes, RDS
└─────────────────────────┘
```





