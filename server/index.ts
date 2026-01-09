/**
 * Main entry point for PetMatch server
 * 
 * Provides CLI interface for running backups and managing services
 */

import { CSVBackupService } from './csvBackupService';
import { PetSyncService } from './petSyncService';
import { PetIngestionService } from './petIngestionService';
import { BackupScheduler } from './backupScheduler';

/**
 * Run CSV backup
 */
async function runBackup() {
  console.log('Starting CSV backup...');
  const backupService = new CSVBackupService();
  
  // Use streaming for memory efficiency
  const result = await backupService.backupCSVStream();
  
  if (result.success) {
    console.log(`✓ Backup completed successfully`);
    console.log(`  File: ${result.filePath}`);
    console.log(`  Size: ${(result.fileSize / 1024 / 1024).toFixed(2)} MB`);
    console.log(`  Time: ${result.timestamp.toISOString()}`);
    
    // Cleanup old backups (keep last 10)
    const deletedCount = await backupService.cleanupOldBackups(10);
    if (deletedCount > 0) {
      console.log(`  Cleaned up ${deletedCount} old backup(s)`);
    }
    
    // Show total backup size
    const totalSize = await backupService.getTotalBackupSize();
    console.log(`  Total backup size: ${(totalSize / 1024 / 1024).toFixed(2)} MB`);
  } else {
    console.error(`✗ Backup failed: ${result.error}`);
    process.exit(1);
  }
}

/**
 * List all backups
 */
async function listBackups() {
  const backupService = new CSVBackupService();
  const backups = await backupService.listBackups();
  
  if (backups.length === 0) {
    console.log('No backups found.');
    return;
  }
  
  console.log(`Found ${backups.length} backup(s):\n`);
  backups.forEach((backup, index) => {
    console.log(`${index + 1}. ${backup.filePath}`);
    console.log(`   Size: ${(backup.fileSize / 1024 / 1024).toFixed(2)} MB`);
    console.log(`   Date: ${backup.timestamp.toISOString()}\n`);
  });
}

/**
 * Run sync service
 */
async function runSync() {
  console.log('Starting pet sync...');
  const syncService = new PetSyncService();
  const result = await syncService.sync();
  
  if (result.success) {
    console.log(`✓ Sync completed successfully`);
    console.log(`  Pets synced: ${result.petsSynced}`);
    console.log(`  Cycle completed: ${result.cycleCompleted}`);
  } else {
    console.error(`✗ Sync failed: ${result.error}`);
  }
}

/**
 * Run ingestion service
 */
async function runIngestion() {
  console.log('Starting pet ingestion...');
  const ingestionService = new PetIngestionService();
  const result = await ingestionService.ingestPets();
  
  console.log(`✓ Ingestion completed`);
  console.log(`  Ingested: ${result.ingested} pets`);
  console.log(`  Cycle completed: ${result.cycleCompleted}`);
  console.log(`  Progress: ${result.progress.dogsCount} dogs, ${result.progress.catsCount} cats`);
}

/**
 * Run backup scheduler
 */
async function runScheduler() {
  const intervalHours = parseInt(process.argv[3] || '6', 10);
  const intervalMs = intervalHours * 60 * 60 * 1000;
  const keepBackups = parseInt(process.argv[4] || '10', 10);

  console.log(`Starting backup scheduler:`);
  console.log(`  Interval: ${intervalHours} hours`);
  console.log(`  Keep backups: ${keepBackups}`);
  console.log(`  Press Ctrl+C to stop\n`);

  const scheduler = new BackupScheduler({
    intervalMs,
    keepBackups,
    onBackupComplete: (result) => {
      console.log(`✓ Backup completed: ${result.filePath}`);
    },
    onBackupError: (error) => {
      console.error(`✗ Backup error: ${error.message}`);
    },
  });

  scheduler.start();

  // Handle graceful shutdown
  process.on('SIGINT', () => {
    console.log('\nStopping backup scheduler...');
    scheduler.stop();
    process.exit(0);
  });

  process.on('SIGTERM', () => {
    console.log('\nStopping backup scheduler...');
    scheduler.stop();
    process.exit(0);
  });

  // Keep process alive
  await new Promise(() => {});
}

/**
 * Main CLI handler
 */
async function main() {
  const command = process.argv[2] || 'backup';
  
  try {
    switch (command) {
      case 'backup':
        await runBackup();
        break;
      case 'list':
        await listBackups();
        break;
      case 'sync':
        await runSync();
        break;
      case 'ingest':
        await runIngestion();
        break;
      case 'scheduler':
        await runScheduler();
        break;
      default:
        console.log('Usage:');
        console.log('  npm run start backup              - Run CSV backup');
        console.log('  npm run start list                - List all backups');
        console.log('  npm run start sync                - Run pet sync');
        console.log('  npm run start ingest              - Run pet ingestion');
        console.log('  npm run start scheduler [hours]   - Run backup scheduler (default: 6 hours)');
        process.exit(1);
    }
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  main();
}

export { runBackup, listBackups, runSync, runIngestion };

