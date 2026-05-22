resource "aws_iam_user" "dev" {
  name = "dev"
}

resource "aws_iam_policy" "dev_eks" {
  name = "AmazonEKSDeveloperPolicy"

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "eks:DescribeCluster",
                "eks:ListClusters"
            ],
            "Resource": "*"
        }
    ]
}
POLICY
}

resource "aws_iam_user_policy_attachment" "dev_eks" {
  user       = aws_iam_user.dev.name
  policy_arn = aws_iam_policy.dev_eks.arn
}

resource "aws_eks_access_entry" "developer" {
  cluster_name      = aws_eks_cluster.eks.name
  principal_arn     = aws_iam_user.dev.arn
  kubernetes_groups = ["my-viewer"]
}

resource "aws_eks_access_policy_association" "developer" {
  cluster_name  = aws_eks_cluster.eks.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
  principal_arn = aws_iam_user.dev.arn

  access_scope {
    type = "cluster"
  }
}