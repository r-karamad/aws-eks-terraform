
// EKS IAM role
resource "aws_iam_role" "eks_master_role" {
  name 			= "eks-master-role"
 
  assume_role_policy 	= <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

// Associate IAM Policy to IAM Role
resource "aws_iam_role_policy_attachment" "eks-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_master_role.name
}

resource "aws_iam_role_policy_attachment" "eks-AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_master_role.name
}


resource "aws_eks_cluster" "this" {
  name     	= "${var.cluster_name}"
  role_arn 	= aws_iam_role.eks_master_role.arn 
  version 	= var.cluster_version 
 
  
  vpc_config {
    subnet_ids 	= var.public_worker ? aws_subnet.publics[*].id : aws_subnet.privates[*].id
 
    // by default private endpoint is disabled and public is enabled
 
    endpoint_private_access 	= "true"
    endpoint_public_access  	= "false"
 
   // which CIDR block will access to the kubernetes API server 
    public_access_cidrs 		= var.cluster_endpoint_public_access_cidrs   
  }
 
 
  kubernetes_network_config {
    service_ipv4_cidr 		= var.cluster_service_ipv4_cidr
  }
  
  // Enable EKS cluster control plane logging
  enabled_cluster_log_types 	= ["api", "audit", "authenticator", "controllerManager", "scheduler"]
 
  // Ensure that IAM Role permissions are created 
 
  depends_on = [
    aws_iam_role_policy_attachment.eks-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks-AmazonEKSVPCResourceController,
  ]
}



