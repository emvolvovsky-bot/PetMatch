# Petfinder-Database-Distributor Server Components

This directory contains server-side components for interacting with the Petfinder-Database-Distributor API.

## ⚠️ Security Notice

**IMPORTANT**: All code in this directory must run server-side only. Never expose `PETFINDER_DISTRIBUTOR_API_KEY` in client bundles, browser code, or query strings.

## Setup

1. Set the environment variable:
   ```bash
   export PETFINDER_DISTRIBUTOR_API_KEY=3h4hdfbhdfesnfsd2439DSFNUIFGSDBJHF
   ```

2. Install dependencies (if using TypeScript):
   ```bash
   npm install --save-dev typescript @types/node
   ```

## Files

### `petfinderDistributorClient.ts`
Shared client for the Petfinder-Database-Distributor API:
- Base URL: `https://petfinder-database-distributor.onrender.com`
- Authentication via `X-API-Key` header
- Typed wrappers for all documented endpoints
- Singleton pattern for reuse across components

### `cycleTracker.ts`
Cycle tracking system:
- Tracks progress toward 10,000 dogs + 10,000 cats per cycle
- Abstract storage interface (implement with your database)
- In-memory store for development/testing

### Server Components

1. **`petIngestionService.ts`** - Ingests pets from the API and tracks cycle progress
2. **`petSyncService.ts`** - Periodically syncs pet data and monitors cycles
3. **`petBatchProcessor.ts`** - Processes pets in batches with cycle tracking
4. **`csvBackupService.ts`** - Downloads and saves CSV backups to disk
5. **`backupScheduler.ts`** - Periodically runs CSV backups automatically
6. **`index.ts`** - CLI entry point for running backups and services

## Usage Examples

### Pet Ingestion Service

```typescript
import { PetIngestionService } from './petIngestionService';

const service = new PetIngestionService();
const result = await service.ingestPets();

console.log(`Ingested ${result.ingested} pets`);
console.log(`Cycle completed: ${result.cycleCompleted}`);
console.log(`Progress: ${result.progress.dogsCount} dogs, ${result.progress.catsCount} cats`);
```

### Pet Sync Service

```typescript
import { PetSyncService } from './petSyncService';

const service = new PetSyncService();

// Single sync
const result = await service.sync();

// Periodic sync (every hour)
service.startPeriodicSync(3600000);
```

### Pet Batch Processor

```typescript
import { PetBatchProcessor } from './petBatchProcessor';

const processor = new PetBatchProcessor();

// Process from API
const result = await processor.processFromAPI('my-batch-1');

// Process in chunks
const results = await processor.processInChunks(1000);
```

## Cycle Management

The system tracks cycles where each cycle = 10,000 dogs + 10,000 cats:

1. As pets are ingested, counters increment
2. When both targets are reached, the cycle is marked complete
3. The next batch is automatically triggered
4. Cycle counters reset and a new cycle begins

## Database Integration

Replace `InMemoryCycleProgressStore` with a database-backed implementation:

```typescript
import { CycleProgressStore, CycleProgress } from './cycleTracker';

class DatabaseCycleProgressStore implements CycleProgressStore {
  async getProgress(): Promise<CycleProgress> {
    // Query your database
  }
  
  async incrementDogs(count: number): Promise<void> {
    // Update database
  }
  
  // ... implement other methods
}
```

## CSV Backup Service

The backup service downloads CSV files from the API and saves them to disk. This is essential when the scraper is offline or experiencing issues.

### Features

- **Memory-efficient streaming**: Uses streaming to avoid loading large CSV files into memory
- **Automatic cleanup**: Keeps only the N most recent backups
- **Timestamped files**: Each backup has a unique timestamp
- **Periodic scheduling**: Can run automatically at intervals

### Usage

#### Manual Backup

```bash
npm run backup
```

#### List Backups

```bash
npm run backup:list
```

#### Run Backup Scheduler

```bash
# Run scheduler with default 6-hour interval
npm run backup:scheduler

# Run scheduler with custom interval (e.g., 3 hours)
npm run build && node dist/index.js scheduler 3

# Run scheduler with custom interval and keep count
npm run build && node dist/index.js scheduler 6 20
```

#### Programmatic Usage

```typescript
import { CSVBackupService } from './csvBackupService';
import { BackupScheduler } from './backupScheduler';

// Single backup
const backupService = new CSVBackupService();
const result = await backupService.backupCSVStream();

// Periodic backups (every 6 hours, keep 10 backups)
const scheduler = new BackupScheduler({
  intervalMs: 6 * 60 * 60 * 1000,
  keepBackups: 10,
});

scheduler.start();
```

## Memory Leak Fixes

The following improvements have been made to prevent memory leaks:

1. **Streaming CSV Processing**: Added `processPetsInChunks()` method that streams CSV data instead of loading everything into memory
2. **Streaming Backups**: CSV backups use streaming to write directly to disk without loading entire file into memory
3. **Chunk Processing**: Services can process pets in configurable chunks to limit memory usage

### Using Streaming for Large Datasets

```typescript
import { PetBatchProcessor } from './petBatchProcessor';

const processor = new PetBatchProcessor();

// Process with streaming (memory efficient)
const results = await processor.processWithStreaming(1000);
```

## Environment Variables

- `PETFINDER_DISTRIBUTOR_API_KEY` (required) - API key for authentication

## Backup Directory

Backups are stored in the `./backups` directory by default. This directory is created automatically if it doesn't exist.

**Note**: Add `backups/` to your `.gitignore` file to avoid committing backup files to version control.


