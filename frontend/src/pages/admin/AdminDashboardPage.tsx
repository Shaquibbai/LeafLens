import { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import {
  ShieldCheck,
  LogOut,
  AlertTriangle,
  CheckCircle2,
  Inbox,
  Filter,
  Eye,
  RotateCcw,
  Sparkles,
  ExternalLink,
} from 'lucide-react';
import { getAllSubmissions, clearAllSubmissions, migrateLegacySubmissions } from '../../services/storageService';
import { clearAllReviews } from '../../services/reviewService';
import { getCurrentAdminUser, logoutAdministrator } from '../../services/authService';
import { Submission, SubmissionStatus } from '../../types/submission';
import { SubmissionThumbnail } from '../../components/admin/SubmissionThumbnail';

export function AdminDashboardPage() {
  const navigate = useNavigate();
  const adminUser = getCurrentAdminUser();

  const [submissions, setSubmissions] = useState<Submission[]>([]);
  const [filter, setFilter] = useState<'all' | 'pending' | 'reviewed'>('pending');
  const [resetModalOpen, setResetModalOpen] = useState(false);

  const refreshData = () => {
    migrateLegacySubmissions().then(() => {
      setSubmissions(getAllSubmissions());
    });
  };

  useEffect(() => {
    refreshData();
  }, []);

  const handleLogout = () => {
    logoutAdministrator();
    navigate('/admin/login');
  };

  const handleResetData = () => {
    clearAllSubmissions();
    clearAllReviews();
    setSubmissions([]);
    setResetModalOpen(false);
  };

  // Metrics
  const totalCount = submissions.length;
  const pendingCount = submissions.filter((s) => s.status === 'flagged_for_review').length;
  const reviewedCount = submissions.filter((s) => s.status === 'reviewed').length;
  const completedAutoCount = submissions.filter((s) => s.status === 'completed').length;

  // Filtered List
  const filteredSubmissions = submissions.filter((s) => {
    if (filter === 'pending') return s.status === 'flagged_for_review';
    if (filter === 'reviewed') return s.status === 'reviewed';
    return true;
  });

  return (
    <div className="py-8 sm:py-12 max-w-6xl mx-auto px-4 sm:px-6 w-full">
      {/* Top Admin Header Bar */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-6 border-b border-[#E3E1D7] mb-8">
        <div className="space-y-1">
          <div className="flex items-center gap-2">
            <span className="inline-flex items-center gap-1.5 px-2 py-0.5 rounded text-[10px] font-mono font-medium bg-[#EAE8DD] text-[#243E30] border border-[#DCD9CE]">
              <ShieldCheck className="w-3.5 h-3.5 text-[#345842]" />
              Specialist Console
            </span>
            <span className="text-[11px] text-[#777B73] font-mono">Evaluation Workspace</span>
          </div>
          <h1 className="font-serif text-2xl sm:text-3xl text-[#1C3227] tracking-tight">
            Specimen Review Queue
          </h1>
          <p className="text-xs text-[#575E54]">
            Reviewer: <strong className="text-[#1C3227] font-medium">{adminUser?.displayName || 'Dr. S. Rahman'}</strong> ({adminUser?.role || 'Agricultural Extension Specialist'})
          </p>
        </div>

        <div className="flex items-center gap-2.5">
          <button
            type="button"
            onClick={() => setResetModalOpen(true)}
            className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-mono text-[#575E54] hover:text-[#1C3227] hover:bg-[#EAE8DD] border border-[#E3E1D7] transition-colors"
            title="Reset demonstration data"
          >
            <RotateCcw className="w-3 h-3 text-[#777B73]" />
            <span>Reset Demo Data</span>
          </button>

          <button
            type="button"
            onClick={handleLogout}
            className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-mono text-[#8E3526] hover:text-[#5E2218] hover:bg-[#FAF0EE] border border-[#ECCEC8] transition-colors"
          >
            <LogOut className="w-3 h-3" />
            <span>Sign Out</span>
          </button>
        </div>
      </div>

      {/* Practical Telemetry Bar (Instead of giant decorative cards) */}
      <div className="bg-[#FAF9F5] rounded-xl border border-[#E3E1D7] p-4 sm:p-5 mb-8 shadow-xs">
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 divide-y sm:divide-y-0 sm:divide-x divide-[#E3E1D7]">
          {/* Pending Triage Metric */}
          <button
            type="button"
            onClick={() => setFilter('pending')}
            className={`pt-2 sm:pt-0 sm:px-4 first:pt-0 first:pl-0 text-left transition-colors ${
              filter === 'pending' ? 'opacity-100' : 'opacity-75 hover:opacity-100'
            }`}
          >
            <span className="text-[10px] font-mono uppercase tracking-wider text-[#865721] block">
              Pending Triage
            </span>
            <div className="text-2xl font-serif text-[#1C3227] mt-0.5">{pendingCount}</div>
            <span className="text-[11px] text-[#777B73]">Awaiting specialist evaluation</span>
          </button>

          {/* Reviewed Metric */}
          <button
            type="button"
            onClick={() => setFilter('reviewed')}
            className={`pt-2 sm:pt-0 sm:px-4 text-left transition-colors ${
              filter === 'reviewed' ? 'opacity-100' : 'opacity-75 hover:opacity-100'
            }`}
          >
            <span className="text-[10px] font-mono uppercase tracking-wider text-[#345842] block">
              Specialist Assessed
            </span>
            <div className="text-2xl font-serif text-[#1C3227] mt-0.5">{reviewedCount}</div>
            <span className="text-[11px] text-[#777B73]">Verified case determinations</span>
          </button>

          {/* Automated Conclusive Metric */}
          <button
            type="button"
            onClick={() => setFilter('all')}
            className="pt-2 sm:pt-0 sm:px-4 text-left opacity-75 hover:opacity-100 transition-colors"
          >
            <span className="text-[10px] font-mono uppercase tracking-wider text-[#575E54] block">
              Automated Conclusive
            </span>
            <div className="text-2xl font-serif text-[#1C3227] mt-0.5">{completedAutoCount}</div>
            <span className="text-[11px] text-[#777B73]">High-confidence classifications</span>
          </button>

          {/* Total Submissions Metric */}
          <button
            type="button"
            onClick={() => setFilter('all')}
            className={`pt-2 sm:pt-0 sm:px-4 text-left transition-colors ${
              filter === 'all' ? 'opacity-100' : 'opacity-75 hover:opacity-100'
            }`}
          >
            <span className="text-[10px] font-mono uppercase tracking-wider text-[#575E54] block">
              Total Archive
            </span>
            <div className="text-2xl font-serif text-[#1C3227] mt-0.5">{totalCount}</div>
            <span className="text-[11px] text-[#777B73]">All recorded specimens</span>
          </button>
        </div>
      </div>

      {/* Filter Segment Controls */}
      <div className="flex items-center justify-between flex-wrap gap-3 mb-4">
        <div className="inline-flex p-1 rounded-lg bg-[#EAE8DD] border border-[#DCD9CE]">
          <button
            type="button"
            onClick={() => setFilter('pending')}
            className={`px-3 py-1 rounded text-xs font-mono transition-all ${
              filter === 'pending'
                ? 'bg-[#FFFFFF] text-[#1C3227] font-semibold shadow-xs'
                : 'text-[#6C7167] hover:text-[#1C3227]'
            }`}
          >
            Pending Review ({pendingCount})
          </button>

          <button
            type="button"
            onClick={() => setFilter('reviewed')}
            className={`px-3 py-1 rounded text-xs font-mono transition-all ${
              filter === 'reviewed'
                ? 'bg-[#FFFFFF] text-[#1C3227] font-semibold shadow-xs'
                : 'text-[#6C7167] hover:text-[#1C3227]'
            }`}
          >
            Reviewed ({reviewedCount})
          </button>

          <button
            type="button"
            onClick={() => setFilter('all')}
            className={`px-3 py-1 rounded text-xs font-mono transition-all ${
              filter === 'all'
                ? 'bg-[#FFFFFF] text-[#1C3227] font-semibold shadow-xs'
                : 'text-[#6C7167] hover:text-[#1C3227]'
            }`}
          >
            All Submissions ({totalCount})
          </button>
        </div>

        <span className="text-xs font-mono text-[#777B73] flex items-center gap-1.5">
          <Filter className="w-3.5 h-3.5" />
          Displaying {filteredSubmissions.length} of {totalCount} records
        </span>
      </div>

      {/* Submissions Queue Table / List */}
      <div className="bg-[#FAF9F5] rounded-xl border border-[#E3E1D7] shadow-xs overflow-hidden">
        {filteredSubmissions.length === 0 ? (
          <div className="py-16 text-center text-[#6C7167] px-4 space-y-3">
            <Inbox className="w-10 h-10 mx-auto text-[#BCC0B9]" />
            <div>
              <h3 className="font-serif text-lg text-[#1C3227]">
                No specimens currently in this queue
              </h3>
              <p className="text-xs text-[#575E54] max-w-sm mx-auto mt-1 leading-relaxed">
                {filter === 'pending'
                  ? 'There are currently no low-confidence cases awaiting specialist triage. Upload an ambiguous sample from the Specimen Intake page to test the review queue.'
                  : 'No records match the active filter.'}
              </p>
            </div>
            <Link
              to="/detect"
              className="inline-flex items-center gap-2 px-4 py-2 rounded-lg text-xs font-medium text-[#FAF9F5] bg-[#243E30] hover:bg-[#1C3227] transition-colors"
            >
              <Sparkles className="w-3.5 h-3.5 text-[#C7D6CC]" />
              <span>Intake New Specimen</span>
            </Link>
          </div>
        ) : (
          <div className="divide-y divide-[#E3E1D7]">
            {filteredSubmissions.map((sub) => {
              const isPending = sub.status === 'flagged_for_review';
              const isReviewed = sub.status === 'reviewed';

              return (
                <div
                  key={sub.id}
                  className="p-4 sm:p-5 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 hover:bg-[#F2F0E7] transition-colors"
                >
                  {/* Thumbnail & Identity */}
                  <div className="flex items-center gap-3.5 min-w-0">
                    <SubmissionThumbnail
                      submissionId={sub.id}
                      altText={`Specimen thumbnail for ${sub.id}`}
                    />

                    <div className="min-w-0 space-y-0.5">
                      <div className="flex items-center gap-2">
                        <span className="font-mono text-xs font-semibold text-[#1C3227]">
                          {sub.id}
                        </span>
                        <StatusBadge status={sub.status} />
                      </div>

                      <h4 className="text-sm font-serif text-[#1C3227] truncate">
                        {sub.prediction.diseaseName}
                      </h4>

                      <div className="flex items-center gap-3 text-xs font-mono text-[#777B73]">
                        <span>
                          Model Confidence:{' '}
                          <strong className="text-[#1C3227] font-semibold">
                            {Math.round(sub.prediction.confidence * 100)}%
                          </strong>
                        </span>
                        <span>&bull;</span>
                        <span>{new Date(sub.timestamp).toLocaleDateString()}</span>
                      </div>
                    </div>
                  </div>

                  {/* Actions */}
                  <div className="flex items-center gap-2.5 w-full sm:w-auto justify-end">
                    <Link
                      to={`/result/${sub.id}`}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-mono text-[#575E54] hover:text-[#1C3227] bg-[#EAE8DD] hover:bg-[#DFDCCF] border border-[#DCD9CE] transition-colors"
                      title="View public result page in new tab"
                    >
                      <Eye className="w-3.5 h-3.5" />
                      <span>Public Record</span>
                      <ExternalLink className="w-3 h-3 text-[#777B73]" />
                    </Link>

                    <Link
                      to={`/admin/reviews/${sub.id}`}
                      className={`inline-flex items-center gap-1 px-4 py-1.5 rounded-lg text-xs font-medium transition-colors ${
                        isPending
                          ? 'bg-[#865721] hover:bg-[#684217] text-[#FAF9F5]'
                          : isReviewed
                          ? 'bg-[#243E30] hover:bg-[#1C3227] text-[#FAF9F5]'
                          : 'bg-[#EAE8DD] text-[#243E30] hover:bg-[#DFDCCF]'
                      }`}
                    >
                      <span>
                        {isPending
                          ? 'Review Specimen'
                          : isReviewed
                          ? 'Edit Assessment'
                          : 'Inspect Details'}
                      </span>
                    </Link>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Confirmation Reset Modal */}
      {resetModalOpen && (
        <div className="fixed inset-0 z-50 bg-[#122119]/50 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-[#FAF9F5] rounded-xl border border-[#E3E1D7] max-w-sm w-full p-6 shadow-xl animate-in zoom-in-95 duration-150 space-y-3">
            <div className="w-9 h-9 rounded-lg bg-[#FAF0EE] text-[#8E3526] flex items-center justify-center">
              <RotateCcw className="w-4 h-4" />
            </div>
            <div>
              <h3 className="font-serif text-lg text-[#1C3227]">
                Reset Demonstration Records?
              </h3>
              <p className="text-xs text-[#575E54] mt-1 leading-relaxed">
                This will purge all local browser submissions and specialist review records, restoring the evaluation environment to a clean state.
              </p>
            </div>
            <div className="flex items-center justify-end gap-2.5 pt-3 border-t border-[#E3E1D7]">
              <button
                type="button"
                onClick={() => setResetModalOpen(false)}
                className="px-3.5 py-1.5 rounded-lg text-xs font-mono text-[#575E54] hover:bg-[#EAE8DD]"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleResetData}
                className="px-4 py-1.5 rounded-lg text-xs font-medium text-[#FAF9F5] bg-[#8E3526] hover:bg-[#5E2218] transition-colors"
              >
                Confirm Reset
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function StatusBadge({ status }: { status: SubmissionStatus }) {
  if (status === 'flagged_for_review') {
    return (
      <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded text-[10px] font-mono font-medium bg-[#FBF4EB] text-[#865721] border border-[#EAD9C2]">
        <AlertTriangle className="w-3 h-3 text-[#865721]" />
        Pending Triage
      </span>
    );
  }

  if (status === 'reviewed') {
    return (
      <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded text-[10px] font-mono font-medium bg-[#EDF3EE] text-[#243E30] border border-[#CFDFD3]">
        <CheckCircle2 className="w-3 h-3 text-[#345842]" />
        Specialist Reviewed
      </span>
    );
  }

  return (
    <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded text-[10px] font-mono text-[#575E54] bg-[#EAE8DD] border border-[#DCD9CE]">
      Automated Conclusive
    </span>
  );
}