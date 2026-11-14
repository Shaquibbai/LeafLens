export interface HealthCheckResponse {
  status: string;
  service: string;
  version: string;
  supported_crops: string[];
  model_status: string;
}
