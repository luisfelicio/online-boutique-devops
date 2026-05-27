resource "helm_release" "online_boutique" {
  name       = "online-boutique"
  repository = null # Local chart
  chart      = "../helm-chart"
  namespace  = "default"

  depends_on = [aws_eks_node_group.general]

  timeout = 600
}
