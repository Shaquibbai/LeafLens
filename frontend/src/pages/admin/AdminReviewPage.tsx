import React, { useState, useEffect } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import {
  ArrowLeft,
  CheckCircle2,
  AlertTriangle,
  FileText,
  Lock,
  ExternalLink,
  HelpCircle,
  Stethoscope,
} from 'lucide-react';
import { getSubmissionById } from '../../services/storageService';
import { getImageBlob } from '../../services/imageStorageService';
import { getReviewBySubmissionId, createAdminReview } from '../../services/reviewService';
import { getCurrentAdminUser } from '../../services/authService';
import { Submission } from '../../types/submission';
import { ReviewOutcome } from '../../types/review';
import { VERIFIED_DISEASE_OPTIONS } from '../../data/mockDiseases';

export function AdminReviewPage() {
  const { submissionId } = useParams<{ submissionId: string }>();
  const navigate = useNavigate();
  const adminUser = getCurrentAdminUser();

  const [submission, setSubmission] = useState<Submission | null>(null);
  const [imageObjectUrl, setImageObjectUrl] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  // Form state
  const [outcome, setOutcome] = useState<ReviewOutcome>('DISEASE_IDENTIFIED');
  const [selectedDiseaseId, setSelectedDiseaseId] = useState<string>('rice_blast');
  const [adminNotes, setAdminNotes] = useState<string>('');
  const [formError, setFormError] = useState<string | null>(null);
  const [successSaved, setSuccessSaved] = useState(false);

  useEffect(() => {
    let active = true;
    let createdUrl: string | null = null;

    if (!submissionId) {
      setLoading(false);
      return;
    }

    const sub = getSubmissionById(submissionId);
    setSubmission(sub);

    if (sub) {
      // Check if a review already exists
      const existingReview = getReviewBySubmissionId(sub.id);
      if (existingReview) {
        setOutcome(existingReview.outcome);
        setSelectedDiseaseId(existingReview.assessedDiseaseId || 'rice_blast');
        setAdminNotes(existingReview.adminNotes);
      } else {
        // Pre-fill notes based on context
        setAdminNotes(
          sub.prediction.confidenceTier === 'low'
            ? 'Examined foliar margins and necrotic discoloration. Visual symptoms indicate...'
            : 'Foliar pathology matches characteristic spindle lesions.'
        );
      }

      // Load image Blob from IndexedDB
      getImageBlob(sub.id)
        .then((blob) => {
          if (!active) return;
          if (blob) {
            createdUrl = URL.createObjectURL(blob);
            setImageObjectUrl(createdUrl);
          }
        })
        .catch((err) => {
          console.error('Failed to load image Blob from IndexedDB:', err);
        })
        .finally(() => {
          if (active) setLoading(false);
        });
    } else {
      setLoading(false);
    }

    return () => {
      active = false;
      if (createdUrl) {
        URL.revokeObjectURL(createdUrl);
      }
    };
  }, [submissionId]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!submission) return;

    setFormError(null);

    let assessedDiseaseId: string | null = null;
    let assessedDiseaseName: string | null = null;

    if (outcome === 'DISEASE_IDENTIFIED') {
      if (!selectedDiseaseId) {
        setFormError('Please select an identified rice disease from the pathology list.');
        return;
      }
      const match = VERIFIED_DISEASE_OPTIONS.find((d) => d.id === selectedDiseaseId);
      assessedDiseaseId = selectedDiseaseId;
      assessedDiseaseName = match ? `${match.name} (${match.scientificName})` : selectedDiseaseId;
    }

    // Persist independent review record
    createAdminReview({
      submissionId: submission.id,
      outcome,
      assessedDiseaseId,
      assessedDiseaseName,
      adminNotes,
      reviewerIdentity: `${adminUser?.displayName || 'Dr. S. Rahman'} (${adminUser?.role || 'Agricultural Extension Specialist'})`,
    });

    setSuccessSaved(true);
    setTimeout(() => {
      navigate('/admin');
    }, 1200);
  };

  if (loading) {
    return (
      <div className="py-20 text-center text-[#575E54] text-xs font-mono">
        Loading case record and image blob from IndexedDB...
      </div>
    );
  }

  if (!submission) {
    return (
      <div className="py-16 max-w-xl mx-auto px-4 text-center">
        <HelpCircle className="w-10 h-10 text-[#865721] mx-auto mb-3" />
        <h2 className="font-serif text-2xl text-[#1C3227] mb-2">Specimen Record Not Found</h2>
        <p className="text-xs text-[#575E54] mb-5 font-mono">
          Submission identifier {submissionId} does not exist in local storage.
        </p>
        <Link
          to="/admin"
          className="inline-flex items-center gap-2 px-4 py-2 rounded-lg text-xs font-medium text-[#FAF9F5] bg-[#243E30]"
        >
          Return to Queue
        </Link>
      </div>
    );
  }

  const { prediction } = submission;
  const isPending = submission.status === 'flagged_for_review';

  return (
    <div className="py-8 sm:py-12 max-w-5xl mx-auto px-4 sm:px-6 w-full">
      {/* Breadcrumb Navigation */}
      <div className="flex items-center justify-between gap-4 mb-6 pb-4 border-b border-[#E3E1D7]">
        <button
          type="button"
          onClick={() => navigate('/admin')}
          className="inline-flex items-center gap-1.5 text-xs font-mono text-[#575E54] hover:text-[#1C3227] transition-colors"
        >
          <ArrowLeft className="w-3.5 h-3.5" />
          <span>Return to Review Queue</span>
        </button>

        <Link
          to={`/result/${submission.id}`}
          target="_blank"
          rel="noopener noreferrer"
          className="inline-flex items-center gap-1.5 text-xs font-mono text-[#6C7167] hover:text-[#1C3227]"
        >
          <span>Open Public Result Record</span>
          <ExternalLink className="w-3.5 h-3.5" />
        </Link>
      </div>

      {/* Case Header */}
      <div className="bg-[#FAF9F5] rounded-xl border border-[#E3E1D7] p-5 shadow-xs mb-8">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
          <div className="space-y-1">
            <div className="flex items-center gap-2">
              <span className="font-mono text-xs font-semibold text-[#1C3227] bg-[#EAE8DD] px-2 py-0.5 rounded border border-[#DCD9CE]">
                SPECIMEN: {submission.id}
              </span>
              <span
                className={`text-[11px] font-mono font-medium px-2 py-0.5 rounded ${
                  isPending
                    ? 'bg-[#FBF4EB] text-[#865721] border border-[#EAD9C2]'
                    : 'bg-[#EDF3EE] text-[#243E30] border border-[#CFDFD3]'
                }`}
              >
                {isPending ? 'Pending Specialist Assessment' : 'Case Assessment Recorded'}
              </span>
            </div>
            <h1 className="font-serif text-2xl sm:text-3xl text-[#1C3227] tracking-tight">
              Clinical Specimen Assessment
            </h1>
          </div>

          <span className="text-xs font-mono text-[#777B73]">
            Intake: {new Date(submission.timestamp).toLocaleString()}
          </span>
        </div>
      </div>

      {/* Main Split Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
        {/* Left Column: Original Submission & Model Output (5 cols) */}
        <div className="lg:col-span-5 space-y-6">
          {/* Image Frame */}
          <div className="bg-[#FAF9F5] rounded-xl border border-[#E3E1D7] p-4 shadow-xs">
            <span className="text-[10px] font-mono uppercase tracking-wider text-[#777B73] block mb-2">
              Original Specimen Photograph (IndexedDB Binary)
            </span>
            <div className="w-full aspect-square rounded-lg overflow-hidden bg-[#ECEAE0] border border-[#DCD9CE] relative">
              {imageObjectUrl ? (
                <img
                  src={imageObjectUrl}
                  alt="Original rice leaf specimen"
                  className="w-full h-full object-cover"
                />
              ) : (
                <div className="w-full h-full flex items-center justify-center text-xs text-[#777B73] font-mono">
                  Specimen Blob unavailable
                </div>
              )}
            </div>
            <div className="mt-2.5 text-xs font-mono text-[#777B73] flex items-center justify-between">
              <span className="truncate max-w-[170px]" title={submission.fileName}>
                File: {submission.fileName}
              </span>
              <span>{(submission.fileSize / 1024).toFixed(1)} KB</span>
            </div>
          </div>

          {/* Original Automated Model Prediction Card */}
          <div className="bg-[#FAF9F5] rounded-xl border border-[#E3E1D7] p-5 shadow-xs space-y-2.5">
            <span className="text-[10px] font-mono uppercase tracking-wider text-[#777B73] block">
              Automated Model Classification (Unmodified)
            </span>
            <h3 className="font-serif text-xl text-[#1C3227]">
              {prediction.diseaseName}
            </h3>
            <div className="flex items-center gap-2 font-mono text-xs">
              <span
                className={`px-2 py-0.5 rounded font-medium ${
                  prediction.confidenceTier === 'high'
                    ? 'bg-[#EDF3EE] text-[#243E30] border border-[#CFDFD3]'
                    : 'bg-[#FBF4EB] text-[#865721] border border-[#EAD9C2]'
                }`}
              >
                Model Confidence: {Math.round(prediction.confidence * 100)}%
              </span>
              <span className="text-[#777B73]">
                Tier: {prediction.confidenceTier.toUpperCase()}
              </span>
            </div>
            <p className="text-xs text-[#575E54] leading-relaxed bg-[#EAE8DD] p-3 rounded-lg border border-[#DCD9CE]">
              {prediction.confidenceExplanation}
            </p>
            <p className="text-[10px] text-[#777B73] leading-normal font-mono">
              * LeafLens architecture stores human specialist determinations independently without modifying raw ML model outputs.
            </p>
          </div>
        </div>

        {/* Right Column: Independent Assessment Form (7 cols) */}
        <div className="lg:col-span-7">
          <form
            onSubmit={handleSubmit}
            className="bg-[#FAF9F5] rounded-xl border border-[#E3E1D7] p-6 sm:p-7 shadow-xs space-y-6"
          >
            <div>
              <div className="flex items-center gap-2 mb-1">
                <Stethoscope className="w-4 h-4 text-[#243E30]" />
                <h2 className="font-serif text-xl text-[#1C3227]">
                  Specialist Clinical Finding
                </h2>
              </div>
              <p className="text-xs text-[#575E54]">
                Record your verified finding after examining foliar lesion patterns and necrotic borders.
              </p>
            </div>

            {/* Assessment Outcome Radio Selector */}
            <div className="space-y-3">
              <label className="block text-xs font-mono uppercase tracking-wider text-[#1C3227] font-semibold">
                Clinical Determination
              </label>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                {/* Option 1: Disease Identified */}
                <button
                  type="button"
                  onClick={() => setOutcome('DISEASE_IDENTIFIED')}
                  className={`p-3.5 rounded-lg border text-left transition-all ${
                    outcome === 'DISEASE_IDENTIFIED'
                      ? 'border-[#243E30] bg-[#FFFFFF] shadow-xs'
                      : 'border-[#E3E1D7] bg-[#FAF9F5] hover:border-[#BCC0B9]'
                  }`}
                >
                  <div className="flex items-center justify-between mb-1">
                    <span className="text-xs font-semibold text-[#1C3227]">
                      Disease Confirmed
                    </span>
                    <CheckCircle2
                      className={`w-3.5 h-3.5 ${
                        outcome === 'DISEASE_IDENTIFIED' ? 'text-[#243E30]' : 'text-[#BCC0B9]'
                      }`}
                    />
                  </div>
                  <p className="text-[11px] text-[#6C7167] leading-relaxed">
                    Specific foliar pathogen identified with clinical certainty.
                  </p>
                </button>

                {/* Option 2: Inconclusive */}
                <button
                  type="button"
                  onClick={() => setOutcome('INCONCLUSIVE')}
                  className={`p-3.5 rounded-lg border text-left transition-all ${
                    outcome === 'INCONCLUSIVE'
                      ? 'border-[#865721] bg-[#FFFFFF] shadow-xs'
                      : 'border-[#E3E1D7] bg-[#FAF9F5] hover:border-[#BCC0B9]'
                  }`}
                >
                  <div className="flex items-center justify-between mb-1">
                    <span className="text-xs font-semibold text-[#1C3227]">
                      Inconclusive / Retake
                    </span>
                    <AlertTriangle
                      className={`w-3.5 h-3.5 ${
                        outcome === 'INCONCLUSIVE' ? 'text-[#865721]' : 'text-[#BCC0B9]'
                      }`}
                    />
                  </div>
                  <p className="text-[11px] text-[#6C7167] leading-relaxed">
                    Specimen requires fresh field photograph or tissue analysis.
                  </p>
                </button>
              </div>
            </div>

            {/* Disease Selector (Only visible if Disease Confirmed) */}
            {outcome === 'DISEASE_IDENTIFIED' && (
              <div className="p-4 rounded-lg bg-[#EAE8DD] border border-[#DCD9CE] space-y-1.5">
                <label className="block text-xs font-mono font-semibold text-[#1C3227]">
                  Identified Rice Condition
                </label>
                <select
                  value={selectedDiseaseId}
                  onChange={(e) => setSelectedDiseaseId(e.target.value)}
                  className="w-full px-3 py-2 rounded-lg border border-[#DCD9CE] text-xs text-[#1C3227] bg-white focus:outline-none focus:ring-1 focus:ring-[#243E30] focus:border-[#243E30] font-sans"
                  required
                >
                  {VERIFIED_DISEASE_OPTIONS.map((opt) => (
                    <option key={opt.id} value={opt.id}>
                      {opt.name} ({opt.scientificName})
                    </option>
                  ))}
                </select>
                <p className="text-[11px] text-[#6C7167] font-mono pt-0.5">
                  This diagnosis will be displayed on the public diagnostic specimen record.
                </p>
              </div>
            )}

            {/* Administrator Notes (Strictly Private) */}
            <div className="space-y-1.5">
              <div className="flex items-center justify-between">
                <label className="text-xs font-mono font-semibold text-[#1C3227] flex items-center gap-1.5">
                  <FileText className="w-3.5 h-3.5 text-[#777B73]" />
                  Administrator Diagnostic Notes
                </label>
                <span className="text-[10px] font-mono text-[#865721] bg-[#FBF4EB] px-2 py-0.5 rounded border border-[#EAD9C2] flex items-center gap-1">
                  <Lock className="w-3 h-3" />
                  Private Notes
                </span>
              </div>

              <textarea
                rows={4}
                value={adminNotes}
                onChange={(e) => setAdminNotes(e.target.value)}
                placeholder="Enter internal specialist diagnosis notes, observable conidia patterns, field recommendations, or clinical rationale..."
                className="w-full px-3.5 py-2.5 rounded-lg border border-[#DCD9CE] text-xs text-[#1C3227] bg-[#FFFFFF] focus:outline-none focus:ring-1 focus:ring-[#243E30] focus:border-[#243E30] transition-all leading-relaxed"
              />
              <p className="text-[11px] text-[#777B73] font-mono flex items-center gap-1">
                <Lock className="w-3 h-3 text-[#8E9389]" />
                <span>
                  <strong>Privacy Rule:</strong> Notes remain strictly private to the administrative portal and are never exposed on public pages.
                </span>
              </p>
            </div>

            {/* Reviewer Signature Card */}
            <div className="p-3 rounded-lg bg-[#EAE8DD] border border-[#DCD9CE] flex items-center justify-between text-xs font-mono text-[#575E54]">
              <span>
                Reviewer: <strong className="text-[#1C3227] font-sans font-medium">{adminUser?.displayName || 'Dr. S. Rahman'}</strong>
              </span>
              <span>
                {new Date().toLocaleDateString()}
              </span>
            </div>

            {/* Form Error Alert */}
            {formError && (
              <div className="p-3 rounded-lg bg-[#FAF0EE] border border-[#ECCEC8] text-[#8E3526] text-xs flex items-center gap-2">
                <AlertTriangle className="w-4 h-4 text-[#8E3526] flex-shrink-0" />
                <span>{formError}</span>
              </div>
            )}

            {/* Success Confirmation Toast */}
            {successSaved && (
              <div className="p-3 rounded-lg bg-[#EDF3EE] border border-[#CFDFD3] text-[#243E30] text-xs flex items-center gap-2">
                <CheckCircle2 className="w-4 h-4 text-[#345842] flex-shrink-0" />
                <span>Assessment saved. Returning to review queue...</span>
              </div>
            )}

            {/* Submit Action */}
            <div className="pt-2 flex items-center justify-end gap-3 border-t border-[#E3E1D7]">
              <button
                type="button"
                onClick={() => navigate('/admin')}
                className="px-3.5 py-2 rounded-lg text-xs font-mono text-[#575E54] hover:text-[#1C3227]"
              >
                Cancel
              </button>

              <button
                type="submit"
                disabled={successSaved}
                className="inline-flex items-center gap-2 px-5 py-2.5 rounded-lg text-xs font-medium text-[#FAF9F5] bg-[#243E30] hover:bg-[#1C3227] transition-colors shadow-xs disabled:opacity-50"
              >
                <CheckCircle2 className="w-3.5 h-3.5 text-[#C7D6CC]" />
                <span>Save Specialist Assessment</span>
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  );
}