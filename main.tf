provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"
}

resource "aws_route53_record" "master" {
  zone_id = "${var.zone_id}"
  name    = "master.${var.domain_name}"
  type    = "A"
  ttl     = "300"
  records = ["${var.master_public_ip}"]
}

resource "aws_route53_record" "node1" {
  zone_id = "${var.zone_id}"
  name    = "node1.${var.domain_name}"
  type    = "A"
  ttl     = "300"
  records = ["${var.node1_public_ip}"]
}

resource "aws_route53_record" "node2" {
  zone_id = "${var.zone_id}"
  name    = "node2.${var.domain_name}"
  type    = "A"
  ttl     = "300"
  records = ["${var.node2_public_ip}"]
}

resource "aws_route53_record" "matchbox" {
  zone_id = "${var.zone_id}"
  name    = "matchbox.${var.domain_name}"
  type    = "A"
  ttl     = "300"
  records = ["${aws_instance.matchbox.public_ip}"]
}

resource "aws_route53_record" "controller" {
  zone_id = "${var.zone_id}"
  name    = "controller.${var.domain_name}"
  type    = "CNAME"
  ttl     = "5"
  records = ["${aws_route53_record.master.name}"]
}

resource "aws_route53_record" "apps" {
  zone_id = "${var.zone_id}"
  name    = "apps.${var.domain_name}"
  type    = "A"
  ttl     = "300"
  records = ["${var.node1_public_ip}", "${var.node2_public_ip}"]
}

//SECURITY GROUP for internet access to matchbox

resource "aws_security_group" "sgext" {

  name = "matchbox-sgext"
  vpc_id = "${var.vpc_to_deploy_to}"
  description = "Security group to allow matchbox to accept ssh and incoming IPXE requests"

  ingress {
    from_port = "0"
    to_port = "0"
    protocol = "-1"
    self = true
    cidr_blocks = ["${var.tectonic_baremetal_cidr}", "${var.tectonic_installer_ip}"]
  }

    egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    name = "matchbox-deployment"
  }
}

//SSH KEY to matchbox from your desktop
resource "aws_key_pair" "sharedsshkey" {
  key_name = "matchbox_test1"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC14AHMKm0Xk1S2cJO40sFm5Ghnr20BeZ8XMnodeyE42Pp8UaF6mJOEjaGmi3x+ohTBuzJwJnLC4uMRfPD9y5Q6qvoiWizh7lowGXjJlKOGd+mGx6bT+Gsccw6nxgYMD40Gv2CHVNiRivHkZLZhdmiqJDziBixD5ApFhxS07zvf8jVHXuLkZYQBCUIQLEqAyrqbFDoDXquBsLTbNvKqsaThGwyzoPh35Cu3XcH35YXjzh4E+rfmvwtUvhKfGPCfFQonB/jWQyPKvT1yTX0PZopjfkOYnQfMtCdGVyupmGyHoJJT15hqNA8/br0n4/AaPDQKFtxHQT/HKN9mG1gVR5H9 speterson@Scotts-iMac.local"
}

//Template file for matchbox userdata
data "template_file" "matchbox_userdata" {
    template = "${file("./user_data.tpl")}"
}

resource "aws_instance" "matchbox" {
  ami           = "${var.matchbox_ami_id}"
  instance_type = "t2.small"
  key_name = "matchbox_test1"
  security_groups = ["${aws_security_group.sgext.name}"]
  user_data = "${data.template_file.matchbox_userdata.rendered}"

  tags {
    Name = "matchbox-deployment"
  }
}