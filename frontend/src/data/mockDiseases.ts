import { PredictionResult } from '../types/submission';

/**
 * Deterministic demonstration scenarios for the LeafLens presentation prototype.
 *
 * NOTE: These are curated mock prediction records designed for interactive demonstration.
 * They are clearly identified as simulated data and do not represent actual ML model evaluations.
 */
export const MOCK_SCENARIOS: Record<'high' | 'low', PredictionResult> = {
  high: {
    scenarioId: 'high_confidence_blast',
    diseaseId: 'rice_blast',
    diseaseName: 'Rice Blast',
    scientificName: 'Magnaporthe oryzae',
    confidence: 0.94,
    confidenceTier: 'high',
    confidenceExplanation:
      'The simulated visual classification algorithm detected diagnostic spindle-shaped lesions with grayish necrotic centers and dark reddish-brown borders characteristic of Rice Blast.',
    description:
      'Rice Blast is one of the most widespread and damaging fungal diseases affecting cultivated rice crops. It can infect leaves, leaf collars, stems, and panicles. On leaves, early infections start as small whitish-gray spots that quickly enlarge into elliptical or diamond-shaped lesions.',
    symptoms: [
      'Spindle-shaped (diamond-like) lesions with grayish-white centers and brownish borders.',
      'Lesions enlarge and coalesce during periods of high humidity, leading to extensive leaf withering.',
      'Younger leaves exhibit higher vulnerability compared to mature, silica-rich foliage.',
    ],
    recommendations: [
      'Avoid excessive application of nitrogen fertilizers, which accelerates tissue susceptibility.',
      'Maintain adequate water level in the paddy; avoid prolonged dry soil conditions that stress the crop.',
      'Consult local agricultural extension specialists regarding recommended systemic fungicide sprays (e.g., tricyclazole) if disease threshold is breached.',
      'Inspect field borders to ensure proper air circulation and morning dew evaporation.',
    ],
    requiresAdminReview: false,
    isMock: true,
  },
  low: {
    scenarioId: 'low_confidence_uncertain',
    diseaseId: 'unresolved_lesion',
    diseaseName: 'Inconclusive / Ambiguous Symptoms',
    scientificName: 'Pathogen Unconfirmed',
    confidence: 0.41,
    confidenceTier: 'low',
    confidenceExplanation:
      'The simulated model confidence is below the diagnostic confidence threshold (41%). Discoloration patterns overlap with multiple conditions (such as drought stress, nitrogen deficiency, or early Brown Spot) or the image lighting may be suboptimal.',
    description:
      'The visual patterns on this leaf do not match any known rice disease profile with sufficient certainty. To avoid misleading field personnel or recommending inappropriate treatments, the system refuses to make an unconfirmed diagnosis.',
    symptoms: [
      'Diffuse brownish-yellow mottling without distinct margins.',
      'Absence of diagnostic necrotic halos or sporulation rings.',
      'Possible environmental or physical stress masking pathology.',
    ],
    recommendations: [
      'Do not apply chemical fungicides or pesticide treatments based on this inconclusive prediction.',
      'Inspect surrounding hills in the paddy to check whether symptoms are localized or widespread.',
      'Capture another photograph of a newly expanded leaf under uniform natural daylight.',
      'This submission has been automatically logged and queued for agricultural specialist review.',
    ],
    requiresAdminReview: true,
    reviewReason:
      'Classification confidence (41%) fell below the diagnostic threshold. Queued for human verification.',
    isMock: true,
  },
};

/**
 * Standard rice pathology options available for independent specialist assessment.
 */
export interface DiseaseOption {
  id: string;
  name: string;
  scientificName: string;
}

export const VERIFIED_DISEASE_OPTIONS: DiseaseOption[] = [
  { id: 'rice_blast', name: 'Rice Blast', scientificName: 'Magnaporthe oryzae' },
  { id: 'bacterial_blight', name: 'Bacterial Leaf Blight', scientificName: 'Xanthomonas oryzae' },
  { id: 'brown_spot', name: 'Brown Spot', scientificName: 'Bipolaris oryzae' },
  { id: 'sheath_blight', name: 'Sheath Blight', scientificName: 'Rhizoctonia solani' },
  { id: 'rice_tungro', name: 'Rice Tungro Disease', scientificName: 'RTBV / RTSV Complex' },
  { id: 'healthy_leaf', name: 'Healthy Leaf (No Pathology)', scientificName: 'Physiologically Normal' },
];
