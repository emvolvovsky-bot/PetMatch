/**
 * Pet Sync Service
 * 
 * Server component #2: Periodically syncs pet data from Petfinder-Database-Distributor
 * Monitors cycle progress and handles batch transitions
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

export interface SyncResult {
  success: boolean;
  petsSynced: number;
  cycleCompleted: boolean;
  error?: string;
  timestamp: Date;
}

export class PetSyncService {
  private readonly client = getPetfinderDistributorClient();
  private readonly cycleTracker: CycleTracker;
  private readonly store: CycleProgressStore;
  private syncInterval: NodeJS.Timeout | null = null;

  constructor(store?: CycleProgressStore) {
    this.store = store || new InMemoryCycleProgressStore();
    this.cycleTracker = new CycleTracker(this.store);
  }

  /**
   * Perform a single sync operation
   */
  async sync(): Promise<SyncResult> {
    const timestamp = new Date();
    
    try {
      // Check if cycle is already complete
      const isComplete = await this.cycleTracker.isCycleComplete();
      
      if (isComplete) {
        // Cycle already complete, trigger next batch and reset
        console.log('Cycle already complete, starting next cycle...');
        await this.client.triggerNextBatch();
        await this.cycleTracker.startNextCycle();
      }

      // Fetch latest pets
      const pets = await this.client.getAllPets();
      
      // Process and track progress
      const cycleCompleted = await this.cycleTracker.processPets(pets);
      
      // If cycle just completed, trigger next batch
      if (cycleCompleted) {
        console.log('Cycle completed during sync! Triggering next batch...');
        await this.client.triggerNextBatch();
        await this.cycleTracker.startNextCycle();
      }

      return {
        success: true,
        petsSynced: pets.length,
        cycleCompleted,
        timestamp,
      };
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Unknown error';
      console.error('Sync error:', errorMessage);
      
      return {
        success: false,
        petsSynced: 0,
        cycleCompleted: false,
        error: errorMessage,
        timestamp,
      };
    }
  }

  /**
   * Start periodic syncing
   * @param intervalMs Interval between syncs in milliseconds
   */
  startPeriodicSync(intervalMs: number = 3600000): void {
    if (this.syncInterval) {
      console.warn('Periodic sync already running');
      return;
    }

    console.log(`Starting periodic sync every ${intervalMs / 1000}s`);
    
    // Perform initial sync
    this.sync().catch(console.error);
    
    // Schedule periodic syncs
    this.syncInterval = setInterval(() => {
      this.sync().catch(console.error);
    }, intervalMs);
  }

  /**
   * Stop periodic syncing
   */
  stopPeriodicSync(): void {
    if (this.syncInterval) {
      clearInterval(this.syncInterval);
      this.syncInterval = null;
      console.log('Periodic sync stopped');
    }
  }

  /**
   * Get current sync status and progress
   */
  async getStatus() {
    const progress = await this.cycleTracker.getProgress();
    const remaining = await this.cycleTracker.getRemainingCounts();
    
    return {
      isSyncing: this.syncInterval !== null,
      progress,
      remaining,
    };
  }
}


