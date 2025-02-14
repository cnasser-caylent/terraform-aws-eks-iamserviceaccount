data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
}

resource "aws_iam_policy" "policy_service_account" {
    count = length(var.policy_files)
    name = "${var.policy_name_prefix}-${count.index}"
    policy = file(var.policy_files[count.index])
}

resource "aws_iam_role" "role_service_account" {
    name = var.iam_role_name
    assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::${local.account_id}:oidc-provider/${var.oidc_provider}"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "${var.oidc_provider}:aud": "sts.amazonaws.com",
                    "${var.oidc_provider}:sub": "system:serviceaccount:${var.service_account_namespace}:${var.service_account_name}"
                }
            }
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "policy_attachment_service_account" {
    count = length(aws_iam_policy.policy_service_account)
    policy_arn = aws_iam_policy.policy_service_account[count.index].arn
    role = aws_iam_role.role_service_account.name
}

resource "aws_iam_openid_connect_provider" "this" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = var.cluster_thumprint_list
  url             = var.cluster_oidc_issuer
}

#resource "kubernetes_service_account" "service_account" {
#    metadata {
#        name = "${var.service_account_name}"
#        annotations = {
#            "eks.amazonaws.com/role-arn" = aws_iam_role.role_service_account.arn
#        }
#        namespace = var.service_account_namespace
#    }
#}
