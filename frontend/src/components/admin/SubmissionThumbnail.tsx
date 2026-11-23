import { useState, useEffect } from 'react';
import { ImageIcon } from 'lucide-react';
import { getImageBlob } from '../../services/imageStorageService';

interface SubmissionThumbnailProps {
  submissionId: string;
  altText: string;
}

export function SubmissionThumbnail({ submissionId, altText }: SubmissionThumbnailProps) {
  const [objectUrl, setObjectUrl] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let active = true;
    let createdUrl: string | null = null;

    setLoading(true);
    getImageBlob(submissionId)
      .then((blob) => {
        if (!active) return;
        if (blob) {
          createdUrl = URL.createObjectURL(blob);
          setObjectUrl(createdUrl);
        } else {
          setObjectUrl(null);
        }
      })
      .catch((err) => {
        console.warn(`Could not load thumbnail for submission ${submissionId}:`, err);
        if (active) setObjectUrl(null);
      })
      .finally(() => {
        if (active) setLoading(false);
      });

    return () => {
      active = false;
      if (createdUrl) {
        URL.revokeObjectURL(createdUrl);
      }
    };
  }, [submissionId]);

  if (loading) {
    return (
      <div className="w-12 h-12 rounded-lg bg-[#ECEAE0] animate-pulse flex items-center justify-center flex-shrink-0">
        <ImageIcon className="w-4 h-4 text-[#8E9389]" />
      </div>
    );
  }

  if (!objectUrl) {
    return (
      <div className="w-12 h-12 rounded-lg bg-[#FAF9F5] border border-[#DCD9CE] flex items-center justify-center flex-shrink-0 text-[#8E9389]">
        <ImageIcon className="w-4 h-4" />
      </div>
    );
  }

  return (
    <div className="w-12 h-12 rounded-lg overflow-hidden bg-[#ECEAE0] border border-[#DCD9CE] flex-shrink-0">
      <img
        src={objectUrl}
        alt={altText}
        className="w-full h-full object-cover"
        loading="lazy"
      />
    </div>
  );
}
