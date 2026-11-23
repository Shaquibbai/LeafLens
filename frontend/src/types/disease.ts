/**
 * Rice disease information and illustrative metadata.
 */
export interface DiseaseInfo {
  id: string;
  commonName: string;
  scientificName: string;
  description: string;
  symptoms: string[];
  recommendations: string[];
  prevention: string[];
  severity: 'mild' | 'moderate' | 'severe' | 'none';
}
