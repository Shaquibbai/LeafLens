import { MOCK_SCENARIOS } from '../data/mockDiseases';
import { PredictionResult, Submission, SubmissionStatus } from '../types/submission';
import { saveSubmission } from './storageService';
import { saveImageBlob } from './imageStorageService';

/**
 * Generates a clean, unique submission identifier.
 */
function generateSubmissionId(): string {
  const timestamp = Date.now().toString(36);
  const random = Math.random().toString(36).substring(2, 7);
  return `sub_${timestamp}_${random}`;
}

/**
 * Analyzes a rice leaf image using the deterministic mock prediction engine.
 *
 * Saves the original binary image directly into IndexedDB as a Blob,
 * and records lightweight metadata in localStorage without base64 bloat.
 */
export async function analyzeLeafImage(
  file: File,
  scenario: 'high' | 'low' = 'high'
): Promise<Submission> {
  // Simulate network & GPU processing time
  await new Promise((resolve) => setTimeout(resolve, 850));

  const submissionId = generateSubmissionId();
  const predictionTemplate: PredictionResult = MOCK_SCENARIOS[scenario];

  const status: SubmissionStatus =
    predictionTemplate.confidenceTier === 'high' ? 'completed' : 'flagged_for_review';

  // 1. Store binary Blob directly in IndexedDB
  await saveImageBlob(submissionId, file);

  // 2. Prepare lightweight metadata (without base64 image data)
  const submission: Submission = {
    id: submissionId,
    timestamp: new Date().toISOString(),
    fileName: file.name,
    mimeType: file.type || 'image/jpeg',
    fileSize: file.size,
    prediction: { ...predictionTemplate },
    status,
    reviewId: null,
  };

  // 3. Persist metadata to local storage
  saveSubmission(submission);

  return submission;
}
