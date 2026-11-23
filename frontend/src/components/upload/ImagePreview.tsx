import React, { useRef } from 'react';
import { RefreshCw, Trash2, CheckCircle2 } from 'lucide-react';

interface ImagePreviewProps {
  file: File;
  previewUrl: string;
  onReplace: (file: File) => void;
  onRemove: () => void;
}

const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/webp'];

export function ImagePreview({ file, previewUrl, onReplace, onRemove }: ImagePreviewProps) {
  const replaceInputRef = useRef<HTMLInputElement>(null);

  const formatFileSize = (bytes: number): string => {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files.length > 0) {
      const selected = e.target.files[0];
      if (ALLOWED_TYPES.includes(selected.type)) {
        onReplace(selected);
      }
    }
  };

  return (
    <div className="bg-[#FAF9F5] rounded-xl border border-[#E3E1D7] p-5 shadow-xs">
      <input
        ref={replaceInputRef}
        type="file"
        accept="image/jpeg,image/png,image/webp"
        onChange={handleFileChange}
        className="hidden"
      />

      <div className="flex flex-col sm:flex-row items-center gap-5">
        {/* Specimen Thumbnail Plate */}
        <div className="w-full sm:w-44 h-44 rounded-lg overflow-hidden bg-[#ECEAE0] border border-[#DCD9CE] flex items-center justify-center relative flex-shrink-0">
          <img
            src={previewUrl}
            alt="Uploaded rice leaf preview"
            className="w-full h-full object-cover"
          />
          <span className="absolute bottom-2 left-2 px-2 py-0.5 rounded bg-[#1C3227]/80 text-[#FAF9F5] text-[10px] font-mono">
            Foliar Plate
          </span>
        </div>

        {/* Specimen File Metadata */}
        <div className="flex-1 flex flex-col justify-between w-full h-full py-1">
          <div className="space-y-1">
            <div className="flex items-center gap-2 mb-1">
              <span className="inline-flex items-center gap-1 text-[11px] font-mono text-[#243E30] bg-[#EAE8DD] px-2 py-0.5 rounded border border-[#DCD9CE]">
                <CheckCircle2 className="w-3 h-3 text-[#345842]" />
                Specimen Verified
              </span>
              <span className="text-[11px] text-[#777B73] font-mono">
                {file.type.replace('image/', '').toUpperCase()}
              </span>
            </div>

            <h4
              className="font-serif text-lg text-[#1C3227] break-all line-clamp-1"
              title={file.name}
            >
              {file.name}
            </h4>

            <p className="text-xs text-[#575E54] font-mono">
              Payload size: {formatFileSize(file.size)}
            </p>

            <p className="text-xs text-[#6C7167] pt-1">
              File validated for local binary storage and diagnostic evaluation.
            </p>
          </div>

          {/* Action Buttons */}
          <div className="flex items-center gap-3 mt-4 pt-3 border-t border-[#E3E1D7]">
            <button
              type="button"
              onClick={() => replaceInputRef.current?.click()}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium text-[#243E30] bg-[#EAE8DD] hover:bg-[#DFDCCF] border border-[#DCD9CE] transition-colors"
            >
              <RefreshCw className="w-3 h-3 text-[#345842]" />
              <span>Replace Specimen</span>
            </button>

            <button
              type="button"
              onClick={onRemove}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium text-[#8E3526] hover:text-[#5E2218] transition-colors ml-auto"
            >
              <Trash2 className="w-3.5 h-3.5" />
              <span>Remove</span>
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
