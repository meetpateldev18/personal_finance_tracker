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
│                                      │                                       │
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
│• Cog-  │ │  Upload│ │  itor │ │• Score │ │• Schedul-│ │• Insig-│
│  nito  │ │• Tags  │ │• SQS  │ │• Pred  │ │  ed Jobs │ │  hts   │
└───┬────┘ └───┬────┘ └──┬────┘ └───┬────┘ └────┬─────┘ └───┬────┘
    │          │          │          │            │           │
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
           │  │  • slack_config  │    │  • Budget cache      ││
           │  └──────────────────┘    └─────────────────────┘│
           │                                                  │
           │  ┌──────────────────┐    ┌─────────────────────┐│
           │  │  AWS S3          │    │  AWS SQS             ││
           │  │                  │    │                      ││
           │  │  • receipts/     │    │  • budget-alerts     ││
           │  │  • profile-pics/ │    │  • notifications     ││
           │  │  • reports/      │    │  • weekly-reports    ││
           │  └──────────────────┘    └──────────┬──────────┘│
           └──────────────────────────────────────┼──────────┘
                                                  │
                                                  ▼
                                   ┌──────────────────────────┐
                                   │   NOTIFICATION SERVICE   │
                                   │                          │
                                   │  ┌────────────────────┐  │
                                   │  │   Slack API        │  │
                                   │  │                    │  │
                                   │  │ • Budget alerts    │  │
                                   │  │ • Daily summary    │  │
                                   │  │ • Weekly report    │  │
                                   │  │ • Large tx alert   │  │
                                   │  │ • /balance cmd     │  │
                                   │  │ • /budget cmd      │  │
                                   │  │ • /spending cmd    │  │
                                   │  └────────────────────┘  │
                                   └──────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                              EXTERNAL SERVICES                               │
│                                                                              │
│  ┌────────────────┐  ┌─────────────────┐  ┌──────────────────────────────┐ │
│  │  AWS Cognito   │  │  Anthropic       │  │  Slack API                   │ │
│  │  User Pools    │  │  Claude Sonnet   │  │  Workspace Integration       │ │
│  │  OAuth2/OIDC   │  │  claude-3-5-     │  │  Bot Token Auth              │ │
│  │  MFA Support   │  │  sonnet-20241022 │  │  Slash Commands              │ │
│  └────────────────┘  └─────────────────┘  └──────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                              CI/CD PIPELINE                                  │
│                                                                              │
│  Git Push → GitHub Actions                                                   │
│      │                                                                       │
│      ├── on push/PR → Run Unit Tests + Integration Tests                     │
│      │                                                                       │
│      └── on merge to main:                                                   │
│              │                                                               │
│              ├── Build Docker Images (per service)                           │
│              ├── Push to AWS ECR                                              │
│              ├── Deploy to AWS ECS Fargate                                   │
│              ├── Health Check / Smoke Tests                                  │
│              └── Slack notification (✅ Success / ❌ Failure)                │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                         DATA FLOW — TRANSACTION CREATED                      │
│                                                                              │
│  Flutter App                                                                 │
│      │  POST /api/transactions                                               │
│      ▼                                                                       │
│  Transaction Service                                                         │
│      │  1. Validate JWT                                                      │
│      │  2. Save to PostgreSQL                                                │
│      │  3. Upload receipt to S3 (if present)                                │
│      │  4. Publish event to SQS: budget-alerts queue                        │
│      ▼                                                                       │
│  Budget Service (SQS consumer)                                               │
│      │  5. Check if transaction exceeds budget threshold                    │
│      │  6. If threshold hit → publish to SQS: notifications queue           │
│      ▼                                                                       │
│  Notification Service (SQS consumer)                                         │
│      │  7. Send Slack DM: "⚠️ 80% of Food budget used"                     │
│      └── 8. Log notification to DB                                           │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```
