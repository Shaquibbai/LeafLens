import { Link } from 'react-router-dom';
import { ArrowRight, UploadCloud } from 'lucide-react';

export function LandingPage() {
  return (
    <div className="flex flex-col min-h-full pb-20">
      {/* Editorial Masthead / Hero Section */}
      <section className="pt-12 sm:pt-16 pb-16 md:pb-24 border-b border-[#E3E1D7]">
        <div className="max-w-6xl mx-auto px-4 sm:px-6">
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 lg:gap-8 items-center">
            {/* Left Content (7 cols) */}
            <div className="lg:col-span-7 space-y-6">
              <div className="inline-flex items-center gap-2 text-xs font-mono tracking-wider text-[#6C7167] uppercase">
                <span className="w-1.5 h-1.5 rounded-full bg-[#345842]" />
                <span>Crop Health Analysis &bull; Foliar Diagnostics</span>
              </div>

              <h1 className="font-serif text-4xl sm:text-5xl lg:text-6xl text-[#1C3227] tracking-tight leading-[1.12]">
                A diagnostic platform for foliar health and agricultural resilience.
              </h1>

              <p className="text-sm sm:text-base text-[#575E54] leading-relaxed max-w-xl font-sans">
                LeafLens pairs computer vision classification with specialist triage. By reporting model confidence transparently and routing ambiguous cases to agronomists, the system provides grounded diagnostic support from field photograph to clinical assessment.
              </p>

              <div className="pt-2 flex flex-col sm:flex-row items-stretch sm:items-center gap-3">
                <Link
                  to="/detect"
                  className="inline-flex items-center justify-center gap-2.5 px-6 py-3.5 rounded-lg text-sm font-medium text-[#FAF9F5] bg-[#243E30] hover:bg-[#1C3227] transition-colors shadow-xs"
                >
                  <UploadCloud className="w-4 h-4 text-[#C7D6CC]" />
                  <span>Analyze Leaf Specimen</span>
                  <ArrowRight className="w-4 h-4 text-[#C7D6CC]" />
                </Link>

                <a
                  href="#methodology"
                  className="inline-flex items-center justify-center gap-2 px-5 py-3.5 rounded-lg text-sm font-medium text-[#243E30] bg-[#FAF9F5] hover:bg-[#EAE8DD] border border-[#E3E1D7] transition-colors"
                >
                  <span>Inspection Methodology</span>
                </a>
              </div>

              {/* Scope Footnote */}
              <div className="pt-4 flex flex-wrap items-center gap-x-4 gap-y-2 text-xs text-[#777B73] font-mono border-t border-[#E3E1D7]/70">
                <span>Scope: Rice (*Oryza sativa*) foliage</span>
                <span className="text-[#BCC0B9]">&bull;</span>
                <span>Deterministic demo engine</span>
                <span className="text-[#BCC0B9]">&bull;</span>
                <span>Local binary image persistence</span>
              </div>
            </div>

            {/* Right Editorial Plate (5 cols) */}
            <div className="lg:col-span-5">
              <div className="bg-[#FAF9F5] border border-[#E3E1D7] rounded-xl p-5 shadow-xs">
                {/* Plate Header */}
                <div className="flex items-center justify-between pb-3 border-b border-[#E3E1D7] text-xs font-mono text-[#777B73]">
                  <span>SPECIMEN PLATE #01</span>
                  <span className="text-[#345842] font-semibold">DIAGNOSTIC ARCHIVE</span>
                </div>

                {/* Botanical Illustration Artwork */}
                <div className="my-4 aspect-[4/3] bg-[#EAE8DE]/60 rounded-lg border border-[#DCD9CE] overflow-hidden flex items-center justify-center relative p-6">
                  {/* Stylized Rice Leaf Specimen Diagram */}
                  <svg
                    viewBox="0 0 320 220"
                    fill="none"
                    xmlns="http://www.w3.org/2000/svg"
                    className="w-full h-full max-h-48"
                  >
                    {/* Background Grid Pattern */}
                    <defs>
                      <pattern id="grid" width="20" height="20" patternUnits="userSpaceOnUse">
                        <line x1="0" y1="0" x2="20" y2="0" stroke="#D5D1C3" strokeWidth="0.5" />
                        <line x1="0" y1="0" x2="0" y2="20" stroke="#D5D1C3" strokeWidth="0.5" />
                      </pattern>
                    </defs>
                    <rect width="320" height="220" fill="url(#grid)" opacity="0.6" />

                    {/* Specimen Leaf Blade */}
                    <path
                      d="M30 150 C 90 90, 220 70, 290 110 C 230 155, 110 170, 30 150 Z"
                      fill="#3D634C"
                      stroke="#243E30"
                      strokeWidth="2"
                    />

                    {/* Central Vein */}
                    <path
                      d="M30 150 C 120 118, 200 98, 290 110"
                      stroke="#243E30"
                      strokeWidth="1.5"
                      strokeDasharray="2 3"
                    />

                    {/* Blast Lesion: Spindle / Diamond Shaped Necrotic Center */}
                    <ellipse
                      cx="145"
                      cy="116"
                      rx="26"
                      ry="9"
                      transform="rotate(-12 145 116)"
                      fill="#D7D2C4"
                      stroke="#6E5D48"
                      strokeWidth="1.8"
                    />
                    <ellipse
                      cx="145"
                      cy="116"
                      rx="14"
                      ry="4.5"
                      transform="rotate(-12 145 116)"
                      fill="#8D795E"
                    />

                    {/* Secondary Lesion */}
                    <ellipse
                      cx="205"
                      cy="104"
                      rx="18"
                      ry="6.5"
                      transform="rotate(-10 205 104)"
                      fill="#DDD8CB"
                      stroke="#78664E"
                      strokeWidth="1.5"
                    />

                    {/* Measurement Callouts */}
                    <circle cx="145" cy="116" r="3" fill="#243E30" />
                    <line x1="145" y1="116" x2="185" y2="60" stroke="#243E30" strokeWidth="1" />
                    <line x1="185" y1="60" x2="235" y2="60" stroke="#243E30" strokeWidth="1" />
                    <text x="240" y="63" fontFamily="monospace" fontSize="9" fill="#243E30">
                      Lesion Core: 12mm
                    </text>
                  </svg>

                  {/* Specimen Badge */}
                  <div className="absolute bottom-2 left-2 px-2 py-0.5 rounded bg-[#FAF9F5]/90 border border-[#DCD9CE] text-[10px] font-mono text-[#575E54]">
                    Specimen: *O. sativa* &bull; Foliar Sample
                  </div>
                </div>

                {/* Plate Metadata */}
                <div className="space-y-1.5 pt-2 text-xs">
                  <div className="flex justify-between text-[#6C7167]">
                    <span>Reference Condition</span>
                    <strong className="text-[#1C3227] font-sans">Rice Blast (*Pyricularia oryzae*)</strong>
                  </div>
                  <div className="flex justify-between text-[#6C7167]">
                    <span>Model Confidence</span>
                    <span className="font-mono text-[#243E30] font-semibold">94% &bull; Conclusive Tier</span>
                  </div>
                  <div className="flex justify-between text-[#6C7167]">
                    <span>Clinical Routing</span>
                    <span className="text-[#345842]">Advisory Issued Immediately</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Methodology Section (Clean editorial hierarchy, no generic 3-card boxes) */}
      <section id="methodology" className="py-16 md:py-20 border-b border-[#E3E1D7]">
        <div className="max-w-6xl mx-auto px-4 sm:px-6">
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-10">
            {/* Left Header (4 cols) */}
            <div className="lg:col-span-4 space-y-3">
              <span className="text-xs font-mono uppercase tracking-wider text-[#777B73] block">
                Platform Methodology
              </span>
              <h2 className="font-serif text-3xl sm:text-4xl text-[#1C3227] leading-tight">
                Designed for clinical precision, not automated assumptions.
              </h2>
              <p className="text-xs sm:text-sm text-[#575E54] leading-relaxed">
                Agricultural diagnostics require caution. Rather than forcing an uncertain classification into a false positive, LeafLens separates decisive visual patterns from specimens that demand human verification.
              </p>
            </div>

            {/* Right Detailed Columns (8 cols) */}
            <div className="lg:col-span-8 divide-y divide-[#E3E1D7]">
              {/* Pillar 01 */}
              <div className="py-6 first:pt-0 space-y-2">
                <div className="flex items-baseline gap-3">
                  <span className="font-mono text-xs text-[#78664E] font-semibold">01</span>
                  <h3 className="font-serif text-xl sm:text-2xl text-[#1C3227]">
                    Visual foliar pathology
                  </h3>
                </div>
                <p className="text-xs sm:text-sm text-[#575E54] leading-relaxed pl-7">
                  Computer vision models analyze lesion morphology, necrotic margins, and chlorotic discoloration. Initial calibration targets major cultivated rice diseases including Rice Blast and Bacterial Leaf Blight.
                </p>
              </div>

              {/* Pillar 02 */}
              <div className="py-6 space-y-2">
                <div className="flex items-baseline gap-3">
                  <span className="font-mono text-xs text-[#78664E] font-semibold">02</span>
                  <h3 className="font-serif text-xl sm:text-2xl text-[#1C3227]">
                    Calibrated confidence thresholds
                  </h3>
                </div>
                <p className="text-xs sm:text-sm text-[#575E54] leading-relaxed pl-7">
                  Confidence scores represent algorithmic certainty. When visual indicators are obscured by glare, camera blur, or atypical lesions, the system withholds treatment advice to prevent chemical misapplication.
                </p>
              </div>

              {/* Pillar 03 */}
              <div className="py-6 last:pb-0 space-y-2">
                <div className="flex items-baseline gap-3">
                  <span className="font-mono text-xs text-[#78664E] font-semibold">03</span>
                  <h3 className="font-serif text-xl sm:text-2xl text-[#1C3227]">
                    Specialist review triage
                  </h3>
                </div>
                <p className="text-xs sm:text-sm text-[#575E54] leading-relaxed pl-7">
                  Low-confidence cases automatically enter an administrator review queue. Agricultural extension specialists inspect the original high-resolution specimen, log diagnostic assessments, and update the public case record.
                </p>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Field Photography Guidance (Specimen Capture Protocol) */}
      <section className="py-16 md:py-20 border-b border-[#E3E1D7] bg-[#FAF9F5]">
        <div className="max-w-6xl mx-auto px-4 sm:px-6">
          <div className="max-w-2xl mb-10">
            <span className="text-xs font-mono uppercase tracking-wider text-[#777B73] block mb-1">
              Field Protocol
            </span>
            <h2 className="font-serif text-3xl sm:text-4xl text-[#1C3227] leading-tight">
              Specimen photography recommendations
            </h2>
            <p className="text-xs sm:text-sm text-[#575E54] mt-2 leading-relaxed">
              Diagnostic accuracy depends directly on photographic fidelity. For reliable classification, follow standard agricultural inspection practices:
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            <div className="space-y-2 border-t border-[#E3E1D7] pt-4">
              <span className="font-mono text-xs text-[#243E30] font-semibold block">A &bull; Focus & Framing</span>
              <h4 className="font-sans font-semibold text-sm text-[#1C3227]">Isolate a single leaf blade</h4>
              <p className="text-xs text-[#575E54] leading-relaxed">
                Ensure the primary leaf lesion is centered and sharp. Exclude distracting backgrounds such as soil, footwear, or hands from the lens frame.
              </p>
            </div>

            <div className="space-y-2 border-t border-[#E3E1D7] pt-4">
              <span className="font-mono text-xs text-[#243E30] font-semibold block">B &bull; Illumination</span>
              <h4 className="font-sans font-semibold text-sm text-[#1C3227]">Diffuse natural daylight</h4>
              <p className="text-xs text-[#575E54] leading-relaxed">
                Photograph under open shade or during morning daylight. Avoid artificial flash, heavy specular reflection, or deep cast shadows across lesions.
              </p>
            </div>

            <div className="space-y-2 border-t border-[#E3E1D7] pt-4">
              <span className="font-mono text-xs text-[#243E30] font-semibold block">C &bull; Lesion Demarcation</span>
              <h4 className="font-sans font-semibold text-sm text-[#1C3227]">Capture tissue margins</h4>
              <p className="text-xs text-[#575E54] leading-relaxed">
                Include both healthy green leaf tissue and the diseased discoloration to enable the model to measure transition borders and necrosis halos.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Direct Call to Action */}
      <section className="py-16 md:py-20">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 text-center space-y-4">
          <h2 className="font-serif text-3xl sm:text-4xl text-[#1C3227] leading-tight">
            Ready to evaluate a crop leaf specimen?
          </h2>
          <p className="text-xs sm:text-sm text-[#575E54] max-w-xl mx-auto leading-relaxed">
            Upload your own field photograph or test calibrated scenarios to observe how LeafLens handles high-confidence results and specialist review routing.
          </p>
          <div className="pt-2">
            <Link
              to="/detect"
              className="inline-flex items-center gap-2 px-6 py-3 rounded-lg text-sm font-medium text-[#FAF9F5] bg-[#243E30] hover:bg-[#1C3227] transition-colors shadow-xs"
            >
              <UploadCloud className="w-4 h-4 text-[#C7D6CC]" />
              <span>Begin Specimen Analysis</span>
            </Link>
          </div>
        </div>
      </section>
    </div>
  );
}
