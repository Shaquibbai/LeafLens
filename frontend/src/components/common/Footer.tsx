import { Link } from 'react-router-dom';

export function Footer() {
  return (
    <footer className="border-t border-[#E3E1D7] bg-[#F1EFE8]/70 text-[#424840] mt-auto text-xs">
      <div className="max-w-6xl mx-auto px-4 sm:px-6 py-12">
        <div className="grid grid-cols-1 md:grid-cols-12 gap-8 mb-10">
          {/* Brand & Purpose (5 cols) */}
          <div className="md:col-span-5 space-y-3">
            <div className="flex items-center space-x-2.5">
              <span className="font-serif text-xl tracking-tight text-[#1C3227]">
                LeafLens
              </span>
              <span className="text-[10px] text-[#777B73] tracking-widest uppercase font-mono">
                Platform
              </span>
            </div>
            <p className="text-[#6C7167] leading-relaxed max-w-sm text-xs">
              A crop health analysis platform providing foliar disease detection, transparent model confidence, and agricultural specialist triage.
            </p>
            <div className="text-[11px] text-[#777B73] font-mono pt-1">
              Active specimen scope: <span className="text-[#243E30] font-semibold">Rice (*Oryza sativa*)</span>
            </div>
          </div>

          {/* Navigation Links (3 cols) */}
          <div className="md:col-span-3 space-y-3">
            <h4 className="font-sans font-semibold text-[#1C3227] tracking-wider uppercase text-[11px]">
              Platform Navigation
            </h4>
            <ul className="space-y-2 text-[#6C7167]">
              <li>
                <Link to="/" className="hover:text-[#1C3227] transition-colors">
                  System Overview
                </Link>
              </li>
              <li>
                <Link to="/detect" className="hover:text-[#1C3227] transition-colors">
                  Specimen Intake & Analysis
                </Link>
              </li>
              <li>
                <Link to="/admin" className="hover:text-[#1C3227] transition-colors">
                  Specialist Review Portal
                </Link>
              </li>
            </ul>
          </div>

          {/* Academic & Demonstration Context (4 cols) */}
          <div className="md:col-span-4 space-y-3">
            <h4 className="font-sans font-semibold text-[#1C3227] tracking-wider uppercase text-[11px]">
              Academic Component & Scope
            </h4>
            <p className="text-[#6C7167] leading-relaxed text-xs">
              Developed as an academic software development project by a university team. Current evaluations use deterministic simulation for prototype demonstration. Automated classifications are illustrative decision-support aids and do not substitute for on-site agricultural extension verification.
            </p>
          </div>
        </div>

        {/* Bottom Bar */}
        <div className="pt-6 border-t border-[#E3E1D7] flex flex-col sm:flex-row items-center justify-between text-[#777B73] gap-2 text-[11px]">
          <span>&copy; {new Date().getFullYear()} LeafLens. Academic Software Engineering Laboratory.</span>
          <span className="font-mono text-[10px] text-[#8E9389]">
            Build v0.2.0 &bull; Contemporary Botanical Edition
          </span>
        </div>
      </div>
    </footer>
  );
}
