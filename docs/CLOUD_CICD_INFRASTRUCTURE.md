# Cloud Infrastructure Documentation

## Project Overview

This project demonstrates the deployment of a cloud-native microservices application on **Amazon Web Services (AWS)** using modern **DevOps** and **Infrastructure as Code (IaC)** practices.

The application used is the **Online Boutique** sample application developed by Google, a distributed e-commerce platform composed of multiple independent microservices communicating through gRPC.

The primary objective of the project was not application development itself, but rather the automation, orchestration, deployment, and management of a production-like cloud infrastructure.

The infrastructure is fully provisioned using **Terraform**, while the application deployment is managed through **Helm**, **Kubernetes (EKS)**, and **GitHub Actions CI/CD pipelines**.

---

# Architecture Overview

The system is composed of the following major components:

- AWS VPC networking infrastructure
- Amazon EKS Kubernetes cluster
- Managed Node Groups
- Amazon ECR container registry
- Helm-based Kubernetes deployments
- GitHub Actions CI/CD workflows
- Redis in-cluster database

The architecture follows cloud-native design principles such as:

- Infrastructure as Code
- Immutable deployments
- Microservice isolation
- Automated deployments
- High availability
- Least-privilege security
- Declarative infrastructure

---

# Application Architecture

The deployed application is the Google Cloud **Online Boutique** microservices demo.

It consists of 11 independent microservices implemented in multiple programming languages:

| Service | Technology |
|---|---|
| frontend | Go |
| productcatalogservice | Go |
| checkoutservice | Go |
| shippingservice | Go |
| recommendationservice | Python |
| emailservice | Python |
| adservice | Java |
| currencyservice | Node.js |
| paymentservice | Node.js |
| cartservice | C# |
| loadgenerator | Python |

The services communicate internally using **gRPC**.

Redis is used as an in-memory database for the shopping cart service.

---

# Infrastructure Components

## 1. Virtual Private Cloud (VPC)

A dedicated AWS VPC is provisioned using the CIDR block:

```text
10.0.0.0/16
```

The VPC provides complete network isolation for the Kubernetes infrastructure.

### Availability Zones

To improve fault tolerance and availability, resources are distributed across two AWS Availability Zones:

- eu-central-1a
- eu-central-1b

---

## 2. Public and Private Subnets

The infrastructure uses both public and private subnets.

### Public Subnets

Public subnets host:

- Internet Gateway connectivity
- NAT Gateway
- Public Load Balancers created by Kubernetes

CIDR ranges:

```text
10.0.64.0/19
10.0.96.0/19
```

### Private Subnets

Private subnets host:

- EKS worker nodes
- Kubernetes workloads
- Application pods

CIDR ranges:

```text
10.0.0.0/19
10.0.32.0/19
```

Worker nodes do not receive public IP addresses, reducing the attack surface and improving security.

---

## 3. Internet Gateway and NAT Gateway

### Internet Gateway (IGW)

Provides public internet connectivity to resources located in public subnets.

### NAT Gateway

The NAT Gateway is deployed inside a public subnet with an Elastic IP address.

Its purpose is to allow worker nodes inside private subnets to:

- Pull Docker images
- Download updates
- Access external repositories

without exposing the nodes directly to inbound internet traffic.

This architecture follows AWS networking best practices.

---

# Amazon EKS (Elastic Kubernetes Service)

## Kubernetes Cluster

The application runs on a managed Kubernetes cluster provisioned through Amazon EKS.

### Cluster Configuration

| Configuration | Value |
|---|---|
| Kubernetes Version | 1.32 |
| Region | eu-central-1 |
| Endpoint Access | Public authenticated API |

Using EKS allows AWS to manage:

- Kubernetes control plane
- etcd database
- API server maintenance
- high availability of the control plane
- security patches and upgrades

while still giving full control over workloads and worker nodes.

---

# EKS Access Control

The cluster uses the modern **EKS Access Entry API** approach instead of the older `aws-auth` ConfigMap method.

This improves:

- maintainability
- security
- IAM integration
- scalability of access management

## IAM Access Mapping

### Developer User

The `dev` IAM user is mapped to:

```text
AmazonEKSViewerPolicy
```

This provides read-only access to cluster resources.

### Administrator Role

The `eks_admin` IAM role is mapped to:

```text
AmazonEKSClusterAdminPolicy
```

This role provides full cluster administrative access.

---

# Managed Node Groups

## EC2 Worker Nodes

The Kubernetes workloads run on managed EC2 node groups.

### Instance Type

```text
t3.small
```

### Scaling Configuration

| Setting | Value |
|---|---|
| desired_size | 3 |
| min_size | 0 |
| max_size | 10 |

---

# Amazon ECR (Elastic Container Registry)

An Amazon ECR repository is provisioned to host the custom frontend Docker image.

## Important Design Detail

Only the frontend image is built and managed within this project.

The remaining backend microservices use official pre-built container images provided by Google through the Google Artifact Registry.

This was an intentional design choice.

The project's objective was to focus on:

