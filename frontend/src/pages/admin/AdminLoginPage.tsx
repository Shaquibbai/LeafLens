import React, { useState } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { ShieldCheck, ArrowRight, User, Lock } from 'lucide-react';
import { loginAdministrator, isAdministratorAuthenticated } from '../../services/authService';

export function AdminLoginPage() {
  const navigate = useNavigate();
  const location = useLocation();

  const [username, setUsername] = useState('admin');
  const [password, setPassword] = useState('leaflens2026');

  // If already authenticated, redirect to /admin
  React.useEffect(() => {
    if (isAdministratorAuthenticated()) {
      navigate('/admin', { replace: true });
    }
  }, [navigate]);

  const handleLogin = (e?: React.FormEvent) => {
    if (e) e.preventDefault();
    loginAdministrator(username);
    const from = (location.state as { from?: { pathname: string } })?.from?.pathname || '/admin';
    navigate(from, { replace: true });
  };

  return (
    <div className="py-12 sm:py-20 max-w-md mx-auto px-4 sm:px-6 w-full">
      {/* Login Card */}
      <div className="bg-[#FAF9F5] rounded-xl border border-[#E3E1D7] p-6 sm:p-8 shadow-xs">
        <div className="text-center mb-6 pb-4 border-b border-[#E3E1D7]">
          <div className="w-10 h-10 rounded-lg bg-[#243E30] text-[#FAF9F5] flex items-center justify-center mx-auto mb-3 shadow-xs">
            <ShieldCheck className="w-5 h-5 text-[#C7D6CC]" />
          </div>
          <span className="text-[10px] font-mono uppercase tracking-widest text-[#777B73] block mb-1">
            Access Authorization
          </span>
          <h1 className="font-serif text-2xl text-[#1C3227] tracking-tight">
            Specialist Review Portal
          </h1>
          <p className="text-xs text-[#575E54] mt-1 font-sans">
            Agricultural specimen review and quality assurance system
          </p>
        </div>

        <form onSubmit={handleLogin} className="space-y-4">
          <div>
            <label className="block text-xs font-mono font-medium text-[#1C3227] mb-1.5 flex items-center gap-1.5">
              <User className="w-3.5 h-3.5 text-[#777B73]" />
              Specialist Identity
            </label>
            <input
              type="text"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              className="w-full px-3 py-2 rounded-lg border border-[#DCD9CE] text-xs text-[#1C3227] bg-[#FFFFFF] focus:outline-none focus:ring-1 focus:ring-[#243E30] focus:border-[#243E30] transition-all font-mono"
              placeholder="e.g. admin"
              required
            />
          </div>

          <div>
            <label className="block text-xs font-mono font-medium text-[#1C3227] mb-1.5 flex items-center gap-1.5">
              <Lock className="w-3.5 h-3.5 text-[#777B73]" />
              Passcode
            </label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full px-3 py-2 rounded-lg border border-[#DCD9CE] text-xs text-[#1C3227] bg-[#FFFFFF] focus:outline-none focus:ring-1 focus:ring-[#243E30] focus:border-[#243E30] transition-all font-mono"
              placeholder="••••••••"
              required
            />
          </div>

          {/* Demonstration Credentials Note */}
          <div className="p-3 bg-[#EAE8DD] rounded-lg border border-[#DCD9CE] text-[11px] text-[#575E54] font-mono leading-normal">
            Demo evaluator profile: <span className="text-[#1C3227] font-semibold">Dr. S. Rahman</span> (Agricultural Extension Specialist).
          </div>

          {/* Submit Button */}
          <button
            type="submit"
            className="w-full inline-flex items-center justify-center gap-2 px-5 py-2.5 rounded-lg text-xs font-medium text-[#FAF9F5] bg-[#243E30] hover:bg-[#1C3227] transition-colors shadow-xs mt-2"
          >
            <span>Enter Specialist Dashboard</span>
            <ArrowRight className="w-3.5 h-3.5 text-[#C7D6CC]" />
          </button>
        </form>

        {/* Single-Click Presentation Shortcut */}
        <div className="mt-5 pt-4 border-t border-[#E3E1D7] text-center">
          <button
            type="button"
            onClick={() => handleLogin()}
            className="text-xs font-mono text-[#78664E] hover:text-[#243E30] underline underline-offset-4 decoration-[#DCD9CE] transition-colors"
          >
            Fill Demo Credentials &amp; Login
          </button>
        </div>
      </div>
    </div>
  );
}