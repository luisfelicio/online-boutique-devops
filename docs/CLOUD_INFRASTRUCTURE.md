# Cloud Infrastructure Documentation

## Overview
This project implements a cloud-native microservices architecture using the **Online Boutique** sample application. The infrastructure is fully provisioned on **Amazon Web Services (AWS)** using **Terraform** as the Infrastructure as Code (IaC) tool, enabling the provision of the entire environment (networking, computing, registry, and application helm release) with a single command (`terraform apply`).

---

## Architecture Components

### 1. Networking (VPC & Subnets)
- **VPC (Virtual Private Cloud):** A dedicated virtual network using the `10.0.0.0/16` CIDR block.
- **Subnets:** Distributed across two Availability Zones (`eu-central-1a` and `eu-central-1b`) for high availability:
  - **Public Subnets (`10.0.64.0/19`, `10.0.96.0/19`):** Hosting the Internet Gateway and NAT Gateway. Public Elastic Load Balancers (ELBs) are dynamically provisioned here.
  - **Private Subnets (`10.0.0.0/19`, `10.0.32.0/19`):** Hosting EKS worker nodes. Nodes do not receive public IP addresses, securing them from direct ingress.
- **Internet Gateway (IGW) & NAT Gateway:** The NAT Gateway is placed in a public subnet with an Elastic IP, enabling worker nodes in private subnets to pull public Docker images and fetch package updates without exposing them to incoming internet traffic.

### 2. Amazon EKS (Elastic Kubernetes Service)
- **Control Plane:** A managed Kubernetes cluster (`version 1.32`) with public API endpoint access enabled (fully authenticated and secured).
- **Access Configuration:** Configured in `API` mode using native Access Entries. We map:
  - `dev` IAM user to the EKS `AmazonEKSViewerPolicy` (read-only/viewer access).
  - `eks_admin` IAM role to the EKS `AmazonEKSClusterAdminPolicy` (full cluster administrator access).
  This eliminates the need for manual, error-prone `kube-system` `aws-auth` ConfigMap configurations or custom RBAC bindings.

### 3. Managed Node Groups
- **EC2 Instance Type:** `t3.medium` instances (2 vCPUs, 4 GiB Memory).
- **Capacity Sizing:** Configured with `desired_size = 2`, `min_size = 0`, and `max_size = 10` nodes.
- **Sizing Justification (Critical Design Choice):**
  - **Pod Count & IP Allocations:** The default AWS VPC CNI allocates IP addresses from the subnet directly to pods. On EKS, a `t3.small` instance only supports a maximum of 11 pods (including CNI, CoreDNS, and kube-proxy). Since Online Boutique deploys 11 microservices and a Redis database (12+ pods), a single `t3.small` node would immediately fail due to IP allocation exhaustion. A `t3.medium` supports up to 17 pods per node.
  - **Resource Demands:** The combined CPU/Memory requests of the microservices total ~1.7 vCPUs and ~1.8 GiB RAM. Running a single node (even `t3.medium`) leaves very little buffer for daemonsets and Kubernetes system pods. Spreading the workloads across `2 x t3.medium` instances provides 4 vCPUs, 8 GiB RAM, and a capacity of up to 34 pods. This ensures reliable scheduling, resource availability, and multi-zone fault tolerance.

### 4. Amazon ECR (Elastic Container Registry)
- A private container registry (`frontend`) is provisioned to host custom builds of the frontend application.
- Supports image scan on push to detect vulnerabilities before deployment.

### 5. Helm & Application Release
- Deployed directly inside Terraform via the `helm_release` provider.
- Utilizes local helm templates configured under `./helm-chart`.
- Deploys only after the EKS Node Group is active (`depends_on = [aws_eks_node_group.general]`).

---

## Design Justification

### Cloud Platform Choice: AWS
We selected **AWS** (deploying in the `eu-central-1` Frankfurt region) to demonstrate proficiency in multi-cloud engineering, exceeding the default course platform (Azure). This demonstrates understanding of AWS VPC topology, IAM policies, EKS access entry APIs, and ECR registries.

### Compute Choice: Managed Kubernetes (EKS)
Kubernetes is the industry standard for hosting microservices. Using a managed service like Amazon EKS offloads control-plane management (etcd database, API servers, and control plane patches) to AWS, while offering native integrations with IAM, VPC networking, auto-scaling, and rolling updates.

### Database Strategy: In-Cluster Redis Pod
- **Redis Cart Database:** The boutique's shopping cart microservice relies on a Redis key-value store.
- **Deployment Format:** Deployed in-cluster as a StatefulSet/Deployment via Helm.
- **Justification:** An in-cluster Redis pod offers sub-millisecond network latency for the cart service, keeps cloud operational costs low (no DBaaS instance overhead for training/demo environments), and enables self-contained backup/restore procedures using Kubernetes PV/PVC resources.
