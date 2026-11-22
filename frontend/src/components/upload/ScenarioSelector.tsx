interface ScenarioSelectorProps {
  scenario: 'high' | 'low';
  onSelect: (scenario: 'high' | 'low') => void;
}

export function ScenarioSelector({ scenario, onSelect }: ScenarioSelectorProps) {
  return (
    <div className="bg-[#FAF9F5] rounded-xl border border-[#E3E1D7] p-4 sm:p-5 mb-6">
      <div className="flex items-center justify-between pb-3 mb-3 border-b border-[#E3E1D7]">
        <div className="space-y-0.5">
          <span className="text-[10px] font-mono uppercase tracking-wider text-[#777B73] block">
            Evaluation Control
          </span>
          <h3 className="text-xs sm:text-sm font-semibold text-[#1C3227]">
            Operational Simulation Scenario
          </h3>
        </div>
        <span className="text-[11px] font-mono text-[#777B73] px-2 py-0.5 rounded bg-[#ECEAE0] border border-[#DCD9CE]">
          Deterministic Preset
        </span>
      </div>

      <p className="text-xs text-[#575E54] mb-3">
        Select a calibrated simulation preset to evaluate the diagnostic decision pathways:
      </p>

      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
        {/* High Confidence Option */}
        <button
          type="button"
          onClick={() => onSelect('high')}
          className={`flex items-start gap-3 p-3.5 rounded-lg border text-left transition-all ${
            scenario === 'high'
              ? 'border-[#243E30] bg-[#FFFFFF] shadow-xs'
              : 'border-[#E3E1D7] bg-[#FAF9F5] hover:border-[#BCC0B9]'
          }`}
        >
          <div
            className={`w-4 h-4 rounded-full flex items-center justify-center mt-0.5 flex-shrink-0 border transition-colors ${
              scenario === 'high'
                ? 'border-[#243E30] bg-[#243E30]'
                : 'border-[#BCC0B9] bg-white'
            }`}
          >
            {scenario === 'high' && <span className="w-1.5 h-1.5 rounded-full bg-white" />}
          </div>
          <div className="space-y-0.5">
            <span className="text-xs sm:text-sm font-medium text-[#1C3227] block">
              Conclusive Visual Match (94%)
            </span>
            <span className="text-[11px] font-mono text-[#345842] block">
              Condition: Rice Blast (*Pyricularia oryzae*)
            </span>
            <p className="text-[11px] text-[#6C7167] leading-relaxed pt-1">
              Demonstrates definitive automated classification, symptom profile, and illustrative cultural advisories.
            </p>
          </div>
        </button>

        {/* Low Confidence Option */}
        <button
          type="button"
          onClick={() => onSelect('low')}
          className={`flex items-start gap-3 p-3.5 rounded-lg border text-left transition-all ${
            scenario === 'low'
              ? 'border-[#865721] bg-[#FFFFFF] shadow-xs'
              : 'border-[#E3E1D7] bg-[#FAF9F5] hover:border-[#BCC0B9]'
          }`}
        >
          <div
            className={`w-4 h-4 rounded-full flex items-center justify-center mt-0.5 flex-shrink-0 border transition-colors ${
              scenario === 'low'
                ? 'border-[#865721] bg-[#865721]'
                : 'border-[#BCC0B9] bg-white'
            }`}
          >
            {scenario === 'low' && <span className="w-1.5 h-1.5 rounded-full bg-white" />}
          </div>
          <div className="space-y-0.5">
            <span className="text-xs sm:text-sm font-medium text-[#1C3227] block">
              Inconclusive Signal (41% Triage)
            </span>
            <span className="text-[11px] font-mono text-[#865721] block">
              Ambiguous / Chlorotic Discoloration
            </span>
            <p className="text-[11px] text-[#6C7167] leading-relaxed pt-1">
              Demonstrates advisory withholding and automatic triage into the specialist inspection queue.
            </p>
          </div>
        </button>
      </div>
    </div>
  );
}
