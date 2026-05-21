# backend/Dockerfile
FROM node:20-alpine AS base
WORKDIR /app
RUN apk add --no-cache dumb-init

FROM base AS deps
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

FROM base AS production
ENV NODE_ENV=production
COPY --from=deps /app/node_modules ./node_modules
COPY src ./src
COPY package.json ./
EXPOSE 8000
USER node
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "src/index.js"]

---
# ai_service/Dockerfile
FROM python:3.12-slim AS base
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends gcc && rm -rf /var/lib/apt/lists/*

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
EXPOSE 8005
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8005", "--workers", "2"]

---
# backend/package.json
{
  "name": "mantra-backend",
  "version": "1.0.0",
  "description": "Mantra Dating App Backend",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js",
    "test": "jest --forceExit --runInBand",
    "migrate": "node src/database/migrate.js",
    "migrate:test": "NODE_ENV=test node src/database/migrate.js",
    "lint": "eslint src/"
  },
  "dependencies": {
    "@fastify/cors": "^9.0.1",
    "@fastify/helmet": "^11.1.1",
    "@fastify/jwt": "^8.0.1",
    "@fastify/multipart": "^8.3.0",
    "@fastify/rate-limit": "^9.1.0",
    "bcryptjs": "^2.4.3",
    "fastify": "^4.28.1",
    "firebase-admin": "^12.2.0",
    "ioredis": "^5.3.2",
    "pg": "^8.12.0",
    "redis": "^4.6.15",
    "uuid": "^10.0.0",
    "razorpay": "^2.9.4",
    "aws-sdk": "^2.1691.0",
    "pino-pretty": "^11.2.1"
  },
  "devDependencies": {
    "@types/node": "^20.14.10",
    "eslint": "^9.7.0",
    "jest": "^29.7.0",
    "nodemon": "^3.1.4",
    "supertest": "^7.0.0"
  }
}

---
# ai_service/requirements.txt
fastapi==0.111.0
uvicorn[standard]==0.30.1
pydantic==2.7.4
httpx==0.27.0
redis[asyncio]==5.0.7
boto3==1.34.144
python-dotenv==1.0.1
openai==1.35.7
pytest==8.2.2
pytest-asyncio==0.23.7

---
# docker-compose.yml (local development)
version: '3.9'

services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: mantra_dev
      POSTGRES_USER: mantra
      POSTGRES_PASSWORD: devpassword
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./backend/database/schema.sql:/docker-entrypoint-initdb.d/schema.sql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U mantra"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    command: redis-server --maxmemory 256mb --maxmemory-policy allkeys-lru
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]

  backend:
    build: ./backend
    ports:
      - "8000:8000"
    environment:
      DATABASE_URL: postgresql://mantra:devpassword@postgres:5432/mantra_dev
      REDIS_URL: redis://redis:6379
      JWT_SECRET: local_dev_secret_min_32_chars_long_!!
      NODE_ENV: development
      PORT: 8000
      LOG_LEVEL: debug
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    volumes:
      - ./backend/src:/app/src
    command: npm run dev

  ai_service:
    build: ./ai_service
    ports:
      - "8005:8005"
    environment:
      REDIS_URL: redis://redis:6379
      OPENAI_API_KEY: ${OPENAI_API_KEY}
      ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY}
    depends_on:
      redis:
        condition: service_healthy

volumes:
  postgres_data:

---
# .env.example
# Copy to .env and fill in values

# Backend
DATABASE_URL=postgresql://mantra:password@localhost:5432/mantra
REDIS_URL=redis://localhost:6379
JWT_SECRET=your_jwt_secret_minimum_32_characters_long
PORT=8000
NODE_ENV=development
LOG_LEVEL=info
ALLOWED_ORIGINS=http://localhost:3000

# Firebase
FIREBASE_PROJECT_ID=your-firebase-project-id
FIREBASE_PRIVATE_KEY=your-firebase-private-key
FIREBASE_CLIENT_EMAIL=firebase-adminsdk@your-project.iam.gserviceaccount.com

# AI Service
OPENAI_API_KEY=sk-your-openai-key
ANTHROPIC_API_KEY=sk-ant-your-anthropic-key
AWS_ACCESS_KEY_ID=your-aws-access-key
AWS_SECRET_ACCESS_KEY=your-aws-secret-key
S3_BUCKET=mantra-media-prod
AWS_REGION=ap-south-1

# Razorpay
RAZORPAY_KEY_ID=rzp_live_your_key
RAZORPAY_KEY_SECRET=your_razorpay_secret
RAZORPAY_WEBHOOK_SECRET=your_webhook_secret

# SMS
MSG91_AUTH_KEY=your_msg91_key
MSG91_SENDER_ID=MANTRA

# Cloudflare R2 (media storage)
R2_ACCOUNT_ID=your_cloudflare_account_id
R2_ACCESS_KEY_ID=your_r2_access_key
R2_SECRET_ACCESS_KEY=your_r2_secret
R2_BUCKET_NAME=mantra-media
R2_PUBLIC_URL=https://media.mantraapp.in
