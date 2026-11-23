import { AdminReview, ReviewOutcome } from '../types/review';
import { updateSubmissionStatus } from './storageService';

const REVIEWS_STORAGE_KEY = 'leaflens_reviews_v1';

/**
 * Reads all review records from localStorage.
 */
export function getAllReviews(): AdminReview[] {
  try {
    const raw = localStorage.getItem(REVIEWS_STORAGE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) return [];
    return parsed;
  } catch (error) {
    console.warn('Failed to read LeafLens reviews from localStorage:', error);
    return [];
  }
}

/**
 * Retrieves a review by submission ID.
 */
export function getReviewBySubmissionId(submissionId: string): AdminReview | null {
  const all = getAllReviews();
  return all.find((r) => r.submissionId === submissionId) || null;
}

/**
 * Retrieves a review by review ID.
 */
export function getReviewById(reviewId: string): AdminReview | null {
  const all = getAllReviews();
  return all.find((r) => r.id === reviewId) || null;
}

/**
 * Generates a unique review identifier.
 */
export function generateReviewId(): string {
  const timestamp = Date.now().toString(36);
  const random = Math.random().toString(36).substring(2, 7);
  return `rev_${timestamp}_${random}`;
}

/**
 * Creates and persists an independent administrator assessment.
 *
 * CRITICAL RULES:
 * 1. Creates a separate review record.
 * 2. Updates the submission status to 'reviewed' and attaches reviewId.
 * 3. Never overwrites or modifies the original ML prediction or confidence score.
 */
export function createAdminReview(params: {
  submissionId: string;
  outcome: ReviewOutcome;
  assessedDiseaseId: string | null;
  assessedDiseaseName: string | null;
  adminNotes: string;
  reviewerIdentity?: string;
}): AdminReview {
  const review: AdminReview = {
    id: generateReviewId(),
    submissionId: params.submissionId,
    outcome: params.outcome,
    assessedDiseaseId: params.assessedDiseaseId,
    assessedDiseaseName: params.assessedDiseaseName,
    adminNotes: params.adminNotes.trim(),
    reviewTimestamp: new Date().toISOString(),
    reviewerIdentity:
      params.reviewerIdentity || 'Dr. S. Rahman (Agricultural Extension Specialist)',
  };

  // 1. Save to review records
  try {
    const existing = getAllReviews();
    const updated = [review, ...existing.filter((r) => r.submissionId !== review.submissionId)];
    localStorage.setItem(REVIEWS_STORAGE_KEY, JSON.stringify(updated));
  } catch (error) {
    console.error('Failed to save review record:', error);
  }

  // 2. Transition submission status to 'reviewed' without touching original prediction
  updateSubmissionStatus(params.submissionId, 'reviewed', review.id);

  return review;
}

/**
 * Clears review records (for development resets).
 */
export function clearAllReviews(): void {
  try {
    localStorage.removeItem(REVIEWS_STORAGE_KEY);
  } catch (error) {
    console.warn('Failed to clear LeafLens reviews:', error);
  }
}
