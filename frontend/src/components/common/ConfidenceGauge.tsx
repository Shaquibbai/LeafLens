import { ConfidenceTier } from '../../types/submission';

interface ConfidenceGaugeProps {
  confidence: number; // 0.0 to 1.0
  tier: ConfidenceTier;
  explanation: string;
}

export function ConfidenceGauge({ confidence, tier, explanation }: ConfidenceGaugeProps) {
  const percentage = Math.round(confidence * 100);
  const isHigh = tier === 'high';

  return (
    <div className="bg-[#FAF9F5] rounded-xl border border-[#E3E1D7] p-4 sm:p-5 shadow-xs">
      <div className="flex items-center justify-between mb-3 pb-2 border-b border-[#E3E1D7]">
        <div className="space-y-0.5">
          <span className="text-[10px] font-mono uppercase tracking-wider text-[#777B73] block">
            Algorithmic Metric
          </span>
          <h4 className="text-xs sm:text-sm font-semibold text-[#1C3227]">
            Model Classification Confidence
          </h4>
        </div>
        <div className="flex items-baseline space-x-1.5 font-mono">
          <span
            className={`text-2xl font-bold tracking-tight ${
              isHigh ? 'text-[#243E30]' : 'text-[#865721]'
            }`}
          >
            {percentage}%
          </span>
          <span className="text-xs text-[#777B73]">/ 100%</span>
        </div>
      </div>

      {/* Subtle Editorial Scale Bar */}
      <div className="space-y-1.5 mb-3.5">
        <div className="w-full h-2 bg-[#ECEAE0] rounded-full overflow-hidden border border-[#DCD9CE]">
          <div
            className={`h-full rounded-full transition-all duration-700 ease-out ${
              isHigh ? 'bg-[#243E30]' : 'bg-[#865721]'
            }`}
            style={{ width: `${percentage}%` }}
          />
        </div>
        <div className="flex justify-between text-[10px] font-mono text-[#777B73]">
          <span>0% (Uncertain)</span>
          <span className="text-center">&bull; 70% Diagnostic Threshold &bull;</span>
          <span>100% (Definitive)</span>
        </div>
      </div>

      {/* Explanation text */}
      <div className="bg-[#EAE8DD]/70 p-3 rounded-lg border border-[#DCD9CE] text-xs text-[#575E54] leading-relaxed">
        <strong className="text-[#1C3227] font-medium block mb-0.5 font-sans">
          Confidence Analysis:
        </strong>
        {explanation}
      </div>

      {/* Scientific integrity note */}
      <p className="mt-2 text-[10px] font-mono text-[#777B73] leading-normal">
        * Model confidence reflects the statistical certainty of the visual classification algorithm, not clinical certainty or guaranteed field truth.
      </p>
    </div>
  );
}
