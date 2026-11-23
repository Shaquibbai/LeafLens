/**
 * Simulated Administrator Authentication Service for LeafLens Demonstration.
 *
 * NOTE: This is a client-side mock authentication service isolated for demonstration.
 * It will eventually be replaced by JWT-based authentication from FastAPI.
 */

const SESSION_KEY = 'leaflens_admin_session_v1';

export interface AdminUser {
  username: string;
  displayName: string;
  role: string;
  loggedInAt: string;
}

const DEFAULT_ADMIN: AdminUser = {
  username: 'admin',
  displayName: 'Dr. S. Rahman',
  role: 'Agricultural Extension Specialist',
  loggedInAt: '',
};

/**
 * Checks if an active demonstration administrator session exists.
 */
export function isAdministratorAuthenticated(): boolean {
  if (typeof window === 'undefined') return false;
  try {
    const session = sessionStorage.getItem(SESSION_KEY);
    return session !== null;
  } catch {
    return false;
  }
}

/**
 * Returns current authenticated admin user or null.
 */
export function getCurrentAdminUser(): AdminUser | null {
  if (typeof window === 'undefined') return null;
  try {
    const raw = sessionStorage.getItem(SESSION_KEY);
    if (!raw) return null;
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

/**
 * Initiates a demonstration administrator session.
 * For presentation convenience, allows single-click demo login or credential validation.
 */
export function loginAdministrator(username = 'admin'): boolean {
  try {
    const user: AdminUser = {
      ...DEFAULT_ADMIN,
      username: username || 'admin',
      loggedInAt: new Date().toISOString(),
    };
    sessionStorage.setItem(SESSION_KEY, JSON.stringify(user));
    return true;
  } catch (err) {
    console.error('Failed to set administrator session:', err);
    return false;
  }
}

/**
 * Clears the active administrator session.
 */
export function logoutAdministrator(): void {
  try {
    sessionStorage.removeItem(SESSION_KEY);
  } catch (err) {
    console.warn('Failed to clear administrator session:', err);
  }
}
