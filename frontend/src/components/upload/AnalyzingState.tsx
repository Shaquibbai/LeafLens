import { useState, useEffect } from 'react';
import { Loader2 } from 'lucide-react';

interface AnalyzingStateProps {
  scenarioName?: string;
}

const STEPS = [
  'Verifying foliar blade demarcation...',
  'Extracting necrotic margin and chlorotic halo profiles...',
  'Evaluating pattern match against calibrated pathology dataset...',
  'Compiling confidence metrics and triage routing...',
];

export function AnalyzingState({ scenarioName }: AnalyzingStateProps) {
  const [currentStep, setCurrentStep] = useState(0);

  useEffect(() => {
    const interval = setInterval(() => {
      setCurrentStep((prev) => (prev < STEPS.length - 1 ? prev + 1 : prev));
    }, 220);

    return () => clearInterval(interval);
  }, []);

  return (
    <div className="bg-[#FAF9F5] rounded-xl border border-[#E3E1D7] p-8 sm:p-12 text-center shadow-xs">
      <div className="max-w-md mx-auto space-y-4">
        {/* Subtle Spinner */}
        <div className="w-10 h-10 rounded-full border-2 border-[#DCD9CE] border-t-[#243E30] animate-spin mx-auto" />

        <div>
          <h3 className="font-serif text-2xl text-[#1C3227]">
            Analyzing foliar specimen
          </h3>
          {scenarioName && (
            <span className="font-mono text-xs text-[#78664E] block mt-1">
              Active profile: {scenarioName}
            </span>
          )}
        </div>

        {/* Current Pipeline Step */}
        <div className="bg-[#EAE8DD] rounded-lg p-3 border border-[#DCD9CE]">
          <div className="flex items-center justify-center gap-2 text-xs font-mono text-[#243E30]">
            <Loader2 className="w-3.5 h-3.5 animate-spin text-[#345842]" />
            <span>{STEPS[currentStep]}</span>
          </div>
        </div>

        {/* Progress Bar */}
        <div className="w-full bg-[#E3E1D7] rounded-full h-1.5 overflow-hidden">
          <div
            className="bg-[#243E30] h-full rounded-full transition-all duration-300 ease-out"
            style={{ width: `${((currentStep + 1) / STEPS.length) * 100}%` }}
          />
        </div>

        <p className="text-[11px] text-[#777B73] font-mono">
          Simulating neural network inference &amp; confidence estimation
        </p>
      </div>
    </div>
  );
}
