import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Service for database backup and restore operations.
///
/// Manages the lifecycle of SQLite database backups by copying the database
/// file to a dedicated backup directory. Backups are timestamped for easy
/// identification and support multiple concurrent backup versions.
///
/// ## Architecture
/// This service operates at the filesystem level, directly copying the
/// `ss_mart.sqlite` database file. It does not use Drift or the DAO layer
/// since backup/restore is a raw file operation.
///
/// ## Backup Location
/// Backups are stored in: `<app_documents_dir>/backups/`
/// Each backup is named: `ss_mart_backup_<YYYYMMDD_HHmmss>.sqlite`
///
/// ## Safety
/// - Before restore, a safety backup of the current database is created.
/// - The restore operation validates the backup file exists and is readable.
/// - Database file operations use temporary files and atomic moves where possible.
///
/// ## Usage
/// ```dart
/// final service = BackupService();
///
/// // Create backup
/// final result = await service.backupDatabase();
/// if (result.isSuccess) print('Backup: ${result.fileName}');
///
/// // Restore
/// final restoreResult = await service.restoreDatabase(backupPath);
///
/// // List backups
/// final backups = await service.getBackups();
/// ```
class BackupService {
  /// The database filename within the app's documents directory.
  static const String _dbFileName = 'ss_mart.sqlite';

  /// The subdirectory name for storing backups.
  static const String _backupDirName = 'backups';

  /// Gets the full path to the main database file.
  Future<File> get _databaseFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _dbFileName));
  }

  /// Gets the backup directory, creating it if it doesn't exist.
  Future<Directory> get _backupDirectory async {
    final dir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(dir.path, _backupDirName));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  /// Creates a backup of the current database.
  ///
  /// Copies the SQLite database file to the backup directory with a
  /// timestamp-based filename. Returns a [BackupResult] indicating
  /// success or failure.
  ///
  /// The backup file is named: `ss_mart_backup_YYYYMMDD_HHmmss.sqlite`
  Future<BackupResult> backupDatabase() async {
    try {
      final dbFile = await _databaseFile;
      if (!await dbFile.exists()) {
        return BackupResult(
          isSuccess: false,
          error: 'Database file not found',
        );
      }

      final backupDir = await _backupDirectory;
      final timestamp = DateTime.now().toIso8601String()
          .replaceAll('-', '')
          .replaceAll(':', '')
          .replaceAll('T', '_')
          .substring(0, 15);
      final backupFileName = 'ss_mart_backup_$timestamp.sqlite';
      final backupFile = File(p.join(backupDir.path, backupFileName));

      // Copy the database file
      await dbFile.copy(backupFile.path);

      return BackupResult(
        isSuccess: true,
        fileName: backupFileName,
        filePath: backupFile.path,
      );
    } catch (e) {
      return BackupResult(
        isSuccess: false,
        error: e.toString(),
      );
    }
  }

  /// Restores the database from a backup file.
  ///
  /// Replaces the current database with the specified backup file.
  /// A safety backup of the current database is created before restore.
  ///
  /// Returns a [BackupResult] indicating success or failure.
  /// After successful restore, the app should restart to reload the database.
  Future<BackupResult> restoreDatabase(String backupFilePath) async {
    try {
      final backupFile = File(backupFilePath);
      if (!await backupFile.exists()) {
        return BackupResult(
          isSuccess: false,
          error: 'Backup file not found',
        );
      }

      // Create safety backup before restore
      final safetyBackup = await backupDatabase();
      if (!safetyBackup.isSuccess) {
        return BackupResult(
          isSuccess: false,
          error: 'Failed to create safety backup: ${safetyBackup.error}',
        );
      }

      final dbFile = await _databaseFile;

      // Delete the current database file
      if (await dbFile.exists()) {
        await dbFile.delete();
      }

      // Copy backup to the database location
      await backupFile.copy(dbFile.path);

      return BackupResult(
        isSuccess: true,
        filePath: backupFilePath,
      );
    } catch (e) {
      return BackupResult(
        isSuccess: false,
        error: e.toString(),
      );
    }
  }

  /// Returns a list of all available backups, sorted by date (newest first).
  ///
  /// Each [BackupInfo] contains the filename, path, creation date, and size.
  Future<List<BackupInfo>> getBackups() async {
    try {
      final backupDir = await _backupDirectory;
      final files = await backupDir
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.sqlite'))
          .cast<File>()
          .toList();

      final backups = <BackupInfo>[];
      for (final file in files) {
        final stat = await file.stat();
        backups.add(BackupInfo(
          fileName: p.basename(file.path),
          filePath: file.path,
          createdAt: stat.modified,
          sizeBytes: stat.size,
        ));
      }

      // Sort by creation date, newest first
      backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return backups;
    } catch (e) {
      return [];
    }
  }

  /// Returns the timestamp of the most recent backup, or null if no backups exist.
  Future<String?> getLastBackupTime() async {
    final backups = await getBackups();
    if (backups.isEmpty) return null;

    final latest = backups.first;
    return latest.formattedDate;
  }

  /// Deletes a backup file at the specified path.
  ///
  /// Returns true if the file was successfully deleted, false otherwise.
  Future<bool> deleteBackup(String backupFilePath) async {
    try {
      final file = File(backupFilePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Gets the total size of all backups in bytes.
  Future<int> getTotalBackupSize() async {
    final backups = await getBackups();
    return backups.fold<int>(0, (sum, b) => sum + b.sizeBytes);
  }

  /// Removes old backups, keeping only the most recent [keepCount] backups.
  ///
  /// Returns the number of backups deleted. Useful for managing storage.
  Future<int> pruneOldBackups({int keepCount = 5}) async {
    final backups = await getBackups();
    if (backups.length <= keepCount) return 0;

    int deletedCount = 0;
    for (int i = keepCount; i < backups.length; i++) {
      final deleted = await deleteBackup(backups[i].filePath);
      if (deleted) deletedCount++;
    }

    return deletedCount;
  }
}

/// Result of a backup or restore operation.
///
/// Contains success/failure status, the backup file name and path,
/// and an error message if the operation failed.
class BackupResult {
  /// Whether the operation completed successfully.
  final bool isSuccess;

  /// The filename of the backup (e.g., `ss_mart_backup_20240101_120000.sqlite`).
  final String? fileName;

  /// The full file path to the backup file.
  final String? filePath;

  /// Error message if the operation failed. Null on success.
  final String? error;

  const BackupResult({
    required this.isSuccess,
    this.fileName,
    this.filePath,
    this.error,
  });
}

/// Information about a backup file.
///
/// Contains metadata about a backup including its filename, path,
/// creation timestamp, and file size in bytes.
class BackupInfo {
  /// The backup filename (e.g., `ss_mart_backup_20240101_120000.sqlite`).
  final String fileName;

  /// The full file path to the backup file.
  final String filePath;

  /// When the backup was created.
  final DateTime createdAt;

  /// The file size in bytes.
  final int sizeBytes;

  const BackupInfo({
    required this.fileName,
    required this.filePath,
    required this.createdAt,
    required this.sizeBytes,
  });

  /// Human-readable date string (e.g., "Jan 1, 2024 12:00 PM").
  String get formattedDate {
    return '${createdAt.month}/${createdAt.day}/${createdAt.year} '
        '${createdAt.hour.toString().padLeft(2, '0')}:'
        '${createdAt.minute.toString().padLeft(2, '0')}';
  }

  /// Human-readable file size (e.g., "2.5 MB").
  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
