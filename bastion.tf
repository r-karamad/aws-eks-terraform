data "aws_ami" "amzlinux2" {
  most_recent = true
  owners = [ "amazon" ]
  filter {
    name = "name"
    values = [ "amzn2-ami-hvm-*-gp2" ]
  }
  filter {
    name = "root-device-type"
    values = [ "ebs" ]
  }
  filter {
    name = "virtualization-type"
    values = [ "hvm" ]
  }
  filter {
    name = "architecture"
    values = [ "x86_64" ]
  }
}

resource "aws_instance" "bastion" {
  ami                 = data.aws_ami.amzlinux2.id
  instance_type       = var.instance_type
  availability_zone   = data.aws_availability_zones.azs.names[0]
  subnet_id           = aws_subnet.publics[0].id
  key_name            = aws_key_pair.key.id
  
  associate_public_ip_address = true
  vpc_security_group_ids      = [
    aws_security_group.basic.id, 
    aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  ]

  provisioner "file" {
    source      = "k8s-cluster-${var.cluster_name}.pem"
    destination = "/home/ec2-user/k8s-cluster-${var.cluster_name}.pem"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = "${file("k8s-cluster-${var.cluster_name}.pem")}"
      host        = "${self.public_ip}"
    }
  }

  tags = {
    Name = "bastion-host"
  }

  depends_on = [
    local_file.key
  ]
}

output "bastionPublicIP" {
  value = aws_instance.bastion.public_ip
}