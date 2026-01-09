# Petfinder-Database-Distributor Integration

This document explains how the Petfinder-Database-Distributor CSV API is integrated into the PetMatch app.

## Files Created

1. **`key.txt`** - Contains the API key for authentication
   - Location: Project root
   - **Note**: In production, this should be stored server-side only

2. **`PetMatch/Data/DistributorPetRepository.swift`** - Repository that fetches pets from the CSV API
   - Fetches CSV from `https://petfinder-database-distributor.onrender.com/pets.csv`
   - Parses CSV and converts to `Pet` models
   - Implements pagination with caching

## How It Works

1. **API Key Loading**: The repository tries to load the key from:
   - Bundle resource (if `key.txt` is added to Xcode project)
   - Project root directory
   - Documents directory

2. **Data Fetching**: 
   - Fetches all pets as CSV on first load
   - Caches the results for pagination
   - Uses `X-API-Key` header for authentication

3. **CSV Parsing**:
   - Handles quoted fields with commas
   - Parses combined breeds (e.g., "Labrador Retriever&American Staffordshire TerrierMix")
   - Normalizes age ranges (e.g., "(3-8 years)" → "adult")
   - Extracts city/state from location field

4. **Integration**: 
   - `DistributorPetRepository` is used as the primary data source
   - Falls back to `PetfinderPetRepository` if CSV fetch fails
   - Falls back to `SamplePetRepository` as final fallback

## Setup Instructions

### Option 1: Add key.txt to Xcode Bundle (Recommended for Development)

1. In Xcode, right-click on the project
2. Select "Add Files to PetMatch..."
3. Select `key.txt`
4. Make sure "Copy items if needed" is checked
5. Ensure the file is added to the target

### Option 2: Use Project Root (Current Setup)

The repository will automatically look for `key.txt` in the project root directory.

## Testing

The repository has been tested and successfully fetches pets from the API. The CSV contains:
- Pet links, names, locations
- Age, gender, size, breed information
- Images, descriptions, and compatibility flags

## Security Note

⚠️ **IMPORTANT**: The API key in `key.txt` should never be committed to version control or exposed in client bundles. For production:

1. Move the API key to server-side environment variables
2. Create a server-side API endpoint that proxies requests to the CSV API
3. Have the iOS app call your server endpoint instead

## Usage

The repository is automatically used when the app starts. No additional configuration is needed if `key.txt` is accessible.

Pets will appear as cards in the Discover view, and users can swipe through them just like with the other data sources.


