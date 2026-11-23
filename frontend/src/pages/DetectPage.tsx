import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  UploadCloud,
  ArrowLeft,
  Sparkles,
} from 'lucide-react';
import { ImageDropzone } from '../components/upload/ImageDropzone';
import { ImagePreview } from '../components/upload/ImagePreview';
import { ValidationAlert } from '../components/upload/ValidationAlert';
import { ScenarioSelector } from '../components/upload/ScenarioSelector';
import { AnalyzingState } from '../components/upload/AnalyzingState';
import { analyzeLeafImage } from '../services/predictionService';

export function DetectPage() {
  const navigate = useNavigate();

  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [validationError, setValidationError] = useState<string | null>(null);
  const [selectedScenario, setSelectedScenario] = useState<'high' | 'low'>('high');
  const [isAnalyzing, setIsAnalyzing] = useState(false);

  // Clean up object URL when component unmounts or file changes
  useEffect(() => {
    return () => {
      if (previewUrl && previewUrl.startsWith('blob:')) {
        URL.revokeObjectURL(previewUrl);
      }
    };
  }, [previewUrl]);

  const handleFileSelected = (file: File) => {
    setValidationError(null);
    if (previewUrl && previewUrl.startsWith('blob:')) {
      URL.revokeObjectURL(previewUrl);
    }
    setSelectedFile(file);
    setPreviewUrl(URL.createObjectURL(file));
  };

  const handleRemove = () => {
    if (previewUrl && previewUrl.startsWith('blob:')) {
      URL.revokeObjectURL(previewUrl);
    }
    setSelectedFile(null);
    setPreviewUrl(null);
    setValidationError(null);
  };

  const handleAnalyze = async () => {
    if (!selectedFile) {
      setValidationError('Please select or drag-and-drop a leaf specimen image first.');
      return;
    }

    try {
      setIsAnalyzing(true);
      setValidationError(null);
      const submission = await analyzeLeafImage(selectedFile, selectedScenario);
      navigate(`/result/${submission.id}`);
    } catch (err) {
      setIsAnalyzing(false);
      setValidationError(
        err instanceof Error ? err.message : 'An error occurred while analyzing the specimen.'
      );
    }
  };

  // Helper to load a generated SVG sample image for quick presentation testing
  const loadDemoSampleImage = (type: 'blast' | 'ambiguous') => {
    const isBlast = type === 'blast';
    const svgContent = isBlast
      ? `<svg xmlns="http://www.w3.org/2000/svg" width="600" height="400" viewBox="0 0 600 400">
          <rect width="600" height="400" fill="#2d5a3f"/>
          <path d="M50 200 C 150 120, 450 120, 550 200 C 450 280, 150 280, 50 200" fill="#448d5f" stroke="#1b382d" stroke-width="4"/>
          <ellipse cx="260" cy="190" rx="35" ry="12" fill="#c4bfb0" stroke="#5d4037" stroke-width="4"/>
          <ellipse cx="340" cy="210" rx="45" ry="15" fill="#d2ccbd" stroke="#4e342e" stroke-width="5"/>
          <ellipse cx="180" cy="205" rx="25" ry="9" fill="#bcaaa4" stroke="#3e2723" stroke-width="3"/>
          <text x="300" y="340" font-family="sans-serif" font-size="20" font-weight="bold" fill="#ffffff" text-anchor="middle">Demo Rice Blast Leaf Sample</text>
        </svg>`
      : `<svg xmlns="http://www.w3.org/2000/svg" width="600" height="400" viewBox="0 0 600 400">
          <rect width="600" height="400" fill="#3b4d3f"/>
          <path d="M50 200 C 150 130, 450 130, 550 200 C 450 270, 150 270, 50 200" fill="#809055" stroke="#253526" stroke-width="4"/>
          <circle cx="280" cy="195" r="28" fill="#a49355" opacity="0.6"/>
          <circle cx="330" cy="210" r="35" fill="#908040" opacity="0.5"/>
          <text x="300" y="340" font-family="sans-serif" font-size="20" font-weight="bold" fill="#ffffff" text-anchor="middle">Demo Inconclusive Discolored Leaf Sample</text>
        </svg>`;

    const blob = new Blob([svgContent], { type: 'image/svg+xml' });
    const file = new File([blob], isBlast ? 'specimen_rice_blast_foliar.png' : 'specimen_chlorotic_foliar.png', {
      type: 'image/png',
    });

    setSelectedScenario(isBlast ? 'high' : 'low');
    handleFileSelected(file);
  };

  return (
    <div className="py-8 sm:py-12 max-w-4xl mx-auto px-4 sm:px-6 w-full">
      {/* Top Breadcrumb */}
      <div className="mb-6">
        <button
          type="button"
          onClick={() => navigate('/')}
          className="inline-flex items-center gap-1.5 text-xs font-mono text-[#575E54] hover:text-[#1C3227] transition-colors"
        >
          <ArrowLeft className="w-3.5 h-3.5" />
          <span>Return to Overview</span>
        </button>
      </div>

      {/* Page Title & Context */}
      <div className="mb-8 space-y-2 border-b border-[#E3E1D7] pb-6">
        <span className="text-[10px] font-mono uppercase tracking-widest text-[#777B73] block">
          Specimen Intake &bull; Calibrated Diagnostic Pipeline
        </span>
        <h1 className="font-serif text-3xl sm:text-4xl text-[#1C3227] tracking-tight">
          Submit a foliar specimen for diagnostic evaluation
        </h1>
        <p className="text-xs sm:text-sm text-[#575E54] leading-relaxed max-w-2xl font-sans">
          Upload a high-resolution photograph of an affected leaf blade. The evaluation model estimates lesion morphology and computes classification confidence.
        </p>
      </div>

      {/* Presentation Scenario Selector */}
      <ScenarioSelector
        scenario={selectedScenario}
        onSelect={(scenario) => setSelectedScenario(scenario)}
      />

      {/* Validation Error Banner */}
      {validationError && (
        <ValidationAlert
          message={validationError}
          onClear={() => setValidationError(null)}
        />
      )}

      {/* Main Upload / Preview / Analyzing Area */}
      {isAnalyzing ? (
        <AnalyzingState
          scenarioName={
            selectedScenario === 'high'
              ? 'Conclusive (Rice Blast — 94%)'
              : 'Inconclusive (Ambiguous Discoloration — 41%)'
          }
        />
      ) : (
        <div className="space-y-6">
          {!selectedFile ? (
            <div className="space-y-4">
              <ImageDropzone
                onFileSelected={handleFileSelected}
                onError={(msg) => setValidationError(msg)}
              />

              {/* Quick Sample Selector for Presentations */}
              <div className="p-4 rounded-xl bg-[#FAF9F5] border border-[#E3E1D7]">
                <div className="flex items-center justify-between flex-wrap gap-2 mb-2.5">
                  <span className="text-xs font-mono text-[#424840] font-semibold flex items-center gap-1.5">
                    <Sparkles className="w-3.5 h-3.5 text-[#78664E]" />
                    Reference Demonstration Samples
                  </span>
                  <span className="text-[11px] font-mono text-[#777B73]">One-click specimen loading</span>
                </div>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
                  <button
                    type="button"
                    onClick={() => loadDemoSampleImage('blast')}
                    className="flex items-center justify-between p-3 rounded-lg border border-[#E3E1D7] hover:border-[#243E30] bg-[#FFFFFF] hover:bg-[#F2F5F3] text-left transition-all text-xs"
                  >
                    <div>
                      <strong className="block text-[#1C3227] font-medium font-sans">
                        Specimen: Rice Blast
                      </strong>
                      <span className="text-[11px] text-[#345842] font-mono">
                        Conclusive Diagnostic Tier (94%)
                      </span>
                    </div>
                    <span className="text-[10px] bg-[#EAE8DD] px-1.5 py-0.5 rounded border border-[#DCD9CE] font-mono text-[#575E54]">
                      PNG
                    </span>
                  </button>

                  <button
                    type="button"
                    onClick={() => loadDemoSampleImage('ambiguous')}
                    className="flex items-center justify-between p-3 rounded-lg border border-[#E3E1D7] hover:border-[#865721] bg-[#FFFFFF] hover:bg-[#FBF4EB] text-left transition-all text-xs"
                  >
                    <div>
                      <strong className="block text-[#1C3227] font-medium font-sans">
                        Specimen: Chlorotic Blade
                      </strong>
                      <span className="text-[11px] text-[#865721] font-mono">
                        Inconclusive Triage Tier (41%)
                      </span>
                    </div>
                    <span className="text-[10px] bg-[#EAE8DD] px-1.5 py-0.5 rounded border border-[#DCD9CE] font-mono text-[#575E54]">
                      PNG
                    </span>
                  </button>
                </div>
              </div>
            </div>
          ) : (
            <div className="space-y-6">
              <ImagePreview
                file={selectedFile}
                previewUrl={previewUrl!}
                onReplace={handleFileSelected}
                onRemove={handleRemove}
              />

              {/* Ready to Analyze Action Bar */}
              <div className="bg-[#FAF9F5] rounded-xl border border-[#E3E1D7] p-5 flex flex-col sm:flex-row items-center justify-between gap-4">
                <div>
                  <h4 className="text-sm font-serif text-[#1C3227]">
                    Specimen ready for pathology evaluation
                  </h4>
                  <p className="text-xs text-[#575E54] mt-0.5 font-mono">
                    Simulation target:{' '}
                    <strong className="text-[#243E30] font-semibold">
                      {selectedScenario === 'high'
                        ? 'Conclusive (Rice Blast — 94%)'
                        : 'Inconclusive (Queued for Specialist — 41%)'}
                    </strong>
                  </p>
                </div>

                <button
                  type="button"
                  onClick={handleAnalyze}
                  className="w-full sm:w-auto inline-flex items-center justify-center gap-2 px-6 py-2.5 rounded-lg font-medium text-xs sm:text-sm text-[#FAF9F5] bg-[#243E30] hover:bg-[#1C3227] transition-colors shadow-xs"
                >
                  <UploadCloud className="w-4 h-4 text-[#C7D6CC]" />
                  <span>Run Diagnostic Analysis</span>
                </button>
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}