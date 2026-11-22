import { useEffect } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { Navbar } from './components/common/Navbar';
import { Footer } from './components/common/Footer';
import { LandingPage } from './pages/LandingPage';
import { DetectPage } from './pages/DetectPage';
import { ResultPage } from './pages/ResultPage';
import { AdminLoginPage } from './pages/admin/AdminLoginPage';
import { AdminDashboardPage } from './pages/admin/AdminDashboardPage';
import { AdminReviewPage } from './pages/admin/AdminReviewPage';
import { AdminProtectedRoute } from './components/admin/AdminProtectedRoute';
import { migrateLegacySubmissions } from './services/storageService';

export default function App() {
  // Trigger automatic one-time migration of legacy base64 localStorage images into IndexedDB Blobs
  useEffect(() => {
    migrateLegacySubmissions().catch((err) => {
      console.error('Initial legacy image migration failed:', err);
    });
  }, []);

  return (
    <BrowserRouter>
      <div className="min-h-screen bg-[#F6F5EF] text-[#30352F] flex flex-col font-sans selection:bg-[#D5DCD0] selection:text-[#122119]">
        {/* Persistent Brand Header */}
        <Navbar />

        {/* Dynamic Route Content */}
        <main className="flex-1 flex flex-col">
          <Routes>
            {/* Public Visitor Routes */}
            <Route path="/" element={<LandingPage />} />
            <Route path="/detect" element={<DetectPage />} />
            <Route path="/result/:submissionId" element={<ResultPage />} />

            {/* Administrator / Specialist Routes */}
            <Route path="/admin/login" element={<AdminLoginPage />} />
            <Route
              path="/admin"
              element={
                <AdminProtectedRoute>
                  <AdminDashboardPage />
                </AdminProtectedRoute>
              }
            />
            <Route
              path="/admin/reviews/:submissionId"
              element={
                <AdminProtectedRoute>
                  <AdminReviewPage />
                </AdminProtectedRoute>
              }
            />

            {/* Catch-all redirect to Landing */}
            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </main>

        {/* Persistent Footer */}
        <Footer />
      </div>
    </BrowserRouter>
  );
}