- cloud infrastructure
- Kubernetes orchestration
- CI/CD automation
- deployment workflows

rather than rebuilding all application services.

---

## Frontend Image Workflow

The CI/CD pipeline:

1. Builds the frontend Docker image
2. Tags the image using the Git commit SHA
3. Pushes the image to Amazon ECR
4. Updates the Helm release with the new image tag

Example deployment strategy:

```bash
--set frontend.image.repository=<ECR_URL>/frontend
--set frontend.image.tag=<git-sha>
```

This approach guarantees:

- immutable deployments
- traceability
- reproducibility
- easier rollback management

---

# Helm Deployment

The application is deployed using Helm.

Terraform integrates directly with Helm through the `helm_release` provider.

## Deployment Flow

Terraform provisions:

1. Networking
2. EKS cluster
3. Node groups
4. ECR
5. Helm release

The Helm deployment depends on worker node readiness:

```hcl
depends_on = [aws_eks_node_group.general]
```

This avoids race conditions where workloads could be scheduled before worker nodes are available.

---

# CI/CD Pipeline

GitHub Actions is used to automate the deployment pipeline.

---

## Main Deployment Workflow

Triggered on:

```text
Push to main branch
```

Pipeline steps:

1. Checkout repository
2. Configure AWS credentials
3. Update kubeconfig
4. Authenticate to ECR
5. Build frontend Docker image
6. Push image to ECR
7. Execute Helm upgrade

---

## Deployment Strategy

The deployment uses:

```bash
helm upgrade --install
```

This command is idempotent and supports both:

- initial deployments
- rolling updates

The workflow also uses:

```bash
--wait
```

which ensures the deployment only succeeds after Kubernetes confirms all pods are in the `Ready` state.

---

# Automated Testing

Separate GitHub Actions workflows are used for testing.

## Pull Request Validation

Executed automatically on PRs:

- Go unit tests
- C# unit tests
- smoke tests

This prevents untested code from reaching production deployments.

---

# Security Design

Security was considered throughout the infrastructure design.

## Security Measures Implemented

### Private Worker Nodes

EKS nodes are deployed inside private subnets.

### Least Privilege IAM

Different IAM roles and policies are used for:

- viewer access
- administrative access

### Container Image Scanning

Amazon ECR image scanning is enabled:

```text
scan_on_push = true
```

This allows vulnerability detection during image uploads.

### Network Isolation

Only required services are publicly exposed.

Application workloads remain isolated inside private networking.

---

# Database Strategy

## Redis Cart Database

Redis is deployed directly inside Kubernetes.

### Justification

Using an in-cluster Redis deployment:

- reduces operational cost
- simplifies the architecture
- keeps the environment self-contained
- provides low-latency communication

For this academic environment, Redis persistence guarantees were not critical because the shopping cart data is temporary.

---

# Design Decisions

## Why AWS?

AWS was selected because:

- EKS is a mature Kubernetes platform
- strong IAM integration
- native integration with ECR and VPC networking
- demonstrates multi-cloud capabilities beyond the default course platform

---

## Why Kubernetes?

The application contains multiple independent microservices.

Kubernetes provides:

- orchestration
- self-healing
- service discovery
- scaling
- workload isolation
- rolling deployments

Managing these services manually through virtual machines would significantly increase operational complexity.

---

## Why Terraform?

Terraform allows the infrastructure to be:

- declarative
- reproducible
- version-controlled
- automated

The entire environment can be recreated directly from the Git repository.

---

## Why GitHub Actions?

GitHub Actions integrates directly with the Git repository and enables:

- automated deployments
- CI/CD workflows
- secure secret management
- deployment reproducibility

---

# Challenges Faced

Several technical challenges were encountered during implementation.

## Kubernetes Networking

Understanding the interaction between:

- VPC networking
- private/public subnets
- NAT Gateways
- Kubernetes load balancers

was one of the most complex aspects of the project.

---

## IAM and Cluster Access

Configuring IAM permissions and EKS access entries correctly required careful coordination between AWS IAM policies and Kubernetes access control.

---

## Terraform Dependencies

Managing resource dependencies inside Terraform was essential to avoid provisioning race conditions.

---

## Helm and Infrastructure Integration

Integrating Helm deployments directly into Terraform required ensuring worker nodes were fully available before application deployment.

---

# Project Outcomes

The final system provides:

- fully automated infrastructure provisioning
- automated application deployment
- reproducible environments
- production-style Kubernetes orchestration
- secure AWS networking
- immutable deployment workflows
- Infrastructure as Code

The infrastructure can be recreated using a single Terraform command:

```bash
terraform apply
```

---

# Conclusion

This project demonstrates the deployment of a production-style cloud-native application using modern DevOps practices.

The implementation combines:

- Terraform
- Amazon EKS
- Helm
- GitHub Actions
- Docker
- AWS networking
- IAM security

into a fully automated deployment platform.

The primary focus of the work was the orchestration and automation of cloud infrastructure rather than application development itself, reflecting real-world DevOps and platform engineering practices.

