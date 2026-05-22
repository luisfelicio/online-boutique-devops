resource "helm_release" "online_boutique" {
  name       = "online-boutique"
  repository = null # Local chart
  chart      = "../helm-chart"
  namespace  = "default"

  # Ensure the application is only deployed after the worker nodes are ready
  depends_on = [aws_eks_node_group.general]

  timeout = 600 # 10 minutes to allow all pods to pull images and start
}
