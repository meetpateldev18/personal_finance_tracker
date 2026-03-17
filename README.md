# Personal Finance Tracker

A production-grade, mobile-first personal finance management system with real-time Slack notifications, AI-powered insights via Claude Sonnet, and microservices backend on AWS.

## Tech Stack

| Layer | Technology |
|-------|------------|
| Mobile | Flutter 3.x (Dart) |
| Backend | Spring Boot 3.x (Java 21) – Microservices |
| Database | PostgreSQL 15 (AWS RDS) |
| Cache | Redis 7 (AWS ElastiCache) |
| Storage | AWS S3 |
| Auth | JWT + AWS Cognito |
| Queue | AWS SQS |
| Notifications | Slack API |
| AI | Claude Sonnet (Anthropic) |
| CI/CD | GitHub Actions → AWS ECS Fargate |
| Containers | Docker + Docker Compose |

---

## Getting Started

### Prerequisites
- Docker Desktop installed and running
- Java 21 (for local backend dev without Docker)
- Flutter 3.x SDK
- AWS CLI configured
- Git

### 1. Clone the Repository
```bash
echo "# personal_finance_tracker" >> README.md
git init
git add README.md
git commit -m "first commit"
git branch -M main
git remote add origin https://github.com/meetpateldev18/personal_finance_tracker.git
git push -u origin main
```

### 2. Configure Environment Variables
Copy the example env file and fill in your secrets:
```bash
cp .env.example .env
```

Fill in the following in `.env`:
```
# Database
POSTGRES_USER=financeuser
POSTGRES_PASSWORD=yourpassword
POSTGRES_DB=financedb

# Redis
REDIS_PASSWORD=redispassword

# JWT
JWT_SECRET=your_256bit_secret_key_here
JWT_EXPIRY_MINUTES=60
JWT_REFRESH_EXPIRY_DAYS=30

# AWS
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_S3_BUCKET=finance-tracker-receipts
AWS_COGNITO_USER_POOL_ID=us-east-1_xxxxxxx
AWS_COGNITO_CLIENT_ID=xxxxxxxxxxxxxxxx
AWS_SQS_BUDGET_ALERT_QUEUE=https://sqs.us-east-1.amazonaws.com/...
AWS_SQS_NOTIFICATION_QUEUE=https://sqs.us-east-1.amazonaws.com/...

# Slack
SLACK_BOT_TOKEN=xoxb-your-slack-bot-token
SLACK_SIGNING_SECRET=your_slack_signing_secret
SLACK_APP_TOKEN=xapp-your-app-token

# Claude AI
ANTHROPIC_API_KEY=sk-ant-your-claude-api-key

# Service Ports
USER_SERVICE_PORT=8081
TRANSACTION_SERVICE_PORT=8082
BUDGET_SERVICE_PORT=8083
ANALYTICS_SERVICE_PORT=8084
NOTIFICATION_SERVICE_PORT=8085
AI_SERVICE_PORT=8086
```

### 3. Start All Services with Docker Compose
```bash
# Start infrastructure (DB, Redis) first
docker-compose up -d postgres redis

# Wait ~10 seconds for DB to be ready, then start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop everything
docker-compose down

# Stop and remove volumes (WARNING: deletes data)
docker-compose down -v
```

### 4. Run Database Migrations
```bash
# Apply the schema
docker exec -i finance_postgres psql -U financeuser -d financedb < database/schema.sql
```

### 5. Run Flutter App
```bash
cd mobile
flutter pub get
flutter run
```

---

## Microservices

| Service | Port | Responsibility |
|---------|------|----------------|
| user-service | 8081 | Auth, registration, profile |
| transaction-service | 8082 | Income/expense CRUD, receipts |
| budget-service | 8083 | Budget creation, threshold monitoring |
| analytics-service | 8084 | Spending patterns, reports |
| notification-service | 8085 | Slack alerts, push notifications |
| ai-service | 8086 | Claude Sonnet financial insights |

All services are exposed through **API Gateway** (Kong / AWS API Gateway) at `http://localhost:8080`.

---

## Slack Bot Setup

1. Go to https://api.slack.com/apps → Create New App
2. Add Bot Token Scopes: `chat:write`, `commands`, `users:read`
3. Add Slash Commands:
   - `/balance` → `https://your-domain/api/slack/commands/balance`
   - `/budget` → `https://your-domain/api/slack/commands/budget`
   - `/spending` → `https://your-domain/api/slack/commands/spending`
4. Install app to workspace and copy **Bot Token** → `SLACK_BOT_TOKEN`
5. Copy **Signing Secret** → `SLACK_SIGNING_SECRET`

---

## Project Structure

```
personal_finance_tracker/
├── .github/workflows/       # GitHub Actions CI/CD
├── backend/
│   ├── user-service/        # Spring Boot – Auth & Users
│   ├── transaction-service/ # Spring Boot – Transactions
│   ├── budget-service/      # Spring Boot – Budgets
│   ├── analytics-service/   # Spring Boot – Analytics
│   ├── notification-service/# Spring Boot – Slack & Notifications
│   └── ai-service/          # Spring Boot – Claude AI Insights
├── mobile/                  # Flutter App
├── database/
│   └── schema.sql           # PostgreSQL schema
├── infrastructure/
│   ├── aws/                 # AWS setup guides
│   └── terraform/           # Terraform IaC
├── docker-compose.yml
├── .env.example
└── README.md
```

---

## CI/CD Pipeline

Push to `main` triggers:
1. Unit tests on all services
2. Build Docker images
3. Push to AWS ECR
4. Deploy to AWS ECS Fargate
5. Smoke tests
6. Slack notification on deploy success/failure

See [.github/workflows/ci-cd.yml](.github/workflows/ci-cd.yml) for details.

---

## API Documentation

Once running, Swagger UI is available at:
- http://localhost:8081/swagger-ui.html (User Service)
- http://localhost:8082/swagger-ui.html (Transaction Service)
- http://localhost:8083/swagger-ui.html (Budget Service)
- http://localhost:8084/swagger-ui.html (Analytics Service)
- http://localhost:8085/swagger-ui.html (Notification Service)
- http://localhost:8086/swagger-ui.html (AI Service)
