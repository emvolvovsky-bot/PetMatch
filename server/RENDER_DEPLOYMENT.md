# Render Deployment Guide for PetMatch Server

This guide explains how to deploy PetMatch server services to Render.

## Services Overview

1. **Web Service** - Express API server for `/api/pet-news` endpoint
2. **Cron Jobs** - Periodic pet ingestion/sync (optional, can use HTTP endpoints)

## Deployment Steps

### 1. Web Service Deployment

1. Go to [Render Dashboard](https://dashboard.render.com)
2. Click "New +" → "Web Service"
3. Connect your GitHub repository: `emvolvovsky-bot/PetMatch`
4. Configure:
   - **Name**: `petmatch-api`
   - **Root Directory**: `server`
   - **Environment**: `Node`
   - **Build Command**: `npm install && npm run build`
   - **Start Command**: `npm start` (or `node dist/app.js`)
   - **Plan**: Free

5. **Environment Variables**:
   - `PORT` = `10000` (Render sets this automatically)
   - `NEWS_API_KEY` = `your_newsapi_key_here` (Set as secret)

6. Deploy!

### 2. Environment Variables

Set these in the Render dashboard for the Web Service:

```
PORT=10000
NEWS_API_KEY=your_newsapi_key_here
```

### 3. Cron Jobs for Pet Ingestion/Sync

#### Option A: Use Render Cron Jobs

1. Go to Render Dashboard → "New +" → "Cron Job"
2. Configure:
   - **Name**: `petmatch-ingest`
   - **Command**: `curl -X POST https://your-api.onrender.com/api/pets/ingest`
   - **Schedule**: `0 */6 * * *` (every 6 hours)
   - **Plan**: Free

#### Option B: Use External Cron Service

Use a service like [cron-job.org](https://cron-job.org) to call your endpoints:

- **URL**: `https://your-api.onrender.com/api/pets/ingest`
- **Method**: POST
- **Schedule**: Every 6 hours

#### Option C: Background Worker (Continuous)

1. Go to Render Dashboard → "New +" → "Background Worker"
2. Configure:
   - **Name**: `petmatch-sync-worker`
   - **Root Directory**: `server`
   - **Build Command**: `npm install && npm run build`
   - **Start Command**: `npm run backup:scheduler`
   - **Plan**: Free

### 4. Update iOS App Base URL

After deployment, update `NewsService.swift` to use your Render URL:

```swift
init(baseURL: String = "https://your-api.onrender.com", session: URLSession = .shared) {
    self.baseURL = baseURL
    // ...
}
```

Replace `your-api.onrender.com` with your actual Render service URL.

### 5. Health Check

Your service should be accessible at:
- `https://your-api.onrender.com/health` - Health check
- `https://your-api.onrender.com/api/pet-news` - Pet news endpoint
- `https://your-api.onrender.com/api/pets/ingest` - Trigger pet ingestion (POST)
- `https://your-api.onrender.com/api/pets/sync` - Trigger pet sync (POST)
- `https://your-api.onrender.com/api/pets/progress` - Get ingestion progress

## Testing Locally Before Deployment

1. Set environment variables:
   ```bash
   export NEWS_API_KEY=your_key_here
   export PORT=3000
   ```

2. Build and run:
   ```bash
   cd server
   npm install
   npm run build
   npm start
   ```

3. Test endpoints:
   ```bash
   curl http://localhost:3000/health
   curl http://localhost:3000/api/pet-news
   curl -X POST http://localhost:3000/api/pets/ingest
   ```

## Notes

- Render free tier services sleep after 15 minutes of inactivity
- First request after sleep may take 30-60 seconds to wake up
- Consider upgrading to a paid plan for always-on service
- Cron jobs run independently and don't affect web service sleep

## Troubleshooting

1. **Service won't start**: Check build logs in Render dashboard
2. **Environment variables not working**: Ensure they're set in Render dashboard (not just `.env`)
3. **Endpoints return empty**: Check `NEWS_API_KEY` is set correctly
4. **Cron jobs not running**: Verify command syntax and schedule format

