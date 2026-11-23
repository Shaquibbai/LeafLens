import { HealthCheckResponse } from '../types/api'

/**
 * Checks backend health and configuration metadata.
 */
export async function checkBackendHealth(): Promise<HealthCheckResponse> {
  const response = await fetch('/api/v1/health')
  if (!response.ok) {
    throw new Error(`Backend returned status ${response.status}: ${response.statusText}`)
  }
  return response.json()
}
