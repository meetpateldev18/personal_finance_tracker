# Personal Finance Tracker

A production-grade, mobile-first personal finance management system with real-time Slack notifications, AI-powered insights via Claude Sonnet, and microservices backend on AWS.

---

## System Architecture

```
╔══════════════════════════════════════════════════════════════════════════════════╗
║                     PERSONAL FINANCE TRACKER — ARCHITECTURE                     ║
╚══════════════════════════════════════════════════════════════════════════════════╝

┌─────────────────────────────────────────────────────────────────────────────┐
│                            MOBILE CLIENT (Flutter)                           │
│   ┌─────────────┐  ┌──────────────┐  ┌────────────┐  ┌──────────────────┐  │
│   │  Auth/Login │  │  Dashboard   │  │Transactions│  │  AI Insights     │  │
│   │   Screen    │  │  Overview    │  │  + Receipt │  │  Screen          │  │
│   └──────┬──────┘  └──────┬───────┘  └─────┬──────┘  └────────┬─────────┘  │
│          └────────────────┴────────────────┴─────────────────┘              │
│                              Flutter HTTP Client (Dio)                       │
│                              JWT Token interceptor                           │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │ HTTPS
                                       ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                         AWS API GATEWAY (Single Entry Point)                  │
│                     Rate Limiting │ Request Routing │ CORS                   │
└───┬──────────┬──────────┬─────────┬─────────┬───────────────┬───────────────┘
    │          │          │         │         │               │
    ▼          ▼          ▼         ▼         ▼               ▼
┌────────┐ ┌────────┐ ┌───────┐ ┌────────┐ ┌──────────┐ ┌────────┐
│  USER  │ │ TRANS  │ │BUDGET │ │ANALYT- │ │NOTIFIC-  │ │   AI   │
│SERVICE │ │SERVICE │ │SERVICE│ │ICS SVC │ │ATION SVC │ │SERVICE │
│:8081   │ │:8082   │ │:8083  │ │:8084   │ │:8085     │ │:8086   │
│        │ │        │ │       │ │        │ │          │ │        │
│• Auth  │ │• CRUD  │ │• CRUD │ │• Stats │ │• Slack   │ │• Claude│
│• JWT   │ │• S3    │ │• Mon- │ │• Rpts  │ │• Push    │ │  API   │
│• Cogn- │ │  Upload│ │  itor │ │• Score │ │• Schedul-│ │• Insig-│
│  ito   │ │• Tags  │ │• SQS  │ │• Pred  │ │  ed Jobs │ │  hts   │
└───┬────┘ └───┬────┘ └──┬────┘ └───┬────┘ └────┬─────┘ └───┬────┘
    └──────────┴──────────┴──────────┴────────────┴───────────┘
                                    │
           ┌─────────────────────────────────────────────────┐
           │              SHARED INFRASTRUCTURE               │
           │                                                  │
           │  ┌──────────────────┐    ┌─────────────────────┐│
           │  │  AWS RDS         │    │  AWS ElastiCache     ││
           │  │  PostgreSQL 15   │    │  Redis 7             ││
           │  │                  │    │                      ││
           │  │  • users         │    │  • JWT blacklist     ││
           │  │  • transactions  │    │  • Session cache     ││
           │  │  • budgets       │    │  • Rate limiting     ││
           │  │  • analytics     │    │  • Fraud detection   ││
           │  │  • slack_config  │    │  • AI response cache ││
           │  └──────────────────┘    └─────────────────────┘│
           │                                                  │
           │  ┌──────────────────┐    ┌─────────────────────┐│
           │  │  AWS S3          │    │  AWS SQS             ││
           │  │                  │    │                      ││
           │  │  • receipts/     │    │  • budget-alerts     ││
           │  │  • profile-pics/ │    │  • notifications     ││
           │  │  • reports/      │    │  • weekly-reports    ││
           │  └──────────────────┘    └─────────────────────┘│
           └─────────────────────────────────────────────────┘
```

---

## Data Flow — How a Transaction Works End-to-End

