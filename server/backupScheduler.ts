/**
 * Backup Scheduler
 * 
 * Periodically runs CSV backups to ensure data is preserved
 * when the scraper is offline or experiencing issues.
 */

import { CSVBackupService, BackupResult } from './csvBackupService';

export interface SchedulerConfig {
  intervalMs: number;
  keepBackups: number;
  onBackupComplete?: (result: BackupResult) => void;
  onBackupError?: (error: Error) => void;
}

export class BackupScheduler {
  private readonly backupService: CSVBackupService;
  private readonly config: SchedulerConfig;
  private interval: NodeJS.Timeout | null = null;
  private isRunning: boolean = false;

  constructor(config: SchedulerConfig) {
    this.backupService = new CSVBackupService();
    this.config = config;
  }

  /**
   * Start periodic backups
   */
  start(): void {
    if (this.interval) {
      console.warn('Backup scheduler already running');
      return;
    }

    const intervalMinutes = this.config.intervalMs / 1000 / 60;
    console.log(`Starting backup scheduler (every ${intervalMinutes} minutes)`);

    // Run initial backup
    this.runBackup().catch(error => {
      console.error('Initial backup failed:', error);
      if (this.config.onBackupError) {
        this.config.onBackupError(error);
      }
    });

    // Schedule periodic backups
    this.interval = setInterval(() => {
      this.runBackup().catch(error => {
        console.error('Scheduled backup failed:', error);
        if (this.config.onBackupError) {
          this.config.onBackupError(error);
        }
      });
    }, this.config.intervalMs);
  }

  /**
   * Stop periodic backups
   */
  stop(): void {
    if (this.interval) {
      clearInterval(this.interval);
      this.interval = null;
      console.log('Backup scheduler stopped');
    }
  }

  /**
   * Run a single backup
   */
  private async runBackup(): Promise<BackupResult> {
    if (this.isRunning) {
      console.warn('Backup already in progress, skipping...');
      return {
        success: false,
        filePath: '',
        fileSize: 0,
        timestamp: new Date(),
        error: 'Backup already in progress',
      };
    }

    this.isRunning = true;
    const startTime = Date.now();

    try {
      console.log(`[${new Date().toISOString()}] Starting backup...`);
      
      // Use streaming for memory efficiency
      const result = await this.backupService.backupCSVStream();
      
      const duration = ((Date.now() - startTime) / 1000).toFixed(2);
      
      if (result.success) {
        console.log(
          `[${new Date().toISOString()}] Backup completed in ${duration}s - ` +
          `${(result.fileSize / 1024 / 1024).toFixed(2)} MB`
        );

        // Cleanup old backups
        const deletedCount = await this.backupService.cleanupOldBackups(
          this.config.keepBackups
        );
        
        if (deletedCount > 0) {
          console.log(`Cleaned up ${deletedCount} old backup(s)`);
        }

        if (this.config.onBackupComplete) {
          this.config.onBackupComplete(result);
        }
      } else {
        console.error(`Backup failed: ${result.error}`);
        if (this.config.onBackupError) {
          this.config.onBackupError(new Error(result.error || 'Unknown error'));
        }
      }

      return result;
    } finally {
      this.isRunning = false;
    }
  }

  /**
   * Check if scheduler is running
   */
  isActive(): boolean {
    return this.interval !== null;
  }

  /**
   * Get scheduler status
   */
  async getStatus() {
    const backups = await this.backupService.listBackups();
    const totalSize = await this.backupService.getTotalBackupSize();
    const latestBackup = await this.backupService.getLatestBackup();

    return {
      isActive: this.isActive(),
      isRunning: this.isRunning,
      intervalMs: this.config.intervalMs,
      keepBackups: this.config.keepBackups,
      totalBackups: backups.length,
      totalSizeMB: (totalSize / 1024 / 1024).toFixed(2),
      latestBackup: latestBackup
        ? {
            filePath: latestBackup.filePath,
            fileSizeMB: (latestBackup.fileSize / 1024 / 1024).toFixed(2),
            timestamp: latestBackup.timestamp,
          }
        : null,
    };
  }
}

