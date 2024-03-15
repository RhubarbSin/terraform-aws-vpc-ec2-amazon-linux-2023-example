data "aws_ec2_instance_types" "this" {
  count = var.instance_type == null ? 1 : 0

  filter {
    name   = "burstable-performance-supported"
    values = ["true"]
  }

  filter {
    name   = "current-generation"
    values = ["true"]
  }

  filter {
    name   = "memory-info.size-in-mib"
    values = ["512"]
  }

  filter {
    name   = "processor-info.supported-architecture"
    values = ["arm64"]
  }
}

data "aws_ec2_instance_type" "this" {
  instance_type = (
    var.instance_type == null ?
    data.aws_ec2_instance_types.this.0.instance_types.0 :
    var.instance_type
  )
}

data "aws_ssm_parameter" "this" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-${data.aws_ec2_instance_type.this.supported_architectures.0}"

  with_decryption = false
}

resource "random_pet" "this" {
  provisioner "local-exec" {
    when    = create
    command = "ssh-keygen -q -P '' -f ${path.module}/${self.id}"
  }

  provisioner "local-exec" {
    when       = destroy
    command    = "rm ${path.module}/${self.id} ${path.module}/${self.id}.pub"
    on_failure = continue
  }
}

resource "aws_key_pair" "this" {
  public_key = file("${random_pet.this.id}.pub")
  key_name   = random_pet.this.id
}

data "aws_iam_policy_document" "this" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  assume_role_policy = data.aws_iam_policy_document.this.json

  name = replace(var.name, " ", "-")
}

data "aws_iam_policy" "this" {
  for_each = toset(
    [
      "ReadOnlyAccess",
      "AmazonSSMManagedInstanceCore",
    ]
  )

  name = each.key
}

resource "aws_iam_role_policy_attachment" "this" {
  for_each = data.aws_iam_policy.this

  role       = aws_iam_role.this.name
  policy_arn = each.value.arn
}

resource "aws_iam_instance_profile" "this" {
  name = replace(var.name, " ", "-")
  role = aws_iam_role.this.name
}

locals {
  user_data = {
    runcmd : [
      "grubby --args selinux=0 --update-kernel ALL",
    ],
    power_state : {
      mode : "reboot",
      timeout : 0,
      condition : true,
    },
  }
}

data "cloudinit_config" "this" {
  gzip          = false
  base64_encode = false

  part {
    content = yamlencode(local.user_data)

    content_type = "text/cloud-config"
  }
}

data "aws_default_tags" "this" {}

resource "aws_instance" "this" {
  ami                         = data.aws_ssm_parameter.this.value
  iam_instance_profile        = aws_iam_role.this.name
  instance_type               = data.aws_ec2_instance_type.this.id
  key_name                    = aws_key_pair.this.key_name
  subnet_id                   = aws_subnet.this.id
  vpc_security_group_ids      = [aws_vpc.this.default_security_group_id]
  volume_tags                 = data.aws_default_tags.this.tags
  user_data                   = data.cloudinit_config.this.rendered
  user_data_replace_on_change = true

  root_block_device {
    encrypted = true
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

resource "aws_eip" "this" {
  domain = "vpc"

  depends_on = [aws_internet_gateway.this]
}

resource "aws_eip_association" "this" {
  instance_id   = aws_instance.this.id
  allocation_id = aws_eip.this.id
}
