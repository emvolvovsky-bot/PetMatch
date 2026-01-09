/**
 * Express server for PetMatch API endpoints
 */

import express from 'express';
import cors from 'cors';
import { PetIngestionService } from './petIngestionService';
import { PetSyncService } from './petSyncService';

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Get NEWS_API_KEY from environment
const NEWS_API_KEY = process.env.NEWS_API_KEY;

// Lazy-load services only when needed (pet endpoints require PETFINDER_DISTRIBUTOR_API_KEY)
let ingestionService: PetIngestionService | null = null;
let syncService: PetSyncService | null = null;

function getIngestionService(): PetIngestionService {
  if (!ingestionService) {
    ingestionService = new PetIngestionService();
  }
  return ingestionService;
}

function getSyncService(): PetSyncService {
  if (!syncService) {
    syncService = new PetSyncService();
  }
  return syncService;
}

// NewsAPI response types
interface NewsAPIArticle {
  title: string | null;
  description: string | null;
  url: string | null;
  publishedAt: string | null;
  source?: {
    name?: string | null;
  } | null;
  urlToImage?: string | null;
}

interface NewsAPIResponse {
  status: string;
  articles?: NewsAPIArticle[];
}

app.get('/api/pet-news', async (req, res) => {
  try {
    if (!NEWS_API_KEY) {
      return res.json({ articles: [] });
    }

    let allArticles: any[] = [];

    // Pet-focused searches only - no general headlines
    const searchQueries = [
      encodeURIComponent(
        '(dog OR dogs OR cat OR cats OR pet OR pets OR puppy OR puppies OR kitten OR kittens) AND (adoption OR adopt OR shelter OR rescue OR fostering OR foster OR "animal rescue" OR "humane society")'
      ),
      encodeURIComponent(
        '(veterinary OR vet OR "pet health" OR "animal welfare" OR "service animal" OR "pet food" OR "pet care" OR "animal care")'
      ),
      encodeURIComponent(
        '("humane society" OR "animal shelter" OR "animal rescue" OR SPCA OR "Best Friends Animal Society" OR "pet adoption" OR "dog adoption" OR "cat adoption")'
      ),
      encodeURIComponent(
        '(puppy OR puppies OR kitten OR kittens OR "pet training" OR "dog training" OR "cat behavior" OR "pet behavior")'
      ),
      encodeURIComponent(
        '("pet food recall" OR "dog food" OR "cat food" OR "pet nutrition" OR "animal nutrition")'
      )
    ];

    // Fetch from all pet-specific queries
    for (const query of searchQueries) {
      try {
        const url = `https://newsapi.org/v2/everything?q=${query}&language=en&sortBy=publishedAt&pageSize=20&apiKey=${NEWS_API_KEY}`;
        const response = await fetch(url);
        const data = (await response.json()) as NewsAPIResponse;

        if (data.status === 'ok' && data.articles) {
          allArticles = allArticles.concat(data.articles);
        }
      } catch (err) {
        console.error('Error fetching pet news query:', err);
      }
    }

    // Strict filtering for pet relevance
    const requiredKeywords = [
      'dog', 'dogs', 'cat', 'cats', 'pet', 'pets', 'puppy', 'puppies', 'kitten', 'kittens',
      'animal', 'animals', 'canine', 'feline', 'adopt', 'adoption', 'shelter', 'rescue',
      'foster', 'fostering', 'veterinary', 'vet', 'spca', 'humane', 'animal welfare',
      'service animal', 'emotional support animal', 'pet health', 'animal health',
      'leash', 'microchip', 'microchipping', 'neuter', 'spay', 'spaying', 'neutering',
      'pet food', 'dog food', 'cat food', 'pet care', 'animal care', 'pet training',
      'dog training', 'cat behavior', 'pet behavior', 'kennel', 'animal shelter',
      'animal rescue', 'pet adoption', 'dog adoption', 'cat adoption'
    ];

    const excludeTerms = [
      'nfl', 'nba', 'mlb', 'soccer', 'football game', 'basketball game',
      'movie', 'tv show', 'celebrity', 'album', 'fashion week', 'science',
      'avalanche', 'earthquake', 'hurricane', 'tornado', 'weather', 'climate',
      'politics', 'election', 'president', 'congress', 'senate', 'stock market',
      'crypto', 'bitcoin', 'technology', 'iphone', 'android', 'gaming'
    ];

    const relevantArticles = allArticles
      .filter(article => {
        if (!article.title || !article.url || !article.publishedAt) return false;

        const titleLower = (article.title || '').toLowerCase();
        const descLower = (article.description || '').toLowerCase();
        const combined = `${titleLower} ${descLower}`;

        // Must have at least one pet-related keyword
        const hasPetKeyword = requiredKeywords.some(k => combined.includes(k));
        if (!hasPetKeyword) return false;

        // Must not contain excluded terms
        const isExcluded = excludeTerms.some(term => combined.includes(term));
        if (isExcluded) return false;

        // Additional check: title should strongly suggest pet content
        const titleHasPetKeyword = requiredKeywords.some(k => titleLower.includes(k));
        if (!titleHasPetKeyword) {
          // If title doesn't have pet keyword, description must be very clear
          const descHasStrongPetKeyword = ['dog', 'cat', 'pet', 'puppy', 'kitten', 'adoption', 'shelter', 'rescue', 'vet', 'veterinary'].some(k => descLower.includes(k));
          if (!descHasStrongPetKeyword) return false;
        }

        return true;
      })
      // Remove duplicates by URL
      .filter((article, index, self) =>
        index === self.findIndex(a => a.url === article.url)
      )
      // Sort by published date (newest first)
      .sort((a, b) => {
        const dateA = new Date(a.publishedAt || 0).getTime();
        const dateB = new Date(b.publishedAt || 0).getTime();
        return dateB - dateA;
      })
      // Limit to top 15 most relevant
      .slice(0, 15)
      // Normalize
      .map(article => ({
        title: article.title,
        description: article.description || '',
        url: article.url,
        publishedAt: article.publishedAt,
        source: article.source?.name || 'News',
        imageUrl: article.urlToImage || null
      }));

    return res.json({ articles: relevantArticles });
  } catch (error) {
    console.error('Error fetching pet news:', error);
    return res.json({ articles: [] });
  }
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

// Pet ingestion endpoint (can be triggered by cron jobs)
app.post('/api/pets/ingest', async (req, res) => {
  try {
    const result = await getIngestionService().ingestPets();
    res.json({
      success: true,
      ...result
    });
  } catch (error: any) {
    console.error('Error ingesting pets:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Pet sync endpoint (can be triggered by cron jobs)
app.post('/api/pets/sync', async (req, res) => {
  try {
    const result = await getSyncService().sync();
    res.json({
      success: result.success,
      petsSynced: result.petsSynced,
      cycleCompleted: result.cycleCompleted,
      error: result.error
    });
  } catch (error: any) {
    console.error('Error syncing pets:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Get ingestion progress
app.get('/api/pets/progress', async (req, res) => {
  try {
    const progress = await getIngestionService().getProgress();
    res.json(progress);
  } catch (error: any) {
    console.error('Error getting progress:', error);
    res.status(500).json({
      error: error.message
    });
  }
});

app.listen(PORT, () => {
  console.log(`PetMatch API server running on port ${PORT}`);
  console.log(`Pet news endpoint: http://localhost:${PORT}/api/pet-news`);
  console.log(`Pet ingestion endpoint: http://localhost:${PORT}/api/pets/ingest`);
});

export default app;

