# MANTRA — Complete Project Setup Guide

## Project Structure

```
mantra/
├── lib/                          # Flutter app
│   ├── main.dart
│   ├── firebase_options.dart
│   ├── app/
│   │   ├── app.dart
│   │   └── app_router.dart
│   ├── core/
│   │   ├── constants/api_constants.dart
│   │   ├── network/api_client.dart
│   │   ├── theme/
│   │   │   ├── app_theme.dart
│   │   │   ├── app_colors.dart
│   │   │   ├── app_text_styles.dart
│   │   │   └── app_spacing.dart
│   │   └── widgets/mantra_button.dart
│   └── features/
│       ├── auth/
│       ├── onboarding/
│       ├── home/
│       ├── matching/
│       ├── chat/
│       ├── community/
│       ├── safety/
│       └── premium/
├── backend/                      # Node.js API
│   ├── src/
│   │   ├── index.js
│   │   └── routes/
│   │       ├── auth.js
│   │       ├── match.js
│   │       └── safety.js
│   ├── database/
│   │   └── schema.sql
│   ├── Dockerfile
│   └── package.json
├── ai_service/                   # Python FastAPI
│   ├── main.py
│   └── requirements.txt
├── .github/workflows/
│   └── deploy.yml
└── docker-compose.yml
```

---

## STEP 1: Flutter Setup

### Prerequisites
```bash
flutter --version   # Must be 3.22+
dart --version      # Must be 3.3+
```

### 1. Get dependencies
```bash
cd mantra
flutter pub get
```

### 2. Setup Firebase
```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Login to Firebase
firebase login

# Configure (creates firebase_options.dart automatically)
flutterfire configure --project=your-firebase-project-id
```

### 3. Add fonts
Download and place in `assets/fonts/`:
- PlusJakartaSans-Regular.ttf
- PlusJakartaSans-Medium.ttf
- PlusJakartaSans-SemiBold.ttf
- PlusJakartaSans-Bold.ttf
- Lora-Regular.ttf
- Lora-SemiBold.ttf

Free download: https://fonts.google.com/specimen/Plus+Jakarta+Sans

### 4. Update API URL
```dart
// lib/core/constants/api_constants.dart
static const String baseUrl = 'https://api.mantraapp.in/api/v1';
// Change to your backend URL for local dev:
static const String baseUrl = 'http://10.0.2.2:8000/api/v1'; // Android emulator
```

### 5. Run on Android
```bash
flutter run -d android --release
```

### 6. Run on iOS
```bash
cd ios && pod install && cd ..
flutter run -d ios
```

---

## STEP 2: Backend Setup

### Prerequisites
- Node.js 20+
- PostgreSQL 16+
- Redis 7+

### 1. Install dependencies
```bash
cd backend
npm install
```

### 2. Setup environment
```bash
cp ../.env.example .env
# Fill in all values in .env
```

### 3. Setup database
```bash
# Create database
createdb mantra_dev

# Run schema
psql mantra_dev -f database/schema.sql
```

### 4. Run backend
```bash
npm run dev
# Server starts on http://localhost:8000
```

---

## STEP 3: AI Service Setup

### Prerequisites
- Python 3.12+

```bash
cd ai_service
pip install -r requirements.txt

# Set env vars
export OPENAI_API_KEY=sk-your-key
export ANTHROPIC_API_KEY=sk-ant-your-key
export REDIS_URL=redis://localhost:6379

# Run
uvicorn main:app --reload --port 8005
```

---

## STEP 4: Full Local with Docker

```bash
# From project root
cp .env.example .env
# Fill .env values

docker-compose up -d

# Backend: http://localhost:8000
# AI service: http://localhost:8005
# PostgreSQL: localhost:5432
# Redis: localhost:6379
```

---

## STEP 5: Firebase Configuration

### Required Firebase services:
1. **Authentication** → Enable Phone provider
2. **Firestore** → Create database (for chat MVP)
3. **Storage** → For voice notes
4. **Cloud Messaging** → For push notifications

