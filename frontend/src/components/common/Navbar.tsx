import { Link, useLocation } from 'react-router-dom';
import { UploadCloud, ShieldCheck } from 'lucide-react';

export function Navbar() {
  const location = useLocation();

  const isCurrent = (path: string) => location.pathname === path;
  const isAdminActive = location.pathname.startsWith('/admin');

  return (
    <header className="border-b border-[#E3E1D7] bg-[#F6F5EF]/92 backdrop-blur-md sticky top-0 z-30 transition-all">
      <div className="max-w-6xl mx-auto px-4 sm:px-6 h-16 flex items-center justify-between">
        {/* Brand Logo & Name */}
        <Link to="/" className="flex items-center space-x-2.5 group">
          <div className="w-8 h-8 sm:w-9 sm:h-9 rounded-lg bg-[#243E30] text-[#F6F5EF] flex items-center justify-center shadow-xs transition-colors group-hover:bg-[#1C3227] flex-shrink-0">
            {/* Custom Leaf + Lens combined SVG mark */}
            <svg
              className="w-4 h-4 sm:w-4.5 sm:h-4.5 text-[#C7D6CC]"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2.2"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              {/* Specimen leaf silhouette */}
              <path d="M11 20A7 7 0 0 1 9.8 6.1C15.5 5 17 4.48 19 2c1 2 2 4.18 2 8 0 5.5-4.78 10-10 10Z" />
              {/* Lens rim */}
              <circle cx="10" cy="11" r="5" stroke="currentColor" strokeWidth="2" />
              {/* Lens handle */}
              <line x1="14" y1="15" x2="18" y2="19" strokeWidth="2.5" />
            </svg>
          </div>
          <div>
            <span className="font-serif text-lg sm:text-xl tracking-tight text-[#1C3227] block leading-none">
              LeafLens
            </span>
            <span className="text-[9px] sm:text-[10px] text-[#777B73] font-medium tracking-wider uppercase hidden sm:block mt-0.5">
              Crop Health Analysis
            </span>
          </div>
        </Link>

        {/* Navigation Items */}
        <nav className="flex items-center space-x-1 sm:space-x-3 text-xs sm:text-sm">
          <Link
            to="/"
            className={`px-2 sm:px-3 py-1.5 rounded-md font-medium transition-colors ${
              isCurrent('/')
                ? 'text-[#1C3227] font-semibold'
                : 'text-[#6C7167] hover:text-[#1C3227]'
            }`}
          >
            Overview
          </Link>

          <Link
            to="/detect"
            className={`inline-flex items-center gap-1.5 px-2.5 sm:px-3.5 py-1.5 rounded-lg font-medium transition-all ${
              isCurrent('/detect')
                ? 'bg-[#243E30] text-[#FAF9F5] shadow-xs'
                : 'text-[#243E30] hover:bg-[#EAE8DD]'
            }`}
          >
            <UploadCloud className="w-3.5 h-3.5 flex-shrink-0" />
            <span><span className="hidden sm:inline">Analyze </span>Specimen</span>
          </Link>

          <div className="h-4 w-[1px] bg-[#E3E1D7] mx-1 hidden sm:block" />

          <Link
            to="/admin"
            className={`inline-flex items-center gap-1.5 px-2.5 sm:px-3 py-1.5 rounded-lg font-medium transition-colors ${
              isAdminActive
                ? 'bg-[#243E30] text-[#FAF9F5]'
                : 'text-[#6C7167] hover:text-[#1C3227] hover:bg-[#EAE8DD]'
            }`}
            title="Specialist Review Portal"
          >
            <ShieldCheck className={`w-3.5 h-3.5 flex-shrink-0 ${isAdminActive ? 'text-[#C7D6CC]' : 'text-[#6C7167]'}`} />
            <span>Specialist<span className="hidden sm:inline"> Portal</span></span>
          </Link>
        </nav>
      </div>
    </header>
  );
}
