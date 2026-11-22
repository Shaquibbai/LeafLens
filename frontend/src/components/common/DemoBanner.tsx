interface DemoBannerProps {
  scenarioName?: string;
}

export function DemoBanner({ scenarioName }: DemoBannerProps) {
  return (
    <div className="bg-[#FAF9F5] border border-[#E3E1D7] rounded-lg p-3 sm:p-3.5 mb-6 text-xs text-[#575E54] flex items-start justify-between gap-3 shadow-xs">
      <div className="space-y-0.5">
        <div className="flex flex-wrap items-center gap-2">
          <span className="font-mono text-[10px] uppercase tracking-wider font-semibold text-[#78664E]">
            Simulation Preset Active
          </span>
          {scenarioName && (
            <span className="px-2 py-0.5 bg-[#EAE8DD] rounded text-[11px] font-mono text-[#243E30] border border-[#DCD9CE]">
              {scenarioName}
            </span>
          )}
        </div>
        <p className="text-xs text-[#6C7167] leading-relaxed pt-0.5">
          Model classifications are computed via calibrated demonstration profiles. Confidence scores represent algorithmic certainty rather than on-site clinical guarantees.
        </p>
      </div>
    </div>
  );
}
