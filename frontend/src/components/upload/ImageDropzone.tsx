import React, { useRef, useState } from 'react';
import { UploadCloud, Image as ImageIcon } from 'lucide-react';

interface ImageDropzoneProps {
  onFileSelected: (file: File) => void;
  onError: (message: string) => void;
}

const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
const MAX_SIZE_MB = 10;
const MAX_SIZE_BYTES = MAX_SIZE_MB * 1024 * 1024;

export function ImageDropzone({ onFileSelected, onError }: ImageDropzoneProps) {
  const [isDragOver, setIsDragOver] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const validateAndProcessFile = (file: File) => {
    // Check format
    if (!ALLOWED_TYPES.includes(file.type)) {
      onError(
        `Unsupported file type (${file.type || 'unknown'}). Please upload a JPEG, PNG, or WebP image.`
      );
      return;
    }

    // Check size
    if (file.size > MAX_SIZE_BYTES) {
      onError(
        `File is too large (${(file.size / (1024 * 1024)).toFixed(1)} MB). Maximum allowed size is ${MAX_SIZE_MB} MB.`
      );
      return;
    }

    if (file.size === 0) {
      onError('The selected file appears to be empty (0 bytes). Please choose a valid image.');
      return;
    }

    onFileSelected(file);
  };

  const handleDragOver = (e: React.DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    e.stopPropagation();
    setIsDragOver(true);
  };

  const handleDragLeave = (e: React.DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    e.stopPropagation();
    setIsDragOver(false);
  };

  const handleDrop = (e: React.DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    e.stopPropagation();
    setIsDragOver(false);

    if (e.dataTransfer.files && e.dataTransfer.files.length > 0) {
      const file = e.dataTransfer.files[0];
      validateAndProcessFile(file);
    }
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files.length > 0) {
      const file = e.target.files[0];
      validateAndProcessFile(file);
    }
  };

  const handleBrowseClick = () => {
    fileInputRef.current?.click();
  };

  return (
    <div
      onDragOver={handleDragOver}
      onDragLeave={handleDragLeave}
      onDrop={handleDrop}
      className={`border-2 border-dashed rounded-xl p-8 sm:p-12 text-center transition-all cursor-pointer ${
        isDragOver
          ? 'border-[#243E30] bg-[#EAE8DD]'
          : 'border-[#DCD9CE] bg-[#FAF9F5] hover:border-[#8E9389]'
      }`}
      onClick={handleBrowseClick}
      role="button"
      tabIndex={0}
      onKeyDown={(e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          handleBrowseClick();
        }
      }}
    >
      <input
        ref={fileInputRef}
        type="file"
        accept="image/jpeg,image/png,image/webp"
        onChange={handleFileChange}
        className="hidden"
      />

      <div className="max-w-md mx-auto space-y-3">
        <div className="w-12 h-12 rounded-lg bg-[#EAE8DD] text-[#243E30] mx-auto flex items-center justify-center">
          <UploadCloud className="w-6 h-6" />
        </div>

        <div>
          <h3 className="font-serif text-xl sm:text-2xl text-[#1C3227] tracking-tight">
            {isDragOver ? 'Release to upload leaf specimen' : 'Select or drop a foliar photograph'}
          </h3>
          <p className="text-xs sm:text-sm text-[#575E54] mt-1 leading-relaxed">
            Frame an individual leaf blade with visible tissue margins and characteristic lesions in focus.
          </p>
        </div>

        <div className="pt-2">
          <button
            type="button"
            onClick={(e) => {
              e.stopPropagation();
              handleBrowseClick();
            }}
            className="inline-flex items-center gap-2 px-4 py-2.5 rounded-lg text-xs font-medium text-[#FAF9F5] bg-[#243E30] hover:bg-[#1C3227] transition-colors shadow-xs"
          >
            <ImageIcon className="w-3.5 h-3.5 text-[#C7D6CC]" />
            <span>Select Specimen File</span>
          </button>
        </div>

        <div className="pt-4 border-t border-[#E3E1D7] flex items-center justify-center gap-3 text-xs font-mono text-[#777B73]">
          <span>JPG, PNG, WebP</span>
          <span>&bull;</span>
          <span>Max 10 MB</span>
        </div>
      </div>
    </div>
  );
}
