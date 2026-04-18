variable "vpc_id" {
    description = "VPC ID in which the security groups are created"
    type        = string
}

variable "vpc_cidr" {
    description = "VPC CIDR block, used for VPC-endpoint ingress rules"
    type        = string
}

variable "postgres_port" {
    description = "Postgres port used by the Airflow metadata DB on RDS"
    type        = number
    default     = 5432
}

# ALB uses instance/NodePort targets. kube-proxy routes the NodePort to the
# istio-ingressgateway Service, which fronts Airflow via Istio VirtualService.
variable "nodeport_range_from" {
    description = "Start of the Kubernetes NodePort range (ALB -> nodes for Istio ingress gateway)"
    type        = number
    default     = 30000
}

variable "nodeport_range_to" {
    description = "End of the Kubernetes NodePort range (ALB -> nodes for Istio ingress gateway)"
    type        = number
    default     = 32767
}

variable "alb_ingress_cidrs" {
    description = "CIDRs allowed to reach the ALB on 80/443"
    type        = list(string)
    default     = ["0.0.0.0/0"]
}
