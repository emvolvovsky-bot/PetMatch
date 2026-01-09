/**
 * Pet Batch Processor
 * 
 * Server component #3: Processes pets in batches with cycle tracking
 * Handles bulk operations and ensures cycle completion triggers next batch
 */

import { 
  getPetfinderDistributorClient, 
  PetRecord 
} from './petfinderDistributorClient';
import { 
  CycleTracker, 
  InMemoryCycleProgressStore,
  CycleProgressStore 
} from './cycleTracker';

export interface BatchProcessResult {
  batchId: string;
  processed: number;
  dogsProcessed: number;
  catsProcessed: number;
  cycleCompleted: boolean;
  progress: {
    dogsCount: number;
    catsCount: number;
    cycleComplete: boolean;
    currentCycle: number;
  };
  timestamp: Date;
}

export class PetBatchProcessor {
  private readonly client = getPetfinderDistributorClient();
  private readonly cycleTracker: CycleTracker;
  private readonly store: CycleProgressStore;

  constructor(store?: CycleProgressStore) {
    this.store = store || new InMemoryCycleProgressStore();
    this.cycleTracker = new CycleTracker(this.store);
  }

  /**
   * Process a batch of pets
   * @param pets Array of pet records to process
   * @param batchId Optional batch identifier
   */
  async processBatch(
    pets: PetRecord[], 
    batchId?: string
  ): Promise<BatchProcessResult> {
    const id = batchId || `batch-${Date.now()}`;
    const timestamp = new Date();

    try {
      // Count pets by type
      const dogs = pets.filter(p => p.pet_type === 'dog');
      const cats = pets.filter(p => p.pet_type === 'cat');

      // Process and track progress
      const cycleCompleted = await this.cycleTracker.processPets(pets);

      // If cycle completed, trigger next batch
      if (cycleCompleted) {
        console.log(`Cycle completed in batch ${id}! Triggering next batch...`);
        await this.client.triggerNextBatch();
        await this.cycleTracker.startNextCycle();
      }

      const progress = await this.cycleTracker.getProgress();

      return {
        batchId: id,
        processed: pets.length,
        dogsProcessed: dogs.length,
        catsProcessed: cats.length,
        cycleCompleted,
        progress,
        timestamp,
      };
    } catch (error) {
      console.error(`Error processing batch ${id}:`, error);
      throw error;
    }
  }

  /**
   * Process pets fetched from the API
   * Fetches all pets and processes them as a batch
   */
  async processFromAPI(batchId?: string): Promise<BatchProcessResult> {
    // Fetch all pets
    const pets = await this.client.getAllPets();
    
    // Process as batch
    return this.processBatch(pets, batchId);
  }

  /**
   * Process pets in chunks to avoid memory issues with large datasets
   * @param chunkSize Number of pets to process per chunk
   */
  async processInChunks(chunkSize: number = 1000): Promise<BatchProcessResult[]> {
    const pets = await this.client.getAllPets();
    const results: BatchProcessResult[] = [];
    
    for (let i = 0; i < pets.length; i += chunkSize) {
      const chunk = pets.slice(i, i + chunkSize);
      const batchId = `chunk-${Math.floor(i / chunkSize) + 1}`;
      const result = await this.processBatch(chunk, batchId);
      results.push(result);
      
      // If cycle completed in this chunk, we're done
      if (result.cycleCompleted) {
        break;
      }
    }
    
    return results;
  }

  /**
   * Process pets using streaming to avoid memory issues with very large datasets
   * This method processes pets as they're streamed from the API
   * @param chunkSize Number of pets to process per chunk
   */
  async processWithStreaming(chunkSize: number = 1000): Promise<BatchProcessResult[]> {
    const results: BatchProcessResult[] = [];
    let chunkNumber = 0;
    
    // Use streaming generator to process pets in chunks
    for await (const chunk of this.client.processPetsInChunks(chunkSize)) {
      chunkNumber++;
      const batchId = `stream-chunk-${chunkNumber}`;
      const result = await this.processBatch(chunk, batchId);
      results.push(result);
      
      // If cycle completed in this chunk, we're done
      if (result.cycleCompleted) {
        break;
      }
    }
    
    return results;
  }

  /**
   * Get current processing status
   */
  async getStatus() {
    const progress = await this.cycleTracker.getProgress();
    const remaining = await this.cycleTracker.getRemainingCounts();
    
    return {
      progress,
      remaining,
    };
  }
}


