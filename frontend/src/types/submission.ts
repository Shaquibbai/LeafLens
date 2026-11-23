export type ConfidenceTier = 'high' | 'low';

export type SubmissionStatus = 'completed' | 'flagged_for_review' | 'reviewed';

export interface PredictionResult {
  scenarioId: 'high_confidence_blast' | 'low_confidence_uncertain';
  diseaseId: string;
  diseaseName: string;
  scientificName?: string;
  confidence: number; // 0.0 - 1.0 (e.g. 0.94 or 0.41)
  confidenceTier: ConfidenceTier;
  confidenceExplanation: string;
  description: string;
  symptoms: string[];
  recommendations: string[];
  requiresAdminReview: boolean;
  reviewReason?: string;
  isMock: boolean;
}

export interface Submission {
  id: string; // Unique submission identifier e.g. "sub_1732289456123_abc"
  timestamp: string; // ISO 8601 string
  fileName: string;
  mimeType: string;
  fileSize: number; // in bytes
  prediction: PredictionResult;
  status: SubmissionStatus;
  reviewId?: string | null; // Reference to AdminReview record
  /**
   * Deprecated: Only present on unmigrated legacy Milestone 1 records.
   * Stripped automatically once image is safely stored in IndexedDB.
   */
  imageDataUrl?: string;
}