### Firestore security rules:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /conversations/{convId} {
      allow read, write: if request.auth != null &&
        request.auth.uid in resource.data.participants;
    }
    match /messages/{msgId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null &&
        request.auth.uid == request.resource.data.sender_id;
      allow update, delete: if false;
    }
    match /typing/{convId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

---

## STEP 6: Android Signing

```bash
# Generate keystore (one time)
keytool -genkey -v -keystore android/app/mantra.keystore \
  -alias mantra -keyalg RSA -keysize 2048 -validity 10000

# android/key.properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=mantra
storeFile=mantra.keystore
```

### android/app/build.gradle — add signing config:
```groovy
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
        }
    }
}
```

---

## STEP 7: Build for Release

### Android APK
```bash
flutter build apk --release --split-per-abi
# Output: build/app/outputs/flutter-apk/
```

### Android App Bundle (Play Store)
```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### iOS (requires Mac + Xcode)
```bash
flutter build ipa --release
# Then distribute via Xcode or Transporter
```

---

## STEP 8: Deploy Backend to AWS

### ECS Deployment (production)
```bash
# Build and push image
docker build -t mantra-backend ./backend
docker tag mantra-backend:latest $ECR_URI/mantra-backend:latest
docker push $ECR_URI/mantra-backend:latest

# Update ECS service
aws ecs update-service \
  --cluster mantra-prod \
  --service mantra-backend \
  --force-new-deployment \
  --region ap-south-1
```

### Environment variables in ECS Task Definition:
```json
{
  "environment": [
    {"name": "NODE_ENV", "value": "production"},
    {"name": "PORT", "value": "8000"}
  ],
  "secrets": [
    {"name": "DATABASE_URL", "valueFrom": "arn:aws:secretsmanager:ap-south-1:..."},
    {"name": "JWT_SECRET", "valueFrom": "arn:aws:secretsmanager:ap-south-1:..."}
  ]
}
```

---

## STEP 9: App Store Submission

### Play Store
1. Build AAB: `flutter build appbundle --release`
2. Go to Play Console → Create app
3. App category: **Social**
4. Content rating: Complete questionnaire (dating app)
5. Upload AAB to Internal Testing first
6. Add Safety section: document age verification + moderation

### App Store
1. Build IPA via Xcode: `flutter build ipa`
2. Open Xcode → Archive → Distribute
3. Category: **Social Networking**
4. Age Rating: **17+**
5. Submit with review notes explaining:
   - Age verification system (Aadhaar)
   - Content moderation system
   - Safety features documentation

---

## Razorpay Integration

```dart
// Already integrated in premium_screen.dart
// Replace key in:
// lib/features/premium/presentation/screens/premium_screen.dart
// 'key': 'rzp_live_YOUR_KEY'

// Also add to AndroidManifest.xml (already included above)
```

---

## Environment Summary

| Service | Local | Production |
|---|---|---|
| Flutter app | localhost | Play Store / App Store |
| Backend API | localhost:8000 | AWS ECS ap-south-1 |
| AI Service | localhost:8005 | AWS ECS ap-south-1 |
| Database | localhost:5432 | AWS RDS PostgreSQL |
| Cache | localhost:6379 | AWS ElastiCache Redis |
| Media storage | - | Cloudflare R2 |
| Chat (MVP) | Firebase | Firebase → Custom WS |
| CDN | - | Cloudflare |

---

## Quick Start (5 minutes)

```bash
# 1. Clone / create project
mkdir mantra && cd mantra

# 2. Copy all Flutter files to lib/
# Copy backend files to backend/
# Copy ai_service files to ai_service/

# 3. Start infrastructure
docker-compose up -d postgres redis

# 4. Start backend
cd backend && npm install && npm run dev

# 5. Start AI service  
cd ../ai_service && pip install -r requirements.txt && uvicorn main:app --reload --port 8005

# 6. Run Flutter
cd .. && flutter pub get && flutter run
```

That's it. Mantra is running.
