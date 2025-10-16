# Django Application Deployment on AWS ECS

This project demonstrates how to deploy a **Django application** on **AWS ECS (Elastic Container Service)** using **Terraform** for infrastructure provisioning and **Docker** for containerization.

---

## Prerequisites

Before you begin, ensure you have the following installed and configured:

- AWS CLI configured with appropriate credentials
- Terraform (latest version)
- Docker
- Python 3.x
- Git

---

## 🏗️ Architecture Overview

This setup provisions the following AWS resources and components:

- **VPC (Virtual Private Cloud):**

  - Creates an isolated network environment with multiple Availability Zones for high availability.

- **Public and Private Subnets:**

  - Distributes resources across zones to balance security and performance.

- **Internet Gateway:**

  - Enables inbound and outbound internet access for resources in public subnets.

- **NAT Gateway:**

  - Allows private subnet instances to securely access the internet for updates or dependencies.

- **Route Tables:**

  - Configures routing for both public and private subnets.

- **Security Groups:**

  - Control inbound and outbound traffic for ALB, ECS, and EC2 instances.

- **IAM Roles and Instance Profiles:**

  - Provide fine-grained permissions for ECS tasks, EC2 instances, and ECR access.

- **ECR (Elastic Container Registry):**

  - Stores and manages Docker images for the Django application.

- **ECS Cluster (Elastic Container Service):**

  - Orchestrates Docker containers running on EC2 instances using the EC2 launch type.

- **EC2 Launch Template:**

  - Defines instance configuration including ECS agent setup via user data and IAM role attachment.

- **Auto Scaling Group (ASG):**

  - Dynamically scales EC2 instances based on load and service metrics.

- **Application Load Balancer (ALB):**

  - Routes external traffic to ECS containers and performs health checks.

- **ECS Task Definition and Service:**

  - Define and maintain running containers for the Django app, linked to the ALB target group.

- **CloudWatch Logs and Metrics:**

  - Collect logs and performance metrics for ECS services, EC2 instances, and the application.

- **Terraform Backend (local or remote):**
  - Manages infrastructure state and enables reproducible deployments.

---

## Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/KarthikEdhala/terraform-aws-ecs-cluster.git
cd terraform
```

Configure your AWS CLI if you haven't already:

```bash
aws configure
```

---

### 2. Create ECR Repository

- Navigate to **AWS Console → ECR** and create a new repository named `django-app`.
- Copy the repository URL (it will look like: `123456789.dkr.ecr.us-west-1.amazonaws.com/django-app`).

---

### 3. Configure Terraform Variables

- Open `variables.tf` and update the following:
  - Replace `docker_image_url_django` with your ECR repository URL.
  - Update IAM policy file paths in `iam.tf` and `variables.tf` if needed.

---

### 4. Build and Push Docker Image

First, authenticate Docker with your ECR repository:

```bash
aws ecr get-login-password --region us-west-1 | docker login --username AWS --password-stdin <YOUR_ECR_REPO_URL>
```

Navigate to the app directory and build the Docker image:

```bash
cd app/
docker build --platform=linux/amd64 -t <YOUR_ECR_REPO_URL>:latest .
```

Push the image to ECR:

```bash
docker push <YOUR_ECR_REPO_URL>:latest
```

---

### 5. Generate SSH Key Pair

Navigate to the Terraform directory and generate an SSH key pair for EC2 access:

```bash
cd ../terraform/
ssh-keygen -f california-region-key-pair
```

- Update the key file path in `variables.tf` to point to the generated key.

---

### 6. Deploy Infrastructure with Terraform

Initialize Terraform:

```bash
terraform init
```

Create an execution plan:

```bash
terraform plan -out terraform.out
```

Apply the configuration:

```bash
terraform apply "terraform.out"
```

> This will create all the necessary AWS resources, including ECS cluster, Auto Scaling Group, ALB, NAT Gateway, VPC, Route Tables, and CloudWatch. The process may take 5-10 minutes.

---

### 7. Deploy Application to ECS

Install required Python packages:

```bash
pip install boto3 click
```

Set your AWS credentials as environment variables:

```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-west-1"
```

Navigate to the `deploy` folder and run the deployment script:

```bash
cd deploy/
python3 update-ecs.py --cluster=production-cluster --service=production-service
```

---

### 8. Verify Deployment

**Check ECS Service:**

- Go to AWS Console → ECS → Clusters → `production-cluster`
- Verify that there are _0 pending tasks_ and all tasks are in _RUNNING_ state

**Check Logs:**

- Navigate to CloudWatch → Log Groups
- Check the application logs for any errors

**Check VPC & Networking:**

- Verify that all networking components (NAT Gateway, Route Tables, subnets) are properly configured

---

### 9. Access Your Application

- Go to EC2 → Load Balancers in the AWS Console.
- Copy the DNS name of your load balancer and access your application:

```
http://<LOAD_BALANCER_DNS>/ping/
```

You should see a successful response from your Django application.

---

## Cleanup

To avoid incurring charges, destroy all resources when you're done:

```bash
cd terraform/
terraform destroy
```

- Type `yes` when prompted to confirm the destruction of resources.

---

## Troubleshooting

### EC2 Instances Not Registering with ECS

- SSH into the instance and check `/var/log/user-data.log`
- Verify the ECS agent is running:  
  `sudo systemctl status ecs`
- Check Docker is running:  
  `sudo systemctl status docker`

### Application Not Accessible

- Verify security groups allow traffic on the required ports
- Check that the target group health checks are passing
- Review CloudWatch logs for application errors

### ECS Tasks Failing to Start

- Ensure the Docker image was successfully pushed to ECR
- Verify IAM roles have correct permissions
- Check task definition configuration

---

## Project Structure

```
.
├── app/                    # Django application code
├── terraform/              # Infrastructure as Code
│   ├── main.tf
│   ├── variables.tf
│   ├── iam.tf
│   └── ...
└── deploy/                 # Deployment scripts
    └── update-ecs.py
```

---

## Contributing

Feel free to open issues or submit pull requests for improvements.

---

## Support

For questions or issues, please open a GitHub issue.
