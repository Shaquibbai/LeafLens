export type ReviewOutcome = 'DISEASE_IDENTIFIED' | 'INCONCLUSIVE';

export interface AdminReview {
  id: string; // e.g. "rev_1732289456123_abc"
  submissionId: string;
  outcome: ReviewOutcome;
  assessedDiseaseId: string | null;
  assessedDiseaseName: string | null;
  adminNotes: string; // Strictly private: never displayed on public result pages
  reviewTimestamp: string; // ISO 8601 string
  reviewerIdentity: string; // e.g. "Dr. S. Rahman (Agricultural Extension Specialist)"
}
