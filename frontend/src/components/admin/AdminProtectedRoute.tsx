import React from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { isAdministratorAuthenticated } from '../../services/authService';

interface AdminProtectedRouteProps {
  children: React.ReactNode;
}

export function AdminProtectedRoute({ children }: AdminProtectedRouteProps) {
  const location = useLocation();

  if (!isAdministratorAuthenticated()) {
    return <Navigate to="/admin/login" state={{ from: location }} replace />;
  }

  return <>{children}</>;
}
