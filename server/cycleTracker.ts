/**
 * Cycle tracking for Petfinder-Database-Distributor ingestion
 * 
 * Tracks progress toward completing a cycle (10,000 dogs + 10,000 cats)
 * and triggers the next batch when a cycle completes.
 */

import { PetRecord } from './petfinderDistributorClient';

export interface CycleProgress {
  dogsCount: number;
  catsCount: number;
  cycleComplete: boolean;
  currentCycle: number;
}

/**
 * Abstract interface for cycle progress storage
 * Implement this with your database or storage solution
 */
export interface CycleProgressStore {
  getProgress(): Promise<CycleProgress>;
  incrementDogs(count: number): Promise<void>;
  incrementCats(count: number): Promise<void>;
  resetCycle(): Promise<void>;
  incrementCycle(): Promise<void>;
}

/**
 * In-memory cycle progress store (for development/testing)
 * In production, replace with a database-backed implementation
 */
export class InMemoryCycleProgressStore implements CycleProgressStore {
  private progress: CycleProgress = {
    dogsCount: 0,
    catsCount: 0,
    cycleComplete: false,
    currentCycle: 1,
  };

  async getProgress(): Promise<CycleProgress> {
    return { ...this.progress };
  }

  async incrementDogs(count: number): Promise<void> {
    this.progress.dogsCount += count;
    this.checkCycleComplete();
  }

  async incrementCats(count: number): Promise<void> {
    this.progress.catsCount += count;
    this.checkCycleComplete();
  }

  async resetCycle(): Promise<void> {
    this.progress.dogsCount = 0;
    this.progress.catsCount = 0;
    this.progress.cycleComplete = false;
  }

  async incrementCycle(): Promise<void> {
    this.progress.currentCycle += 1;
  }

  private checkCycleComplete(): void {
    const DOGS_TARGET = 10000;
    const CATS_TARGET = 10000;
    
    this.progress.cycleComplete = 
      this.progress.dogsCount >= DOGS_TARGET && 
      this.progress.catsCount >= CATS_TARGET;
  }
}

/**
 * Cycle tracker that manages ingestion progress
 */
export class CycleTracker {
  private readonly store: CycleProgressStore;
  private readonly DOGS_TARGET = 10000;
  private readonly CATS_TARGET = 10000;

  constructor(store: CycleProgressStore) {
    this.store = store;
  }

  /**
   * Get current cycle progress
   */
  async getProgress(): Promise<CycleProgress> {
    return this.store.getProgress();
  }

  /**
   * Process ingested pets and update counters
   * Returns true if cycle was completed in this batch
   */
  async processPets(pets: PetRecord[]): Promise<boolean> {
    const dogs = pets.filter(p => p.pet_type === 'dog');
    const cats = pets.filter(p => p.pet_type === 'cat');

    const progressBefore = await this.store.getProgress();
    const wasCompleteBefore = progressBefore.cycleComplete;

    // Increment counters
    if (dogs.length > 0) {
      await this.store.incrementDogs(dogs.length);
    }
    if (cats.length > 0) {
      await this.store.incrementCats(cats.length);
    }

    // Check if cycle just completed
    const progressAfter = await this.store.getProgress();
    const cycleJustCompleted = !wasCompleteBefore && progressAfter.cycleComplete;

    return cycleJustCompleted;
  }

  /**
   * Check if current cycle is complete
   */
  async isCycleComplete(): Promise<boolean> {
    const progress = await this.store.getProgress();
    return progress.cycleComplete;
  }

  /**
   * Reset cycle and start next one
   */
  async startNextCycle(): Promise<void> {
    await this.store.resetCycle();
    await this.store.incrementCycle();
  }

  /**
   * Get remaining counts needed to complete cycle
   */
  async getRemainingCounts(): Promise<{ dogsRemaining: number; catsRemaining: number }> {
    const progress = await this.store.getProgress();
    return {
      dogsRemaining: Math.max(0, this.DOGS_TARGET - progress.dogsCount),
      catsRemaining: Math.max(0, this.CATS_TARGET - progress.catsCount),
    };
  }
}


