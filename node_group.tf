//IAM role for EKS node group 

locals {
  suffix = var.public_worker ? "public" : "private"
}

resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "key" {
  key_name   = "k8s-cluster${var.cluster_name}"
  public_key = tls_private_key.this.public_key_openssh
}

# write key data to local
resource "local_file" "key" {
  filename = "./k8s-cluster-${var.cluster_name}.pem"
  content  = tls_private_key.this.private_key_pem

  provisioner "local-exec" {
    command = "chmod 400 ./k8s-cluster-${var.cluster_name}.pem"
  }

  depends_on = [
    tls_private_key.this,
  ]
}

resource "aws_iam_role" "eks_nodegroup_role" {
  name = "eks-nodegroup-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "eks-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodegroup_role.name
}

resource "aws_iam_role_policy_attachment" "eks-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodegroup_role.name
}

resource "aws_iam_role_policy_attachment" "eks-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodegroup_role.name
}


// AWS EKS node group - public
resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name

  node_group_name = "eks-nodes-${local.suffix}"
  node_role_arn   = aws_iam_role.eks_nodegroup_role.arn
  subnet_ids      = var.public_worker ? aws_subnet.publics[*].id : aws_subnet.privates[*].id
  
  ami_type = "AL2_x86_64"  
  capacity_type = "ON_DEMAND"
  disk_size = 20
  instance_types = ["t3.medium"]
  
  
  remote_access {
    ec2_ssh_key = aws_key_pair.key.key_name
    source_security_group_ids = [ aws_security_group.basic.id ]
  }

  scaling_config {
    desired_size = 1
    min_size     = 1    
    max_size     = 2
  }

  update_config {
    max_unavailable = 1    
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eks-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.eks-AmazonEC2ContainerRegistryReadOnly,
  ] 

  tags = {
    Name = "Node-Group${local.suffix}"
  }
}
