import { useEffect, useState } from 'react'
import { Leaf, CheckCircle2, AlertCircle, RefreshCw, Server, ShieldCheck } from 'lucide-react'
import { checkBackendHealth } from './api/client'
import { HealthCheckResponse } from './types/api'

export default function App() {
  const [health, setHealth] = useState<HealthCheckResponse | null>(null)
  const [loading, setLoading] = useState<boolean>(true)
  const [error, setError] = useState<string | null>(null)
  const [lastChecked, setLastChecked] = useState<string | null>(null)

  const fetchHealth = async () => {
    setLoading(true)
    setError(null)
    try {
      const data = await checkBackendHealth()
      setHealth(data)
      setLastChecked(new Date().toLocaleTimeString())
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to connect to backend server')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchHealth()
  }, [])

  return (
    <div className="min-h-screen bg-[#F8FAF8] text-[#1B382D] flex flex-col font-sans">
      {/* Top Navigation Bar */}
      <header className="border-b border-leaf-100 bg-white/80 backdrop-blur-sm sticky top-0 z-10">
        <div className="max-w-5xl mx-auto px-4 sm:px-6 h-16 flex items-center justify-between">
          <div className="flex items-center space-x-2.5">
            <div className="w-10 h-10 rounded-xl bg-leaf-600 flex items-center justify-center text-white shadow-sm shadow-leaf-600/20">
              <Leaf className="w-5 h-5" />
            </div>
            <div>
              <span className="font-semibold text-lg tracking-tight text-leaf-900 block leading-tight">
                LeafLens
              </span>
              <span className="text-xs text-leaf-600 font-medium">Rice Disease Detection</span>
            </div>
          </div>

          <div className="flex items-center space-x-2">
            <span className="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium bg-leaf-100 text-leaf-800 border border-leaf-200">
              Crop: Rice (Initial Scope)
            </span>
          </div>
        </div>
      </header>

      {/* Main Content Area */}
      <main className="flex-1 max-w-5xl w-full mx-auto px-4 sm:px-6 py-10">
        <div className="mb-8">
          <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-leaf-100 text-leaf-800 text-xs font-semibold uppercase tracking-wider mb-3">
            <ShieldCheck className="w-3.5 h-3.5" />
            Milestone 1 — Foundation & Scaffold
          </div>
          <h1 className="text-3xl sm:text-4xl font-bold text-leaf-950 tracking-tight">
            System Connectivity Verification
          </h1>
          <p className="mt-2 text-base text-leaf-700 max-w-2xl">
            This verification view confirms that the React + TypeScript frontend and the FastAPI backend
            are running and communicating seamlessly through the API proxy.
          </p>
        </div>

        {/* Backend Status Card */}
        <div className="bg-white rounded-2xl border border-leaf-100 shadow-sm overflow-hidden mb-6">
          <div className="p-6">
            <div className="flex items-center justify-between pb-4 border-b border-leaf-100">
              <div className="flex items-center space-x-3">
                <div className="w-9 h-9 rounded-lg bg-leaf-50 flex items-center justify-center text-leaf-700">
                  <Server className="w-5 h-5" />
                </div>
                <div>
                  <h2 className="font-semibold text-leaf-900 text-base">Backend API Health</h2>
                  <p className="text-xs text-leaf-600">Endpoint: <code>/api/v1/health</code></p>
                </div>
              </div>

              <button
                onClick={fetchHealth}
                disabled={loading}
                className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium text-leaf-700 hover:text-leaf-900 hover:bg-leaf-50 border border-leaf-200 transition-colors disabled:opacity-50"
              >
                <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} />
                {loading ? 'Pinging...' : 'Refresh Status'}
              </button>
            </div>

            <div className="mt-6">
              {loading && !health && !error && (
                <div className="py-8 text-center text-sm text-leaf-600">
                  <RefreshCw className="w-6 h-6 animate-spin mx-auto mb-2 text-leaf-500" />
                  Connecting to backend server...
                </div>
              )}

              {error && (
                <div className="p-4 rounded-xl bg-red-50 border border-red-200 text-red-800 text-sm flex items-start gap-3">
                  <AlertCircle className="w-5 h-5 text-red-600 mt-0.5 flex-shrink-0" />
                  <div>
                    <strong className="font-semibold block">Connection Failed</strong>
                    <p className="text-xs text-red-700 mt-0.5">{error}</p>
                    <p className="text-xs text-red-600 mt-2">
                      Ensure the FastAPI backend is running via:
                      <code className="block mt-1 p-1.5 bg-red-100/70 rounded text-[11px] font-mono">
                        uvicorn app.main:app --reload --port 8000
                      </code>
                    </p>
                  </div>
                </div>
              )}

              {health && (
                <div className="space-y-4">
                  <div className="flex items-center justify-between p-3.5 rounded-xl bg-leaf-50 border border-leaf-200/60">
                    <div className="flex items-center space-x-2.5">
                      <CheckCircle2 className="w-5 h-5 text-emerald-600 flex-shrink-0" />
                      <span className="font-medium text-sm text-leaf-900">
                        Backend Connected & Responsive
                      </span>
                    </div>
                    <span className="text-xs text-leaf-600">
                      Last checked: {lastChecked}
                    </span>
                  </div>

                  <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 gap-3">
                    <div className="p-3.5 rounded-xl border border-leaf-100 bg-[#FBFDFB]">
                      <span className="text-xs text-leaf-600 block">Service Name</span>
                      <strong className="text-sm font-semibold text-leaf-900 mt-0.5 block">
                        {health.service}
                      </strong>
                    </div>

                    <div className="p-3.5 rounded-xl border border-leaf-100 bg-[#FBFDFB]">
                      <span className="text-xs text-leaf-600 block">API Version</span>
                      <strong className="text-sm font-semibold text-leaf-900 mt-0.5 block">
                        v{health.version}
                      </strong>
                    </div>

                    <div className="p-3.5 rounded-xl border border-leaf-100 bg-[#FBFDFB]">
                      <span className="text-xs text-leaf-600 block">Active Crop</span>
                      <strong className="text-sm font-semibold text-leaf-900 mt-0.5 block capitalize">
                        {health.supported_crops.join(', ')}
                      </strong>
                    </div>

                    <div className="p-3.5 rounded-xl border border-leaf-100 bg-[#FBFDFB]">
                      <span className="text-xs text-leaf-600 block">Model Status</span>
                      <strong className="text-sm font-semibold text-amber-700 mt-0.5 block capitalize">
                        {health.model_status}
                      </strong>
                    </div>
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Milestone 1 Checklist Card */}
        <div className="bg-white rounded-2xl border border-leaf-100 p-6 shadow-sm">
          <h3 className="font-semibold text-leaf-900 text-sm uppercase tracking-wider mb-4">
            Milestone 1 Architecture Checklist
          </h3>
          <ul className="space-y-2.5 text-sm text-leaf-700">
            <li className="flex items-center gap-2">
              <CheckCircle2 className="w-4 h-4 text-emerald-600" />
              <span>Decoupled repository structure with <code>frontend/</code> and <code>backend/</code>.</span>
            </li>
            <li className="flex items-center gap-2">
              <CheckCircle2 className="w-4 h-4 text-emerald-600" />
              <span>Comprehensive <code>.gitignore</code> covering Node, Python, virtualenvs, and ML weights.</span>
            </li>
            <li className="flex items-center gap-2">
              <CheckCircle2 className="w-4 h-4 text-emerald-600" />
              <span>React 18 + TypeScript + Vite + Tailwind CSS development environment ready.</span>
            </li>
            <li className="flex items-center gap-2">
              <CheckCircle2 className="w-4 h-4 text-emerald-600" />
              <span>FastAPI backend with CORS and <code>/api/v1/health</code> endpoint active.</span>
            </li>
            <li className="flex items-center gap-2">
              <CheckCircle2 className="w-4 h-4 text-emerald-600" />
              <span>Next phase: Landing Page & Crop Selector (Milestone 2).</span>
            </li>
          </ul>
        </div>
      </main>

      {/* Footer */}
      <footer className="border-t border-leaf-100 bg-white/50 py-4 text-center text-xs text-leaf-600">
        LeafLens &bull; University Software Development Project &bull; Team of 6
      </footer>
    </div>
  )
}
