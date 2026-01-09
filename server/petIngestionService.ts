/**
 * Pet Ingestion Service
 * 
 * Server component #1: Handles ingestion of pets from Petfinder-Database-Distributor
 * Tracks cycle progress and triggers next batch when cycle completes
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

export class PetIngestionService {
  private readonly client = getPetfinderDistributorClient();
  private readonly cycleTracker: CycleTracker;
  private readonly store: CycleProgressStore;

  constructor(store?: CycleProgressStore) {
    // Use provided store or default to in-memory (replace with DB in production)
    this.store = store || new InMemoryCycleProgressStore();
    this.cycleTracker = new CycleTracker(this.store);
  }

  /**
   * Ingest pets from the API and update cycle progress
   * Automatically triggers next batch when cycle completes
   */
  async ingestPets(): Promise<{
    ingested: number;
    cycleCompleted: boolean;
    progress: {
      dogsCount: number;
      catsCount: number;
      cycleComplete: boolean;
      currentCycle: number;
    };
  }> {
    try {
      // Fetch all pets from the API
      const pets = await this.client.getAllPets();
      
      // Process pets and check if cycle completed
      const cycleCompleted = await this.cycleTracker.processPets(pets);
      
      // If cycle completed, trigger next batch
      if (cycleCompleted) {
        console.log('Cycle completed! Triggering next batch...');
        await this.client.triggerNextBatch();
        await this.cycleTracker.startNextCycle();
      }
      
      const progress = await this.cycleTracker.getProgress();
      
      return {
        ingested: pets.length,
        cycleCompleted,
        progress,
      };
    } catch (error) {
      console.error('Error ingesting pets:', error);
      throw error;
    }
  }

  /**
   * Get current ingestion progress
   */
  async getProgress() {
    return this.cycleTracker.getProgress();
  }

  /**
   * Health check for the service
   */
  async healthCheck() {
    return this.client.healthCheck();
  }
}


