# PetMatch Deployment Checklist

## ✅ Pre-Deployment

- [x] Express server created with `/api/pet-news` endpoint
- [x] Pet ingestion endpoints added (`/api/pets/ingest`, `/api/pets/sync`)
- [x] Health check endpoint (`/health`)
- [x] Render configuration files created
- [x] iOS app configured with configurable API URL

## 🚀 Render Deployment Steps

### 1. Deploy Web Service (News API)

1. Go to [Render Dashboard](https://dashboard.render.com)
2. Click "New +" → "Web Service"
3. Connect GitHub repo: `emvolvovsky-bot/PetMatch`
4. Configure:
   - **Name**: `petmatch-api`
   - **Root Directory**: `server`
   - **Environment**: `Node`
   - **Build Command**: `npm install && npm run build`
   - **Start Command**: `npm start`
   - **Plan**: Free

5. Set Environment Variables:
   - `NEWS_API_KEY` = (your NewsAPI key)
   - `PORT` = `10000` (Render sets this automatically, but you can override)

6. Deploy!

### 2. Update iOS App

After deployment, update your iOS app to use the Render URL:

**Option A: Info.plist (Recommended)**
Add to `Info.plist`:
```xml
<key>PETMATCH_API_URL</key>
<string>https://petmatch-api.onrender.com</string>
```

**Option B: Xcode Scheme Environment**
- Product → Scheme → Edit Scheme…
- Run → Arguments → Environment Variables
- Add: `PETMATCH_API_URL` = `https://petmatch-api.onrender.com`

**Option C: Code**
Update default in `NewsService.swift`:
```swift
self.baseURL = "https://petmatch-api.onrender.com"
```

### 3. Set Up Pet Ingestion (Choose One)

#### Option A: Render Cron Job (Recommended)
1. Render Dashboard → "New +" → "Cron Job"
2. Configure:
   - **Name**: `petmatch-ingest`
   - **Command**: `curl -X POST https://petmatch-api.onrender.com/api/pets/ingest`
   - **Schedule**: `0 */6 * * *` (every 6 hours)
   - **Plan**: Free

#### Option B: External Cron Service
Use [cron-job.org](https://cron-job.org) or similar:
- **URL**: `https://petmatch-api.onrender.com/api/pets/ingest`
- **Method**: POST
- **Schedule**: Every 6 hours

#### Option C: Background Worker
1. Render Dashboard → "New +" → "Background Worker"
2. Configure:
   - **Name**: `petmatch-sync-worker`
   - **Root Directory**: `server`
   - **Build Command**: `npm install && npm run build`
   - **Start Command**: `npm run backup:scheduler`
   - **Plan**: Free

### 4. Test Deployment

```bash
# Health check
curl https://petmatch-api.onrender.com/health

# Pet news endpoint
curl https://petmatch-api.onrender.com/api/pet-news

# Pet ingestion (manual trigger)
curl -X POST https://petmatch-api.onrender.com/api/pets/ingest

# Pet sync (manual trigger)
curl -X POST https://petmatch-api.onrender.com/api/pets/sync

# Get progress
curl https://petmatch-api.onrender.com/api/pets/progress
```

## 📝 Notes

- **Free Tier Limitations**: 
  - Services sleep after 15 minutes of inactivity
  - First request after sleep takes 30-60 seconds (cold start)
  - Consider paid plan for always-on service

- **Environment Variables**: 
  - Set in Render dashboard (not `.env` file)
  - Mark sensitive values as "Secret"

- **Service URL**: 
  - Render assigns URL like `https://petmatch-api-xxxx.onrender.com`
  - Update iOS app with your actual URL

## 🔧 Troubleshooting

1. **Service won't start**: Check build logs in Render dashboard
2. **Empty news articles**: Verify `NEWS_API_KEY` is set correctly
3. **iOS app can't connect**: 
   - Check API URL in app matches Render URL
   - Verify CORS is enabled (already done in `app.ts`)
   - Check service is not sleeping (make health check request first)

## 🎯 Next Steps After Deployment

1. Test all endpoints from iOS app
2. Monitor logs in Render dashboard
3. Set up cron job for pet ingestion
4. Configure automatic deployments (Render auto-deploys on push to main)