```
  Flutter App
      │  POST /api/transactions (+ optional receipt image)
      ▼
  Transaction Service (:8082)
      │  1. Validate JWT token
      │  2. Run velocity/fraud check via Redis counter
      │  3. Save transaction to PostgreSQL
      │  4. Upload receipt to AWS S3 (if attached)
      │  5. Publish event → SQS: budget-alerts queue
      ▼
  Budget Service (:8083)  ← SQS consumer (polls every 10s)
      │  6. Look up active budgets for that category
      │  7. Increment spentAmount
      │  8. If usage ≥ alert threshold → publish → SQS: notifications queue
      ▼
  Notification Service (:8085)  ← SQS consumer (polls every 10s)
      │  9. Dispatch Slack DM:  "⚠️ 80% of Food & Dining budget used"
      │     or:                 "🚨 Food budget exceeded!"
      └── 10. Log notification to PostgreSQL
```

---

## Slack Integration Flow

```
  User types: /balance  (in Slack)
      │
      ▼
  Slack API  →  POST /api/v1/slack/commands
      │
  Notification Service (:8085)
      │  1. Verify HMAC-SHA256 signature (replay-attack safe, 5-min window)
      │  2. Parse slash command
      │  3. Fetch data from Analytics/Budget services
      │  4. Build Block Kit response with progress bars
      ▼
  Slack DM  ←  Rich formatted message returned instantly
```

Available slash commands:

| Command | Description |
|---------|-------------|
| `/balance` | Current month income vs expenses vs net balance |
| `/budget` | All budgets with usage bars and remaining amounts |
| `/spending` | Category breakdown of this month's expenses |

---

## AI Insights Flow

```
  Flutter App — AI Insights screen
      │  POST /api/v1/ai/spending-analysis
      ▼
  AI Service (:8086)
      │  1. Check Redis cache (60-min TTL per prompt hash)
      │  2. Cache miss → build context prompt with user's 30-day data
      │  3. Call Claude Sonnet API (claude-3-5-sonnet-20241022)
      │  4. Parse response → store in Redis cache
      ▼
  Flutter App  ←  Insight text rendered on screen
```

Available AI endpoints:

| Endpoint | Description |
|----------|-------------|
| `POST /ai/spending-analysis` | 30-day spending pattern analysis |
| `POST /ai/budget-recommendations` | 50/30/20 rule comparison & suggestions |
| `POST /ai/unusual-spending` | Flags categories >50% above average |
| `POST /ai/health-score` | Financial health score 0–100 with action items |
| `POST /ai/ask` | Free-form financial Q&A (not cached) |

---

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
git clone https://github.com/meetpateldev18/personal_finance_tracker.git
cd personal_finance_tracker
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

```
  git push origin main
      │
      ▼
  GitHub Actions
      │
      ├─ [Test]       Run unit tests for all 6 services in parallel
      │                (postgres + redis spun up as service containers)
      │
      ├─ [Build]      mvn package -DskipTests  →  docker build
      │                Push image to AWS ECR  (tag: short SHA)
      │
      ├─ [Deploy]     Update ECS task definition with new image
      │                Roll out to AWS ECS Fargate (one service at a time)
      │                Wait for service stability / auto-rollback on failure
      │
      ├─ [Smoke]      curl /actuator/health on all 6 services
      │                Retry 5× with 10s back-off
      │
      └─ [Notify]     Slack webhook  →  ✅ Success  or  ❌ Failure
```

See [.github/workflows/ci-cd.yml](.github/workflows/ci-cd.yml) for the full workflow definition.

---

## API Documentation

Once running, Swagger UI is available at:
- http://localhost:8081/swagger-ui.html (User Service)
- http://localhost:8082/swagger-ui.html (Transaction Service)
- http://localhost:8083/swagger-ui.html (Budget Service)
- http://localhost:8084/swagger-ui.html (Analytics Service)
- http://localhost:8085/swagger-ui.html (Notification Service)
- http://localhost:8086/swagger-ui.html (AI Service)
