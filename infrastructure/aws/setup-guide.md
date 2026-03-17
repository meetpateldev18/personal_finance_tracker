# AWS Infrastructure Setup Guide

## Prerequisites

- AWS CLI v2 configured: `aws configure`
- Terraform >= 1.7: `brew install terraform` or https://developer.hashicorp.com/terraform/install
- Docker installed locally
- A registered domain with a Route 53 hosted zone (or bring your ACM cert ARN)

---

## Step 1 — Bootstrap Terraform State Bucket

Run once before `terraform init`:

```bash
aws s3api create-bucket \
  --bucket finance-tracker-tf-state \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket finance-tracker-tf-state \
  --versioning-configuration Status=Enabled

aws dynamodb create-table \
  --table-name finance-tracker-tf-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

---

## Step 2 — Request an ACM TLS Certificate

Replace `yourdomain.com` with your actual domain:

```bash
aws acm request-certificate \
  --domain-name "api.yourdomain.com" \
  --validation-method DNS \
  --region us-east-1
```

Copy the Certificate ARN from the output and set it as `TF_VAR_acm_certificate_arn`.

---

## Step 3 — Set Terraform Variables

Create a `terraform.tfvars` file (never commit this):

```hcl
aws_region          = "us-east-1"
environment         = "prod"
db_password         = "YourStrongPassword!123"
acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/xxxxxxxx"
```

---

## Step 4 — Deploy Infrastructure

```bash
cd infrastructure/terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

Expected resources created: ~45 (VPC, subnets, RDS, ElastiCache, SQS × 6, S3, ECR × 6, ECS cluster + 6 services, ALB, Cognito)

---

## Step 5 — Apply Database Schema

Get the RDS endpoint:

```bash
terraform output rds_endpoint
```

Then run the schema:

```bash
psql -h <rds-endpoint> -U financeadmin -d finance_db -f database/schema.sql
```

---

## Step 6 — Configure GitHub Actions Secrets

Add these secrets to your GitHub repository (`Settings → Secrets → Actions`):

| Secret Name            | Value                               |
|------------------------|-------------------------------------|
| `AWS_ACCESS_KEY_ID`    | IAM user access key                 |
| `AWS_SECRET_ACCESS_KEY`| IAM user secret key                 |
| `AWS_ACCOUNT_ID`       | Your 12-digit AWS account ID        |
| `PROD_API_HOST`        | ALB DNS or your custom domain       |
| `SLACK_WEBHOOK_URL`    | Slack incoming webhook URL          |

Minimal IAM permissions for the CI/CD user:
- `ecr:GetAuthorizationToken`, `ecr:BatchGetImage`, `ecr:PutImage`
- `ecs:DescribeTaskDefinition`, `ecs:RegisterTaskDefinition`, `ecs:UpdateService`
- `ec2:DescribeSubnets` (for waiter)

---

## Step 7 — Set Up Slack Bot

1. Go to https://api.slack.com/apps → **Create New App** → From scratch
2. Name it **Finance Tracker Bot**, select your workspace
3. Under **OAuth & Permissions → Bot Token Scopes** add:
   - `chat:write`, `im:write`, `commands`, `users:read`
4. Under **Slash Commands** add:
   - `/balance` → `https://api.yourdomain.com/api/v1/slack/commands`
   - `/budget`  → same URL
   - `/spending` → same URL
5. Install the app to your workspace
6. Copy **Bot User OAuth Token** → set as `SLACK_BOT_TOKEN` env var in ECS task definition
7. Copy **Signing Secret** → set as `SLACK_SIGNING_SECRET`

---

## Step 8 — Configure Claude AI

1. Get API key from https://console.anthropic.com
2. Store in AWS Secrets Manager:

```bash
aws secretsmanager create-secret \
  --name finance-tracker/claude-api-key \
  --secret-string '{"CLAUDE_API_KEY":"sk-ant-xxxx"}'
```

3. Reference in ECS task definition environment variables (update `modules/ecs_service/main.tf`).

---

## Step 9 — Run First Deployment

```bash
git push origin main
```

GitHub Actions will:
1. Run tests for all 6 services in parallel
2. Build and push Docker images to ECR
3. Update ECS task definitions and deploy
4. Run smoke tests against health endpoints
5. Send Slack notification with deployment status

---

## Monitoring & Troubleshooting

### View ECS logs
```bash
aws logs tail /ecs/finance-tracker/user-service --follow
```

### Force new deployment
```bash
aws ecs update-service \
  --cluster finance-tracker-cluster \
  --service finance-tracker-user-service-service \
  --force-new-deployment
```

### Check service status
```bash
aws ecs describe-services \
  --cluster finance-tracker-cluster \
  --services finance-tracker-user-service-service \
  --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}'
```

### Destroy all infrastructure (caution!)
```bash
terraform destroy
```

---

## Cost Estimate (us-east-1, prod)

| Resource                     | Monthly ~cost |
|------------------------------|---------------|
| RDS db.t3.micro (Multi-AZ)   | ~$30          |
| ElastiCache cache.t3.micro   | ~$14          |
| ECS Fargate (6 × 256 CPU)    | ~$25          |
| ALB                          | ~$18          |
| S3 + SQS + Data Transfer     | ~$5           |
| **Total**                    | **~$92/mo**   |

Use `dev` environment (no Multi-AZ, 1 Fargate task each) for ~$45/mo.
