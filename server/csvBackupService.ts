/**
 * CSV Backup Service
 * 
 * Downloads CSV files from the Petfinder-Database-Distributor API
 * and saves them to disk for backup purposes.
 */

import * as fs from 'fs/promises';
import * as fsSync from 'fs';
import * as path from 'path';
import { 
  getPetfinderDistributorClient, 
  PetfinderDistributorClient 
} from './petfinderDistributorClient';

export interface BackupResult {
  success: boolean;
  filePath: string;
  fileSize: number;
  timestamp: Date;
  error?: string;
}

export interface BackupInfo {
  filePath: string;
  fileSize: number;
  timestamp: Date;
}

export class CSVBackupService {
  private readonly client: PetfinderDistributorClient;
  private readonly backupDir: string;

  constructor(backupDir: string = './backups') {
    this.client = getPetfinderDistributorClient();
    this.backupDir = backupDir;
  }

  /**
   * Ensure backup directory exists
   */
  private async ensureBackupDir(): Promise<void> {
    try {
      await fs.access(this.backupDir);
    } catch {
      await fs.mkdir(this.backupDir, { recursive: true });
    }
  }

  /**
   * Generate backup filename with timestamp
   */
  private generateBackupFilename(): string {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    return `pets-backup-${timestamp}.csv`;
  }

  /**
   * Download CSV and save to disk
   */
  async backupCSV(): Promise<BackupResult> {
    const timestamp = new Date();
    
    try {
      // Ensure backup directory exists
      await this.ensureBackupDir();

      // Generate filename
      const filename = this.generateBackupFilename();
      const filePath = path.join(this.backupDir, filename);

      // Fetch CSV content
      const csvContent = await this.client.getAllPetsCSV();

      // Write to disk
      await fs.writeFile(filePath, csvContent, 'utf-8');

      // Get file stats
      const stats = await fs.stat(filePath);

      return {
        success: true,
        filePath,
        fileSize: stats.size,
        timestamp,
      };
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Unknown error';
      console.error('CSV backup error:', errorMessage);
      
      return {
        success: false,
        filePath: '',
        fileSize: 0,
        timestamp,
        error: errorMessage,
      };
    }
  }

  /**
   * Stream CSV download to disk (memory efficient for large files)
   */
  async backupCSVStream(): Promise<BackupResult> {
    const timestamp = new Date();
    
    try {
      // Ensure backup directory exists
      await this.ensureBackupDir();

      // Generate filename
      const filename = this.generateBackupFilename();
      const filePath = path.join(this.backupDir, filename);

      // Get response stream
      const response = await (this.client as any).getCSVStream();
      
      if (!response.body) {
        throw new Error('Response body is not readable');
      }

      // Create write stream
      const writeStream = fsSync.createWriteStream(filePath, { encoding: 'utf-8' });
      
      // Stream data to file
      const reader = response.body.getReader();
      const decoder = new TextDecoder();

      try {
        while (true) {
          const { done, value } = await reader.read();
          
          if (done) {
            break;
          }

          const chunk = decoder.decode(value, { stream: true });
          writeStream.write(chunk);
        }
      } finally {
        reader.releaseLock();
        writeStream.end();
        
        // Wait for write stream to finish
        await new Promise<void>((resolve, reject) => {
          writeStream.on('finish', resolve);
          writeStream.on('error', reject);
        });
      }

      // Get file stats
      const stats = await fs.stat(filePath);

      return {
        success: true,
        filePath,
        fileSize: stats.size,
        timestamp,
      };
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Unknown error';
      console.error('CSV backup error:', errorMessage);
      
      return {
        success: false,
        filePath: '',
        fileSize: 0,
        timestamp,
        error: errorMessage,
      };
    }
  }

  /**
   * List all backup files
   */
  async listBackups(): Promise<BackupInfo[]> {
    try {
      await this.ensureBackupDir();
      
      const files = await fs.readdir(this.backupDir);
      const csvFiles = files.filter(f => f.endsWith('.csv'));
      
      const backups: BackupInfo[] = [];
      
      for (const file of csvFiles) {
        const filePath = path.join(this.backupDir, file);
        const stats = await fs.stat(filePath);
        
        backups.push({
          filePath,
          fileSize: stats.size,
          timestamp: stats.mtime,
        });
      }
      
      // Sort by timestamp (newest first)
      backups.sort((a, b) => b.timestamp.getTime() - a.timestamp.getTime());
      
      return backups;
    } catch (error) {
      console.error('Error listing backups:', error);
      return [];
    }
  }

  /**
   * Get the most recent backup
   */
  async getLatestBackup(): Promise<BackupInfo | null> {
    const backups = await this.listBackups();
    return backups.length > 0 ? backups[0] : null;
  }

  /**
   * Delete old backups, keeping only the N most recent
   */
  async cleanupOldBackups(keepCount: number = 10): Promise<number> {
    try {
      const backups = await this.listBackups();
      
      if (backups.length <= keepCount) {
        return 0;
      }
      
      const toDelete = backups.slice(keepCount);
      let deletedCount = 0;
      
      for (const backup of toDelete) {
        try {
          await fs.unlink(backup.filePath);
          deletedCount++;
        } catch (error) {
          console.error(`Error deleting backup ${backup.filePath}:`, error);
        }
      }
      
      return deletedCount;
    } catch (error) {
      console.error('Error cleaning up backups:', error);
      return 0;
    }
  }

  /**
   * Get total backup size
   */
  async getTotalBackupSize(): Promise<number> {
    try {
      const backups = await this.listBackups();
      return backups.reduce((total, backup) => total + backup.fileSize, 0);
    } catch (error) {
      console.error('Error calculating backup size:', error);
      return 0;
    }
  }
}

