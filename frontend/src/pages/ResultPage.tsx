import { useEffect, useState } from 'react';
import { useParams, Link, useNavigate } from 'react-router-dom';
import {
  ArrowLeft,
  UploadCloud,
  CheckCircle2,
  AlertTriangle,
  Clock,
  Fingerprint,
  FileText,
  UserCheck,
  ShieldCheck,
  HelpCircle,
} from 'lucide-react';
import { getSubmissionById } from '../services/storageService';
import { getImageBlob } from '../services/imageStorageService';
import { getReviewBySubmissionId } from '../services/reviewService';
import { Submission } from '../types/submission';
import { AdminReview } from '../types/review';
import { DemoBanner } from '../components/common/DemoBanner';
import { ConfidenceGauge } from '../components/common/ConfidenceGauge';

export function ResultPage() {
  const { submissionId } = useParams<{ submissionId: string }>();
  const navigate = useNavigate();

  const [submission, setSubmission] = useState<Submission | null>(null);
  const [review, setReview] = useState<AdminReview | null>(null);
  const [imageUrl, setImageUrl] = useState<string | null>(null);
  const [imageLoading, setImageLoading] = useState(true);
  const [loading, setLoading] = useState(true);

  // Load submission metadata and review
  useEffect(() => {
    if (submissionId) {
      const found = getSubmissionById(submissionId);
      setSubmission(found);
      const foundReview = getReviewBySubmissionId(submissionId);
      setReview(foundReview);
    }
    setLoading(false);
  }, [submissionId]);

  // Load binary image Blob from IndexedDB with cleanup
  useEffect(() => {
    let active = true;
    let objectUrl: string | null = null;

    async function fetchImage() {
      if (!submissionId) {
        setImageLoading(false);
        return;
      }

      setImageLoading(true);
      try {
        const blob = await getImageBlob(submissionId);
        if (!active) return;

        if (blob) {
          objectUrl = URL.createObjectURL(blob);
          setImageUrl(objectUrl);
        } else if (submission?.imageDataUrl) {
          // Fallback to legacy base64 if present
          setImageUrl(submission.imageDataUrl);
        } else {
          setImageUrl(null);
        }
      } catch (err) {
        console.error('Failed to load image blob from IndexedDB:', err);
        if (submission?.imageDataUrl) {
          setImageUrl(submission.imageDataUrl);
        }
      } finally {
        if (active) setImageLoading(false);
      }
    }

    fetchImage();

    return () => {
      active = false;
      if (objectUrl) {
        URL.revokeObjectURL(objectUrl);
      }
    };
  }, [submissionId, submission?.imageDataUrl]);

  if (loading) {
    return (
      <div className="py-20 text-center text-[#575E54] text-xs font-mono">
        Loading specimen record...
      </div>
    );
  }

  // Not Found State
  if (!submission) {
    return (
      <div className="py-16 max-w-xl mx-auto px-4 text-center">
        <div className="w-12 h-12 rounded-xl bg-[#FAF3EA] text-[#865721] flex items-center justify-center mx-auto mb-3 border border-[#EAD9C2]">
          <HelpCircle className="w-6 h-6" />
        </div>
        <h2 className="font-serif text-2xl text-[#1C3227] mb-2">
          Specimen Record Not Found
        </h2>
        <p className="text-xs text-[#575E54] mb-6 leading-relaxed">
          The requested specimen identifier (<code className="font-mono">{submissionId}</code>) could not be located in local storage.
        </p>
        <Link
          to="/detect"
          className="inline-flex items-center gap-2 px-5 py-2.5 rounded-lg text-xs font-medium text-[#FAF9F5] bg-[#243E30] hover:bg-[#1C3227] transition-colors shadow-xs"
        >
          <UploadCloud className="w-4 h-4 text-[#C7D6CC]" />
          <span>Submit a New Specimen</span>
        </Link>
      </div>
    );
  }

  const { prediction, timestamp, fileName, id, status } = submission;
  const isHighConfidence = prediction.confidenceTier === 'high';
  const isReviewed = status === 'reviewed' && !!review;

  return (
    <div className="py-8 sm:py-12 max-w-5xl mx-auto px-4 sm:px-6 w-full">
      {/* Top Back Action & Navigation */}
      <div className="flex items-center justify-between gap-4 mb-6 pb-4 border-b border-[#E3E1D7]">
        <button
          type="button"
          onClick={() => navigate('/detect')}
          className="inline-flex items-center gap-1.5 text-xs font-mono text-[#575E54] hover:text-[#1C3227] transition-colors"
        >
          <ArrowLeft className="w-3.5 h-3.5" />
          <span>Upload Another Specimen</span>
        </button>

        <span className="text-xs text-[#777B73] font-mono">
          SPECIMEN: {id}
        </span>
      </div>

      {/* Demonstration Banner */}
      <DemoBanner
        scenarioName={
          isReviewed
            ? 'Scenario 3: Specialist Review Completed'
            : isHighConfidence
            ? 'Scenario 1: High Confidence Assessment'
            : 'Scenario 2: Low Confidence Triage (Queued for Specialist)'
        }
      />

      {/* Main Grid: Left = Leaf Image & Meta; Right = Diagnosis & Recommendations */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
        {/* Left Column: Image & Metadata (5 cols) */}
        <div className="lg:col-span-5 space-y-5">
          {/* Specimen Photograph Plate */}
          <div className="bg-[#FAF9F5] rounded-xl border border-[#E3E1D7] p-4 shadow-xs">
            <div className="w-full aspect-square rounded-lg overflow-hidden bg-[#ECEAE0] border border-[#DCD9CE] relative flex items-center justify-center">
              {imageLoading ? (
                <div className="text-xs text-[#777B73] font-mono animate-pulse">
                  Loading specimen plate...
                </div>
              ) : imageUrl ? (
                <img
                  src={imageUrl}
                  alt="Analyzed foliar specimen"
                  className="w-full h-full object-cover"
                />
              ) : (
                <div className="text-xs text-[#777B73] font-mono p-4 text-center">
                  Binary data unavailable
                </div>
              )}

              {/* Status Ribbon */}
              <div className="absolute top-2.5 left-2.5">
                <span
                  className={`inline-flex items-center gap-1 px-2.5 py-0.5 rounded text-[11px] font-mono tracking-wide ${
                    isReviewed
                      ? 'bg-[#243E30] text-[#FAF9F5] border border-[#345842]'
                      : isHighConfidence
                      ? 'bg-[#243E30] text-[#FAF9F5] border border-[#345842]'
                      : 'bg-[#865721] text-[#FAF9F5] border border-[#A66E2B]'
                  }`}
                >
                  {isReviewed
                    ? 'Specialist Verified'
                    : isHighConfidence
                    ? 'Conclusive Pattern'
                    : 'Uncertain Signal'}
                </span>
              </div>
            </div>

            {/* Specimen Dossier Metadata */}
            <div className="mt-4 pt-3 border-t border-[#E3E1D7] space-y-2 text-xs font-mono">
              <div className="flex items-center justify-between text-[#6C7167]">
                <span className="flex items-center gap-1.5">
                  <Fingerprint className="w-3.5 h-3.5 text-[#8E9389]" />
                  Specimen ID
                </span>
                <span className="font-semibold text-[#1C3227]">{id}</span>
              </div>

              <div className="flex items-center justify-between text-[#6C7167]">
                <span className="flex items-center gap-1.5">
                  <Clock className="w-3.5 h-3.5 text-[#8E9389]" />
                  Analyzed
                </span>
                <span className="text-[#1C3227]">
                  {new Date(timestamp).toLocaleDateString()}
                </span>
              </div>

              <div className="flex items-center justify-between text-[#6C7167]">
                <span className="flex items-center gap-1.5">
                  <FileText className="w-3.5 h-3.5 text-[#8E9389]" />
                  Source File
                </span>
                <span className="text-[#1C3227] truncate max-w-[150px]" title={fileName}>
                  {fileName}
                </span>
              </div>

              <div className="flex items-center justify-between text-[#6C7167] pt-1">
                <span>Routing Status</span>
                <span
                  className={`px-2 py-0.5 rounded text-[10px] font-mono font-medium ${
                    status === 'reviewed'
                      ? 'bg-[#EDF3EE] text-[#243E30] border border-[#CFDFD3]'
                      : status === 'flagged_for_review'
                      ? 'bg-[#FBF4EB] text-[#865721] border border-[#EAD9C2]'
                      : 'bg-[#EAE8DD] text-[#345842] border border-[#DCD9CE]'
                  }`}
                >
                  {status === 'reviewed'
                    ? 'Reviewed by Specialist'
                    : status === 'flagged_for_review'
                    ? 'Queued for Triage'
                    : 'Classification Complete'}
                </span>
              </div>
            </div>
          </div>

          {/* Quick Actions */}
          <div className="p-4 rounded-xl bg-[#FAF9F5] border border-[#E3E1D7] flex flex-col gap-2">
            <Link
              to="/detect"
              className="w-full inline-flex items-center justify-center gap-2 px-4 py-2.5 rounded-lg text-xs font-medium text-[#FAF9F5] bg-[#243E30] hover:bg-[#1C3227] transition-colors shadow-xs"
            >
              <UploadCloud className="w-3.5 h-3.5 text-[#C7D6CC]" />
              <span>Analyze Another Specimen</span>
            </Link>

            <Link
              to="/"
              className="w-full inline-flex items-center justify-center px-4 py-2 rounded-lg text-xs font-medium text-[#575E54] hover:text-[#1C3227] bg-[#FAF9F5] hover:bg-[#EAE8DD] border border-[#E3E1D7] transition-colors"
            >
              <span>Return to Overview</span>
            </Link>

            {status === 'flagged_for_review' && (
              <Link
                to="/admin"
                className="w-full inline-flex items-center justify-center gap-1.5 px-4 py-2 rounded-lg text-xs font-mono font-medium text-[#865721] hover:text-[#5C3911] bg-[#FBF4EB] border border-[#EAD9C2] transition-colors"
              >
                <span>Inspect in Specialist Queue &rarr;</span>
              </Link>
            )}
          </div>
        </div>

        {/* Right Column: Diagnostic & Guidance Details (7 cols) */}
        <div className="lg:col-span-7 space-y-6">

          {/* SPECIALIST ASSESSMENT CARD (Rendered when reviewed by human specialist) */}
          {isReviewed && review && (
            <div className="bg-[#243E30] text-[#FAF9F5] rounded-xl p-6 sm:p-7 shadow-xs border border-[#345842]">
              <div className="flex items-center justify-between gap-3 flex-wrap mb-4 pb-3 border-b border-[#3C634F]">
                <div className="flex items-center gap-2">
                  <div className="w-8 h-8 rounded-lg bg-[#345842] flex items-center justify-center text-[#C7D6CC]">
                    <UserCheck className="w-4 h-4" />
                  </div>
                  <div>
                    <span className="text-[10px] font-mono tracking-wider uppercase text-[#9FB9A7] block">
                      Human Review Completed
                    </span>
                    <h3 className="text-sm font-serif text-[#FAF9F5]">
                      Agricultural Specialist Assessment
                    </h3>
                  </div>
                </div>

                <span
                  className={`inline-flex items-center gap-1 px-2.5 py-0.5 rounded text-[11px] font-mono ${
                    review.outcome === 'DISEASE_IDENTIFIED'
                      ? 'bg-[#345842] text-[#FAF9F5] border border-[#487256]'
                      : 'bg-[#865721] text-[#FAF9F5] border border-[#A66E2B]'
                  }`}
                >
                  {review.outcome === 'DISEASE_IDENTIFIED'
                    ? 'Pathogen Confirmed'
                    : 'Sample Inconclusive'}
                </span>
              </div>

              {/* Assessment Body */}
              {review.outcome === 'DISEASE_IDENTIFIED' ? (
                <div className="space-y-2">
                  <span className="text-xs text-[#9FB9A7] font-mono block">Verified Condition</span>
                  <p className="font-serif text-2xl text-[#FAF9F5]">
                    {review.assessedDiseaseName}
                  </p>
                  <p className="text-xs text-[#C7D6CC] leading-relaxed pt-1">
                    An agricultural extension specialist inspected this foliar specimen and confirmed the diagnosis of <strong>{review.assessedDiseaseName}</strong>. This clinical evaluation supersedes provisional automated model estimates.
                  </p>
                </div>
              ) : (
                <div className="space-y-2">
                  <span className="text-xs text-[#EAD9C2] font-mono block">Diagnostic Determination</span>
                  <p className="font-serif text-2xl text-[#FAF9F5]">
                    Inconclusive / Sample Insufficient
                  </p>
                  <p className="text-xs text-[#C7D6CC] leading-relaxed pt-1">
                    An agricultural specialist examined this specimen and determined that visible symptom patterns are ambiguous, degraded, or obscured. A fresh close-up photograph under diffuse daylight or on-site extension verification is advised.
                  </p>
                </div>
              )}

              {/* Specialist Attribution Footer (Strictly excludes private admin notes) */}
              <div className="mt-5 pt-3 border-t border-[#3C634F] flex flex-wrap items-center justify-between gap-2 text-xs font-mono text-[#9FB9A7]">
                <span>Reviewed by: <strong className="text-[#FAF9F5] font-sans font-medium">{review.reviewerIdentity}</strong></span>
                <span>{new Date(review.reviewTimestamp).toLocaleString()}</span>
              </div>
            </div>
          )}

          {/* Model Diagnostic Output Card */}
          <div className="bg-[#FAF9F5] rounded-xl border border-[#E3E1D7] p-6 sm:p-7 shadow-xs">
            <div className="flex items-start justify-between gap-4 flex-wrap mb-4 pb-3 border-b border-[#E3E1D7]">
              <div>
                <span className="text-[10px] font-mono uppercase tracking-wider text-[#777B73] block mb-1">
                  {isReviewed ? 'Original Model Classification (Automated)' : 'Model Diagnostic Assessment'}
                </span>
                <h2 className="font-serif text-3xl sm:text-4xl text-[#1C3227] tracking-tight">
                  {prediction.diseaseName}
                </h2>
                {prediction.scientificName && (
                  <p className="text-xs text-[#575E54] italic mt-0.5">
                    Pathogen: {prediction.scientificName}
                  </p>
                )}
              </div>

              <span
                className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded text-xs font-mono ${
                  isHighConfidence
                    ? 'bg-[#EDF3EE] text-[#243E30] border border-[#CFDFD3]'
                    : 'bg-[#FBF4EB] text-[#865721] border border-[#EAD9C2]'
                }`}
              >
                {isHighConfidence ? (
                  <CheckCircle2 className="w-3.5 h-3.5 text-[#345842]" />
                ) : (
                  <AlertTriangle className="w-3.5 h-3.5 text-[#865721]" />
                )}
                {isHighConfidence ? 'Conclusive Visual Signal' : 'Low Confidence Signal'}
              </span>
            </div>

            {/* Model Confidence Metric Gauge */}
            <ConfidenceGauge
              confidence={prediction.confidence}
              tier={prediction.confidenceTier}
              explanation={prediction.confidenceExplanation}
            />

            {/* Disease Pathology Overview */}
            <div className="mt-5 pt-4 border-t border-[#E3E1D7]">
              <h3 className="text-xs font-mono font-semibold uppercase tracking-wider text-[#1C3227] mb-1.5">
                Pathology Overview
              </h3>
              <p className="text-xs sm:text-sm text-[#575E54] leading-relaxed">
                {prediction.description}
              </p>
            </div>
          </div>

          {/* Observable Characteristics & Field Indicators */}
          <div className="bg-[#FAF9F5] rounded-xl border border-[#E3E1D7] p-6 sm:p-7 shadow-xs">
            <h3 className="text-xs font-mono font-semibold uppercase tracking-wider text-[#1C3227] mb-3">
              Observable Foliar Indicators
            </h3>
            <ul className="space-y-2">
              {prediction.symptoms.map((symptom, idx) => (
                <li
                  key={idx}
                  className="flex items-start gap-2 text-xs sm:text-sm text-[#575E54] leading-relaxed"
                >
                  <span className="w-1.5 h-1.5 rounded-full bg-[#78664E] mt-2 flex-shrink-0" />
                  <span>{symptom}</span>
                </li>
              ))}
            </ul>
          </div>

          {/* Actionable Recommendations (Tailored to Confidence Tier) */}
          {isHighConfidence ? (
            <div className="bg-[#FAF9F5] rounded-xl border border-[#CFDFD3] p-6 sm:p-7 shadow-xs">
              <div className="flex items-center gap-2 mb-2 pb-2 border-b border-[#CFDFD3]">
                <ShieldCheck className="w-4 h-4 text-[#243E30]" />
                <h3 className="text-xs font-mono font-semibold uppercase tracking-wider text-[#1C3227]">
                  Illustrative Cultural Advisory
                </h3>
              </div>
              <p className="text-xs text-[#575E54] mb-3 leading-relaxed">
                Management practices documented for foliar rice blast management under standard agronomic conditions:
              </p>
              <ul className="space-y-2 mb-4">
                {prediction.recommendations.map((rec, idx) => (
                  <li
                    key={idx}
                    className="flex items-start gap-2 text-xs sm:text-sm text-[#1C3227] leading-relaxed"
                  >
                    <CheckCircle2 className="w-3.5 h-3.5 text-[#345842] flex-shrink-0 mt-0.5" />
                    <span>{rec}</span>
                  </li>
                ))}
              </ul>
              <div className="p-3 bg-[#EAE8DD]/70 rounded-lg border border-[#DCD9CE] text-[11px] text-[#575E54] leading-normal">
                <strong>Advisory Note:</strong> Illustrated guidelines serve educational decision support. Consult local agricultural extension officers before initiating chemical fungicide applications.
              </div>
            </div>
          ) : (
            <div className="bg-[#FAF9F5] rounded-xl border border-[#EAD9C2] p-6 sm:p-7 shadow-xs">
              <div className="flex items-center gap-2 mb-2 pb-2 border-b border-[#EAD9C2]">
                <AlertTriangle className="w-4 h-4 text-[#865721]" />
                <h3 className="text-xs font-mono font-semibold uppercase tracking-wider text-[#865721]">
                  Triage Protocol &amp; Uncertainty Guidance
                </h3>
              </div>
              <p className="text-xs text-[#575E54] mb-3 leading-relaxed">
                Because this model confidence ({Math.round(prediction.confidence * 100)}%) falls beneath clinical certainty thresholds, chemical treatment recommendations are withheld to prevent misdiagnosis.
              </p>
              <ul className="space-y-2 mb-4">
                {prediction.recommendations.map((rec, idx) => (
                  <li
                    key={idx}
                    className="flex items-start gap-2 text-xs sm:text-sm text-[#865721] leading-relaxed"
                  >
                    <span className="w-1.5 h-1.5 rounded-full bg-[#865721] mt-2 flex-shrink-0" />
                    <span>{rec}</span>
                  </li>
                ))}
              </ul>

              {/* Triage Status Notice */}
              <div className="p-3 bg-[#FBF4EB] rounded-lg border border-[#EAD9C2] text-xs text-[#865721] space-y-1">
                <span className="font-semibold block">
                  {isReviewed ? 'Specialist Determination Recorded' : 'Queued for Agricultural Specialist Inspection'}
                </span>
                <p className="text-[11px] text-[#865721]/90 leading-relaxed">
                  {isReviewed
                    ? 'An agricultural extension specialist has completed a clinical assessment of this specimen. See the verified determination above.'
                    : `This specimen (${id}) has been entered into the specialist triage queue. Specialists will inspect high-resolution tissue margins in the administrative review portal.`}
                </p>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}