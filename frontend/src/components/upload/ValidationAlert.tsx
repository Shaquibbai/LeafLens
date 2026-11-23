import { AlertCircle, X } from 'lucide-react';

interface ValidationAlertProps {
  message: string;
  onClear: () => void;
}

export function ValidationAlert({ message, onClear }: ValidationAlertProps) {
  return (
    <div className="p-3.5 rounded-lg bg-[#FAF0EE] border border-[#ECCEC8] text-[#8E3526] text-xs sm:text-sm flex items-start justify-between gap-3 mb-5">
      <div className="flex items-start gap-2.5">
        <AlertCircle className="w-4 h-4 text-[#8E3526] flex-shrink-0 mt-0.5" />
        <div>
          <span className="font-semibold block text-[#5E2218]">Intake Notice</span>
          <p className="mt-0.5 text-xs text-[#8E3526] leading-relaxed">{message}</p>
        </div>
      </div>
      <button
        type="button"
        onClick={onClear}
        className="text-[#8E3526] hover:text-[#5E2218] p-1 rounded transition-colors"
        title="Dismiss notice"
      >
        <X className="w-3.5 h-3.5" />
      </button>
    </div>
  );
}
