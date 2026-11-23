import { Submission, SubmissionStatus } from '../types/submission';
import { saveImageBlob, hasImageBlob, dataUrlToBlob } from './imageStorageService';

const STORAGE_KEY = 'leaflens_submissions_v1';
const MIGRATION_FLAG_KEY = 'leaflens_image_migration_v1';

/**
 * Reads all stored submission metadata from localStorage safely.
 */
export function getAllSubmissions(): Submission[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) return [];
    return parsed;
  } catch (error) {
    console.warn('Failed to read LeafLens submissions from localStorage:', error);
    return [];
  }
}

/**
 * Retrieves a single submission metadata record by its unique identifier.
 */
export function getSubmissionById(id: string): Submission | null {
  const all = getAllSubmissions();
  return all.find((sub) => sub.id === id) || null;
}

/**
 * Persists a new submission's metadata. Existing submissions are never overwritten.
 * The newest submission is placed at the beginning of the queue.
 *
 * NOTE: Image bytes are stored as binary Blobs in IndexedDB.
 * Any base64 image field is sanitized prior to persisting to localStorage.
 */
export function saveSubmission(submission: Submission): void {
  try {
    const existing = getAllSubmissions();

    // Sanitize submission to guarantee no base64 string enters localStorage metadata
    const sanitized: Submission = {
      id: submission.id,
      timestamp: submission.timestamp,
      fileName: submission.fileName,
      mimeType: submission.mimeType || 'image/jpeg',
      fileSize: submission.fileSize,
      prediction: { ...submission.prediction },
      status: submission.status,
      reviewId: submission.reviewId || null,
    };

    const updated = [sanitized, ...existing.filter((s) => s.id !== sanitized.id)];
    localStorage.setItem(STORAGE_KEY, JSON.stringify(updated));
  } catch (error) {
    console.error('Failed to save LeafLens submission metadata to localStorage:', error);
  }
}

/**
 * Updates a submission's status and review reference.
 *
 * CRITICAL RULE: Preserves the original model prediction and confidence score intact.
 */
export function updateSubmissionStatus(
  submissionId: string,
  newStatus: SubmissionStatus,
  reviewId?: string
): boolean {
  try {
    const all = getAllSubmissions();
    const index = all.findIndex((s) => s.id === submissionId);
    if (index === -1) return false;

    all[index] = {
      ...all[index],
      status: newStatus,
      reviewId: reviewId !== undefined ? reviewId : all[index].reviewId,
    };

    localStorage.setItem(STORAGE_KEY, JSON.stringify(all));
    return true;
  } catch (error) {
    console.error('Failed to update submission status:', error);
    return false;
  }
}

/**
 * Safely migrates legacy Milestone 1 submissions that stored base64 image data in localStorage.
 * Converts base64 Data URLs to Blobs, stores them in IndexedDB, verifies retrieval,
 * and then strips the base64 string from active localStorage metadata.
 */
export async function migrateLegacySubmissions(): Promise<{
  migratedCount: number;
  failedCount: number;
}> {
  if (typeof window === 'undefined') {
    return { migratedCount: 0, failedCount: 0 };
  }

  // Check if migration has already been executed
  const flag = localStorage.getItem(MIGRATION_FLAG_KEY);
  if (flag === 'completed') {
    return { migratedCount: 0, failedCount: 0 };
  }

  const all = getAllSubmissions();
  let migratedCount = 0;
  let failedCount = 0;
  let hasModified = false;

  for (let i = 0; i < all.length; i++) {
    const sub = all[i];

    // If legacy record has embedded base64 image data
    if (sub.imageDataUrl && sub.imageDataUrl.startsWith('data:')) {
      try {
        const blob = dataUrlToBlob(sub.imageDataUrl);
        await saveImageBlob(sub.id, blob);

        // Verify retrieval before altering metadata
        const verified = await hasImageBlob(sub.id);
        if (verified) {
          // Remove embedded base64 from active record
          delete sub.imageDataUrl;
          if (!sub.mimeType) sub.mimeType = blob.type || 'image/jpeg';
          migratedCount++;
          hasModified = true;
        } else {
          console.error(`Verification failed for migrated image ${sub.id}. Preserving legacy data.`);
          failedCount++;
        }
      } catch (err) {
        console.error(`Migration failed for submission ${sub.id}:`, err);
        failedCount++;
      }
    }
  }

  if (hasModified) {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(all));
  }

  if (failedCount === 0) {
    localStorage.setItem(MIGRATION_FLAG_KEY, 'completed');
  }

  return { migratedCount, failedCount };
}

/**
 * Clears stored submissions and migration flag (useful for development resets).
 */
export function clearAllSubmissions(): void {
  try {
    localStorage.removeItem(STORAGE_KEY);
    localStorage.removeItem(MIGRATION_FLAG_KEY);
  } catch (error) {
    console.warn('Failed to clear LeafLens submissions:', error);
  }
}
