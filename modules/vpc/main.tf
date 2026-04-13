resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  enable_dns_hostnames = true #DNS hostnames assigns DNS names to the instances
  enable_dns_support = true # DNS support allows instances to resolve domain names

  tags = {
    Name = "aws-test-vpc"
  }
}

# Door to internet for vpc. Without this ,nothing in your VPC can talk to outside world.
#Allows communication between VPC and internet
resource "aws_internet_gateway" "main" {
    vpc_id = aws_vpc.main.id
}


resource "aws_subnet" "public" {
    count = length(var.public_subnet_cidrs)
    vpc_id = aws_vpc.main.id
    cidr_block = var.public_subnet_cidrs[count.index]
    availability_zone = var.availability_zones[count.index]
    map_public_ip_on_launch = true
    tags = {
      Name = "public-subnet-${count.index + 1}"
    }
}

resource "aws_subnet" "private" {
    count = length(var.private_subnet_cidrs)
    vpc_id = aws_vpc.main.id
    cidr_block = var.private_subnet_cidrs[count.index]
    availability_zone = var.availability_zones[count.index]
    tags = {
      Name = "private-subnet-${count.index + 1}"
    }
}

#Elastic IP + NAT Gateway

# Private subnets can't reach the internet directly
# NAT Gateway sits in public subnet and acts as a proxy for private subnets
# EKS nodes use this to pull Docker images, call AWS APIs
# depends_on — NAT needs the Internet Gateway to exist first

#  Why do we need it?

#   NAT Gateway needs a public IP to talk to the internet
#       ↓
#   But regular public IPs change if the resource restarts
#       ↓
#   Elastic IP = fixed IP that NEVER changes
#       ↓
#   Attach it to NAT Gateway → stable outbound internet for private subnets

resource "aws_eip" "nat" {
 domain = "vpc"
 tags = {
    Name = "eks-nat-eip"
 } 
}

# Allow private subnet servers to access the internet, but block internet from accessing them
# NAT Gateway must sit in a public subnet so it can access the internet (via Internet Gateway)
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id = aws_subnet.public[0].id

  depends_on = [ aws_internet_gateway.main ]
}


# 0.0.0.0/0 → Internet Gateway — all outbound traffic goes directly to internet
# Association links all 3 public subnets to this route table

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}


resource "aws_route_table_association" "public" {
    count          = length(var.public_subnet_cidrs)
    subnet_id      = aws_subnet.public[count.index].id
    route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
    vpc_id = aws_vpc.main.id

    route {
        cidr_block     = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.main.id
    }
}

resource "aws_route_table_association" "private" {
    count          = length(var.private_subnet_cidrs)
    subnet_id      = aws_subnet.private[count.index].id
    route_table_id = aws_route_table.private.id
}