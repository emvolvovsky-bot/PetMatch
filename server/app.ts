/**
 * Express server for PetMatch API endpoints
 */

import express from 'express';
import cors from 'cors';

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Get NEWS_API_KEY from environment
const NEWS_API_KEY = process.env.NEWS_API_KEY;

app.get('/api/pet-news', async (req, res) => {
  try {
    if (!NEWS_API_KEY) {
      return res.json({ articles: [] });
    }

    let allArticles: any[] = [];

    // 1) Try headlines first
    try {
      const headlinesUrl = `https://newsapi.org/v2/top-headlines?country=us&pageSize=20&apiKey=${NEWS_API_KEY}`;
      const headlinesResponse = await fetch(headlinesUrl);
      const headlinesData = await headlinesResponse.json();

      if (headlinesData.status === 'ok' && headlinesData.articles) {
        allArticles = allArticles.concat(headlinesData.articles);
      }
    } catch (err) {
      console.error('Error fetching headlines:', err);
    }

    // 2) Pet-focused searches (use first 2 to avoid rate limits)
    const searchQueries = [
      encodeURIComponent(
        '(dog OR dogs OR cat OR cats OR pet OR pets OR animal OR animals) AND (adoption OR adopt OR shelter OR rescue OR fostering OR foster)'
      ),
      encodeURIComponent(
        '(veterinary OR vet OR "pet health" OR "animal welfare" OR "service animal" OR "pet food" OR recall OR "animal control")'
      ),
      encodeURIComponent(
        '("humane society" OR "animal shelter" OR "animal rescue" OR SPCA OR "Best Friends Animal Society")'
      )
    ];

    for (const query of searchQueries.slice(0, 2)) {
      try {
        const url = `https://newsapi.org/v2/everything?q=${query}&language=en&sortBy=publishedAt&pageSize=15&apiKey=${NEWS_API_KEY}`;
        const response = await fetch(url);
        const data = await response.json();

        if (data.status === 'ok' && data.articles) {
          allArticles = allArticles.concat(data.articles);
        }
      } catch (err) {
        console.error('Error fetching pet news query:', err);
      }
    }

    // 3) Filter for pet relevance and remove junk
    const relevanceKeywords = [
      'dog', 'dogs', 'cat', 'cats', 'pet', 'pets', 'animal', 'animals',
      'adopt', 'adoption', 'shelter', 'rescue', 'foster', 'fostering',
      'veterinary', 'vet', 'spca', 'humane', 'animal welfare',
      'service animal', 'emotional support', 'pet health', 'rabies',
      'leash', 'microchip', 'microchipping', 'neuter', 'spay',
      'pet food', 'recall', 'kennel', 'puppy', 'kitten'
    ];

    const excludeTerms = [
      'nfl', 'nba', 'mlb', 'soccer', 'football game', 'basketball game',
      'movie', 'tv show', 'celebrity', 'album', 'fashion week'
    ];

    const relevantArticles = allArticles
      .filter(article => {
        if (!article.title || !article.url || !article.publishedAt) return false;

        const titleLower = (article.title || '').toLowerCase();
        const descLower = (article.description || '').toLowerCase();
        const combined = `${titleLower} ${descLower}`;

        const hasPetKeyword = relevanceKeywords.some(k => combined.includes(k));
        if (!hasPetKeyword) return false;

        const isExcluded = excludeTerms.some(term => titleLower.includes(term));
        return !isExcluded;
      })
      // Remove duplicates by URL
      .filter((article, index, self) =>
        index === self.findIndex(a => a.url === article.url)
      )
      // Limit
      .slice(0, 5)
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

app.listen(PORT, () => {
  console.log(`PetMatch API server running on port ${PORT}`);
  console.log(`Pet news endpoint: http://localhost:${PORT}/api/pet-news`);
});

export default app;

