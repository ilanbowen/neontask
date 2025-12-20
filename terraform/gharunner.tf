resource "aws_iam_role" "gha_runner" {
  name = "${var.cluster_name}-gha-runner"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "gha_runner_ssm" {
  role       = aws_iam_role.gha_runner.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "gha_runner" {
  name = "${var.cluster_name}-gha-runner"
  role = aws_iam_role.gha_runner.name
}

# Discover a reasonable AMI
data "aws_ami" "ubuntu_jammy" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}


resource "aws_instance" "gha_runner" {
  ami = data.aws_ami.ubuntu_jammy.id
  instance_type          = "t3.small"
  subnet_id              = module.vpc.private_subnets[0]
  vpc_security_group_ids = [module.eks.node_security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.gha_runner.name

  associate_public_ip_address = false

  user_data = templatefile("${path.module}/runner_userdata.sh", {
    GITHUB_URL     = "https://github.com/${var.github_runner_token}/${var.github_repo}"
    RUNNER_TOKEN   = var.github_runner_token     # short-lived runner token
    RUNNER_LABEL   = "eks-runner"
    RUNNER_VERSION = "2.315.0"                   # or whichever version you want
  })

  tags = {
    Name = "${var.cluster_name}-gha-runner"
  }
}

