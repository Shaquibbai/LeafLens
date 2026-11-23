-- ============================================================================
-- LeafLense Database – Functions & Procedures
-- File: 02_functions_procedures.sql
-- Description: Admin login & session verification, admin low-confidence review
--              workflow, and login-free farmer submission & report lookup.
--              Roles: Farmer (no login) and Admin ('admin' role only).
-- ============================================================================

SET search_path = leaflense, public;

-- Clean up any previously removed analytics / super_admin functions if upgrading
DROP FUNCTION IF EXISTS calculate_model_performance(INT);
DROP FUNCTION IF EXISTS calculate_model_performance(INT, TEXT);
DROP FUNCTION IF EXISTS get_disease_statistics(TIMESTAMPTZ, TIMESTAMPTZ);
DROP FUNCTION IF EXISTS get_disease_statistics(TIMESTAMPTZ, TIMESTAMPTZ, TEXT);
DROP FUNCTION IF EXISTS get_active_confidence_threshold();
DROP FUNCTION IF EXISTS get_active_confidence_threshold(TEXT);
DROP FUNCTION IF EXISTS create_admin_user(VARCHAR, TEXT, admin_role, VARCHAR, VARCHAR, TEXT);
DROP FUNCTION IF EXISTS change_admin_password(INT, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS set_admin_active_status(INT, BOOLEAN, TEXT);
DROP FUNCTION IF EXISTS get_admin_users(TEXT);
DROP FUNCTION IF EXISTS update_model_config(INT, NUMERIC, BOOLEAN, TEXT);
DROP FUNCTION IF EXISTS get_audit_logs(INT, VARCHAR, TEXT);
DROP FUNCTION IF EXISTS fn_require_admin_privilege(admin_role[], TEXT);

-- ============================================================================
-- FRONTEND INTEGRATION: ADMIN AUTHENTICATION & PRIVILEGE HELPERS
-- ============================================================================

-- Safe read-only view of admin accounts (never exposes password_hash)
DROP VIEW IF EXISTS v_admin_users_public CASCADE;

CREATE OR REPLACE VIEW v_admin_users_public AS
SELECT
    admin_id,
    username,
    full_name,
    email,
    role,
    is_active,
    last_login_at,
    created_at
FROM AdminUsers;

GRANT SELECT ON v_admin_users_public TO leaflense_admin, leaflense_app;

COMMENT ON VIEW v_admin_users_public
    IS 'Safe admin user directory omitting password hashes and lockout internals.';

-- Maps the 'admin' role to explicit frontend capability flags
DROP FUNCTION IF EXISTS fn_get_role_privileges(admin_role);

CREATE OR REPLACE FUNCTION fn_get_role_privileges(p_role admin_role)
RETURNS JSONB
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT CASE p_role
        WHEN 'admin' THEN jsonb_build_object(
            'can_view_pending_reviews',  TRUE,
            'can_review_low_confidence', TRUE,
            'can_reject_submissions',    TRUE
        )
    END;
$$;

GRANT EXECUTE ON FUNCTION fn_get_role_privileges(admin_role) TO leaflense_admin, leaflense_app;

-- Internal guard: authorizes either DB-level admin roles (leaflense_admin / postgres)
-- OR an active, non-revoked AdminSessions token belonging to an active admin.
DROP FUNCTION IF EXISTS fn_require_admin_privilege(TEXT);

CREATE OR REPLACE FUNCTION fn_require_admin_privilege(
    p_session_token TEXT DEFAULT NULL
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = leaflense, public
AS $$
DECLARE
    v_token         TEXT;
    v_token_hash    VARCHAR(64);
    v_admin_id      INT;
    v_username      VARCHAR(100);
    v_role          admin_role;
BEGIN
    v_token := COALESCE(
        NULLIF(TRIM(p_session_token), ''),
        NULLIF(TRIM(current_setting('leaflense.session_token', true)), '')
    );

    -- If a session token is provided, validate it and verify active admin account
    IF v_token IS NOT NULL THEN
        v_token_hash := encode(digest(v_token, 'sha256'), 'hex');

        SELECT s.admin_id, u.username, u.role
          INTO v_admin_id, v_username, v_role
          FROM AdminSessions s
          INNER JOIN AdminUsers u ON u.admin_id = s.admin_id
         WHERE s.token_hash = v_token_hash
           AND s.is_revoked = FALSE
           AND s.expires_at > NOW()
           AND u.is_active  = TRUE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Access denied: invalid or expired admin session.';
        END IF;

        IF v_role <> 'admin' THEN
            RAISE EXCEPTION 'Access denied: admin role required.';
        END IF;

        UPDATE AdminSessions
           SET last_activity_at = NOW()
         WHERE token_hash = v_token_hash;

        PERFORM set_config('leaflense.current_admin', v_username, true);
        RETURN v_admin_id;
    END IF;

    -- Fallback for direct DBA / backend connections using PostgreSQL admin roles
    IF pg_has_role(current_user, 'leaflense_admin', 'MEMBER')
       OR current_user = 'leaflense_admin'
       OR current_user = 'postgres' THEN
        RETURN NULL;
    END IF;

    RAISE EXCEPTION 'Access denied: admin login required. Current user: %', current_user;
END;
$$;

ALTER FUNCTION fn_require_admin_privilege(TEXT) OWNER TO leaflense_admin;
GRANT EXECUTE ON FUNCTION fn_require_admin_privilege(TEXT) TO leaflense_admin, leaflense_app;

-- ============================================================================
-- FUNCTION: login_admin(p_username, p_password, p_ip_address, p_user_agent)
-- ----------------------------------------------------------------------------
-- Authenticates an admin from the corner-tab Login Page.
-- Verifies bcrypt password hash via pgcrypto crypt(), enforces account
-- active & lockout state, issues an AdminSessions token, logs the login
-- event in AuditLogs, and returns the admin profile + privileges.
-- Farmers never call this; it is strictly for Admin login.
-- ============================================================================

DROP FUNCTION IF EXISTS login_admin(VARCHAR, TEXT, INET, TEXT);

CREATE OR REPLACE FUNCTION login_admin(
    p_username   VARCHAR,
    p_password   TEXT,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
)
RETURNS TABLE (
    authenticated  BOOLEAN,
    admin_id       INT,
    username       VARCHAR,
    full_name      VARCHAR,
    role           admin_role,
    privileges     JSONB,
    session_token  TEXT,
    expires_at     TIMESTAMPTZ,
    message        TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = leaflense, public
AS $$
DECLARE
    v_user            AdminUsers%ROWTYPE;
    v_clean_username  VARCHAR(100);
    v_password_match  BOOLEAN := FALSE;
    v_raw_token       TEXT;
    v_token_hash      VARCHAR(64);
    v_expires_at      TIMESTAMPTZ;
    v_attempts        INT;
BEGIN
    v_clean_username := TRIM(COALESCE(p_username, ''));

    IF v_clean_username = '' OR COALESCE(p_password, '') = '' THEN
        RETURN QUERY SELECT
            FALSE, NULL::INT, NULL::VARCHAR, NULL::VARCHAR, NULL::admin_role,
            NULL::JSONB, NULL::TEXT, NULL::TIMESTAMPTZ,
            'Username and password are required.'::TEXT;
        RETURN;
    END IF;

    SELECT *
      INTO v_user
      FROM AdminUsers u
     WHERE u.username = v_clean_username;

    IF NOT FOUND THEN
        INSERT INTO AuditLogs (actor, action, table_name, record_id, new_values)
        VALUES (
            v_clean_username,
            'LOGIN_FAILED',
            'admin_users',
            NULL,
            jsonb_build_object('reason', 'unknown_username', 'ip_address', p_ip_address)
        );

        RETURN QUERY SELECT
            FALSE, NULL::INT, NULL::VARCHAR, NULL::VARCHAR, NULL::admin_role,
            NULL::JSONB, NULL::TEXT, NULL::TIMESTAMPTZ,
            'Invalid username or password.'::TEXT;
        RETURN;
    END IF;

    IF v_user.is_active = FALSE THEN
        INSERT INTO AuditLogs (actor, action, table_name, record_id, new_values)
        VALUES (
            v_user.username,
            'LOGIN_FAILED',
            'admin_users',
            v_user.admin_id,
            jsonb_build_object('reason', 'account_inactive', 'ip_address', p_ip_address)
        );

        RETURN QUERY SELECT
            FALSE, NULL::INT, NULL::VARCHAR, NULL::VARCHAR, NULL::admin_role,
            NULL::JSONB, NULL::TEXT, NULL::TIMESTAMPTZ,
            'Account is deactivated.'::TEXT;
        RETURN;
    END IF;

    IF v_user.locked_until IS NOT NULL AND v_user.locked_until > NOW() THEN
        RETURN QUERY SELECT
            FALSE, NULL::INT, NULL::VARCHAR, NULL::VARCHAR, NULL::admin_role,
            NULL::JSONB, NULL::TEXT, NULL::TIMESTAMPTZ,
            'Account temporarily locked due to too many failed login attempts. Try again later.'::TEXT;
        RETURN;
    END IF;

    BEGIN
        v_password_match := (crypt(p_password, v_user.password_hash) = v_user.password_hash);
    EXCEPTION WHEN OTHERS THEN
        v_password_match := FALSE;
    END;

    IF NOT COALESCE(v_password_match, FALSE) THEN
        v_attempts := COALESCE(v_user.failed_login_attempts, 0) + 1;

        UPDATE AdminUsers
           SET failed_login_attempts = v_attempts,
               locked_until = CASE
                   WHEN v_attempts >= 5 THEN NOW() + INTERVAL '15 minutes'
                   ELSE NULL
               END
         WHERE AdminUsers.admin_id = v_user.admin_id;

        INSERT INTO AuditLogs (actor, action, table_name, record_id, new_values)
        VALUES (
            v_user.username,
            'LOGIN_FAILED',
            'admin_users',
            v_user.admin_id,
            jsonb_build_object('reason', 'invalid_password', 'attempt', v_attempts, 'ip_address', p_ip_address)
        );

        RETURN QUERY SELECT
            FALSE, NULL::INT, NULL::VARCHAR, NULL::VARCHAR, NULL::admin_role,
            NULL::JSONB, NULL::TEXT, NULL::TIMESTAMPTZ,
            'Invalid username or password.'::TEXT;
        RETURN;
    END IF;

    -- Successful authentication: reset lockout counters & issue session token
    UPDATE AdminUsers
       SET failed_login_attempts = 0,
           locked_until          = NULL,
           last_login_at         = NOW()
     WHERE AdminUsers.admin_id = v_user.admin_id;

    v_raw_token  := encode(gen_random_bytes(32), 'hex');
    v_token_hash := encode(digest(v_raw_token, 'sha256'), 'hex');
    v_expires_at := NOW() + INTERVAL '12 hours';

    INSERT INTO AdminSessions (admin_id, token_hash, ip_address, user_agent, expires_at)
    VALUES (v_user.admin_id, v_token_hash, p_ip_address, p_user_agent, v_expires_at);

    INSERT INTO AuditLogs (actor, action, table_name, record_id, new_values)
    VALUES (
        v_user.username,
        'LOGIN',
        'admin_users',
        v_user.admin_id,
        jsonb_build_object('role', v_user.role, 'ip_address', p_ip_address)
    );

    RETURN QUERY SELECT
        TRUE,
        v_user.admin_id,
        v_user.username,
        v_user.full_name,
        v_user.role,
        fn_get_role_privileges(v_user.role),
        v_raw_token,
        v_expires_at,
        'Login successful.'::TEXT;
END;
$$;

ALTER FUNCTION login_admin(VARCHAR, TEXT, INET, TEXT) OWNER TO leaflense_admin;
GRANT EXECUTE ON FUNCTION login_admin(VARCHAR, TEXT, INET, TEXT) TO leaflense_admin, leaflense_app;

COMMENT ON FUNCTION login_admin(VARCHAR, TEXT, INET, TEXT)
    IS 'Authenticates an admin using username and password, returning admin privileges and a session token.';

-- ============================================================================
-- FUNCTION: verify_admin_session(p_session_token)
-- ----------------------------------------------------------------------------
-- Validates an admin session token from the frontend/backend and returns
-- the authenticated admin profile and privileges.
-- ============================================================================

DROP FUNCTION IF EXISTS verify_admin_session(TEXT);

CREATE OR REPLACE FUNCTION verify_admin_session(p_session_token TEXT)
RETURNS TABLE (
    is_valid    BOOLEAN,
    admin_id    INT,
    username    VARCHAR,
    full_name   VARCHAR,
    role        admin_role,
    privileges  JSONB,
    expires_at  TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = leaflense, public
AS $$
DECLARE
    v_token_hash VARCHAR(64);
    v_rec        RECORD;
BEGIN
    IF NULLIF(TRIM(COALESCE(p_session_token, '')), '') IS NULL THEN
        RETURN QUERY SELECT FALSE, NULL::INT, NULL::VARCHAR, NULL::VARCHAR, NULL::admin_role, NULL::JSONB, NULL::TIMESTAMPTZ;
        RETURN;
    END IF;

    v_token_hash := encode(digest(TRIM(p_session_token), 'sha256'), 'hex');

    SELECT
        u.admin_id,
        u.username,
        u.full_name,
        u.role,
        s.expires_at
      INTO v_rec
      FROM AdminSessions s
      INNER JOIN AdminUsers u ON u.admin_id = s.admin_id
     WHERE s.token_hash = v_token_hash
       AND s.is_revoked = FALSE
       AND s.expires_at > NOW()
       AND u.is_active  = TRUE;

    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, NULL::INT, NULL::VARCHAR, NULL::VARCHAR, NULL::admin_role, NULL::JSONB, NULL::TIMESTAMPTZ;
        RETURN;
    END IF;

    UPDATE AdminSessions
       SET last_activity_at = NOW()
     WHERE token_hash = v_token_hash;

    RETURN QUERY SELECT
        TRUE,
        v_rec.admin_id,
        v_rec.username,
        v_rec.full_name,
        v_rec.role,
        fn_get_role_privileges(v_rec.role),
        v_rec.expires_at;
END;
$$;

ALTER FUNCTION verify_admin_session(TEXT) OWNER TO leaflense_admin;
GRANT EXECUTE ON FUNCTION verify_admin_session(TEXT) TO leaflense_admin, leaflense_app;

COMMENT ON FUNCTION verify_admin_session(TEXT)
    IS 'Validates an active admin session token and returns admin privileges.';

-- ============================================================================
-- FUNCTION: logout_admin(p_session_token)
-- ----------------------------------------------------------------------------
-- Revokes the active session token and records a LOGOUT entry in AuditLogs.
-- ============================================================================

DROP FUNCTION IF EXISTS logout_admin(TEXT);

CREATE OR REPLACE FUNCTION logout_admin(p_session_token TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = leaflense, public
AS $$
DECLARE
    v_token_hash VARCHAR(64);
    v_admin_id   INT;
    v_username   VARCHAR(100);
BEGIN
    IF NULLIF(TRIM(COALESCE(p_session_token, '')), '') IS NULL THEN
        RETURN FALSE;
    END IF;

    v_token_hash := encode(digest(TRIM(p_session_token), 'sha256'), 'hex');

    UPDATE AdminSessions s
       SET is_revoked = TRUE
      FROM AdminUsers u
     WHERE s.admin_id   = u.admin_id
       AND s.token_hash = v_token_hash
       AND s.is_revoked = FALSE
     RETURNING s.admin_id, u.username INTO v_admin_id, v_username;

    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;

    INSERT INTO AuditLogs (actor, action, table_name, record_id, new_values)
    VALUES (
        v_username,
        'LOGOUT',
        'admin_sessions',
        v_admin_id,
        jsonb_build_object('revoked', TRUE)
    );

    RETURN TRUE;
END;
$$;

ALTER FUNCTION logout_admin(TEXT) OWNER TO leaflense_admin;
GRANT EXECUTE ON FUNCTION logout_admin(TEXT) TO leaflense_admin, leaflense_app;

COMMENT ON FUNCTION logout_admin(TEXT)
    IS 'Revokes an admin session token and records the logout in AuditLogs.';

-- ============================================================================
-- FRONTEND INTEGRATION: PENDING LOW-CONFIDENCE VIEW & FUNCTION
-- ----------------------------------------------------------------------------
-- Powers the "Pending Low-Confidence Reviews" tab for logged-in admins.
-- ============================================================================

DROP VIEW IF EXISTS v_pending_low_confidence_reviews CASCADE;

CREATE OR REPLACE VIEW v_pending_low_confidence_reviews AS
SELECT
    s.submission_id,
    s.image_path,
    s.additional_info                                       AS farmer_additional_info,
    s.submitted_at,
    s.status,
    p.prediction_id,
    p.disease_id                                            AS predicted_disease_id,
    d.disease_name                                          AS predicted_disease_name,
    p.confidence_score,
    m.model_id,
    m.model_name,
    m.version                                               AS model_version,
    m.confidence_threshold,
    ROUND((m.confidence_threshold - p.confidence_score), 4) AS threshold_gap,
    DATE_PART('day', NOW() - s.submitted_at)::INT           AS days_pending
FROM
    Submissions s
    INNER JOIN Predictions p ON p.submission_id  = s.submission_id
                             AND p.is_top_prediction = TRUE
    INNER JOIN Models      m ON m.model_id       = p.model_id
    INNER JOIN Diseases    d ON d.disease_id     = p.disease_id
WHERE
    s.status = 'low_confidence'
ORDER BY
    p.confidence_score ASC;

GRANT SELECT ON v_pending_low_confidence_reviews TO leaflense_admin, leaflense_app;

COMMENT ON VIEW v_pending_low_confidence_reviews
    IS 'Powers the admin review queue showing all pending low-confidence submissions with farmer notes, sorted by lowest score first.';

DROP FUNCTION IF EXISTS get_pending_low_confidence_submissions();
DROP FUNCTION IF EXISTS get_pending_low_confidence_submissions(TEXT);

CREATE OR REPLACE FUNCTION get_pending_low_confidence_submissions(p_session_token TEXT DEFAULT NULL)
RETURNS TABLE (
    submission_id           INT,
    image_path              VARCHAR,
    farmer_additional_info  TEXT,
    submitted_at            TIMESTAMPTZ,
    status                  submission_status,
    prediction_id           INT,
    predicted_disease_id    INT,
    predicted_disease_name  VARCHAR,
    confidence_score        NUMERIC(5,4),
    model_name              VARCHAR,
    model_version           VARCHAR,
    confidence_threshold    NUMERIC(5,4),
    threshold_gap           NUMERIC(5,4),
    days_pending            INT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = leaflense, public
AS $$
BEGIN
    PERFORM fn_require_admin_privilege(p_session_token);

    RETURN QUERY
    SELECT
        v.submission_id,
        v.image_path,
        v.farmer_additional_info,
        v.submitted_at,
        v.status,
        v.prediction_id,
        v.predicted_disease_id,
        v.predicted_disease_name,
        v.confidence_score,
        v.model_name,
        v.model_version,
        v.confidence_threshold,
        v.threshold_gap,
        v.days_pending
    FROM v_pending_low_confidence_reviews v;
END;
$$;

ALTER FUNCTION get_pending_low_confidence_submissions(TEXT) OWNER TO leaflense_admin;
GRANT EXECUTE ON FUNCTION get_pending_low_confidence_submissions(TEXT) TO leaflense_admin, leaflense_app;

-- ============================================================================
-- FRONTEND INTEGRATION: FARMER SUBMISSION REPORT VIEW & FUNCTION
-- ----------------------------------------------------------------------------
-- Powers the Farmer Report Lookup field by submission_id (NO login required).
--   • If status is 'pending' or 'low_confidence': returns submission_id and
--     status = 'pending', while prediction, disease, and recommendation fields
--     are all NULL so unverified low-confidence predictions are never exposed.
--   • If status is 'processed': returns the high-confidence AI diagnosis,
--     symptoms, and linked treatment recommendations.
--   • If status is 'reviewed': returns the admin-verified diagnosis
--     (assessed_disease_id), admin notes, symptoms, and recommendations.
-- ============================================================================

DROP VIEW IF EXISTS v_farmer_submission_reports CASCADE;

CREATE OR REPLACE VIEW v_farmer_submission_reports AS
SELECT
    s.submission_id,
    s.image_path,
    s.additional_info,
    s.submitted_at,
    CASE
        WHEN s.status IN ('pending', 'low_confidence') THEN 'pending'
        ELSE s.status::TEXT
    END AS status,
    d.disease_id,
    d.disease_name,
    d.description                                           AS disease_description,
    d.symptoms,
    CASE
        WHEN s.status IN ('processed', 'reviewed') THEN p.confidence_score
        ELSE NULL
    END AS confidence_score,
    CASE
        WHEN s.status IN ('processed', 'reviewed') THEN m.model_name
        ELSE NULL
    END AS model_name,
    CASE
        WHEN s.status IN ('processed', 'reviewed') THEN m.version
        ELSE NULL
    END AS model_version,
    CASE
        WHEN s.status = 'processed' THEN 'ai_model'
        WHEN s.status = 'reviewed'  THEN 'admin_review'
        ELSE NULL
    END AS diagnosis_source,
    CASE
        WHEN s.status = 'reviewed' THEN ar.reviewed_at
        ELSE NULL
    END AS reviewed_at,
    CASE
        WHEN s.status = 'reviewed' THEN ar.notes
        ELSE NULL
    END AS admin_notes,
    rec.recommendations
FROM
    Submissions s
    LEFT JOIN LATERAL (
        SELECT
            p_inner.model_id,
            p_inner.disease_id,
            p_inner.confidence_score
        FROM Predictions p_inner
        WHERE p_inner.submission_id = s.submission_id
          AND p_inner.is_top_prediction = TRUE
        ORDER BY p_inner.predicted_at DESC, p_inner.prediction_id DESC
        LIMIT 1
    ) p ON TRUE
    LEFT JOIN Models m
        ON m.model_id = p.model_id
    LEFT JOIN LATERAL (
        SELECT
            ar_inner.assessed_disease_id,
            ar_inner.notes,
            ar_inner.reviewed_at
        FROM AdminReviews ar_inner
        WHERE ar_inner.submission_id = s.submission_id
        ORDER BY ar_inner.reviewed_at DESC
        LIMIT 1
    ) ar ON TRUE
    LEFT JOIN Diseases d
        ON d.disease_id = CASE
            WHEN s.status = 'reviewed'  THEN ar.assessed_disease_id
            WHEN s.status = 'processed' THEN p.disease_id
            ELSE NULL
        END
    LEFT JOIN LATERAL (
        SELECT
            JSONB_AGG(
                JSONB_BUILD_OBJECT(
                    'recommendation_id', r.recommendation_id,
                    'title',             r.title,
                    'description',       r.description,
                    'source',            r.source
                )
                ORDER BY r.recommendation_id
            ) AS recommendations
        FROM DiseaseRecommendations dr
        INNER JOIN Recommendations r
            ON r.recommendation_id = dr.recommendation_id
        WHERE dr.disease_id = d.disease_id
    ) rec ON d.disease_id IS NOT NULL;

GRANT SELECT ON v_farmer_submission_reports TO leaflense_admin, leaflense_app;

COMMENT ON VIEW v_farmer_submission_reports
    IS 'Returns farmer-facing submission reports; hides predictions and recommendations as NULL with status "pending" until high-confidence processing or admin review completes.';

CREATE OR REPLACE FUNCTION get_farmer_submission_report(p_submission_id INT)
RETURNS TABLE (
    submission_id        INT,
    image_path           VARCHAR,
    additional_info      TEXT,
    submitted_at         TIMESTAMPTZ,
    status               TEXT,
    disease_id           INT,
    disease_name         VARCHAR,
    disease_description  TEXT,
    symptoms             TEXT,
    confidence_score     NUMERIC(5,4),
    model_name           VARCHAR,
    model_version        VARCHAR,
    diagnosis_source     TEXT,
    reviewed_at          TIMESTAMPTZ,
    admin_notes          TEXT,
    recommendations      JSONB
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = leaflense, public
AS $$
    SELECT
        submission_id,
        image_path,
        additional_info,
        submitted_at,
        status,
        disease_id,
        disease_name,
        disease_description,
        symptoms,
        confidence_score,
        model_name,
        model_version,
        diagnosis_source,
        reviewed_at,
        admin_notes,
        recommendations
    FROM v_farmer_submission_reports
    WHERE submission_id = p_submission_id;
$$;

ALTER FUNCTION get_farmer_submission_report(INT) OWNER TO leaflense_admin;
GRANT EXECUTE ON FUNCTION get_farmer_submission_report(INT) TO leaflense_admin, leaflense_app;

COMMENT ON FUNCTION get_farmer_submission_report(INT)
    IS 'Fetches the farmer report for a given submission_id, returning NULL for predictions/recommendations while pending or low_confidence.';


-- ############################################################################
-- PROCEDURES
-- ############################################################################

-- ============================================================================
-- PROCEDURE 1: submit_leaf_sample()
-- ----------------------------------------------------------------------------
-- Creates a new submission record for an uploaded leaf image (NO login needed).
-- Also records the initial status ('pending') in SubmissionStatusHistory.
-- Returns the new submission_id via OUT parameter.
-- ============================================================================

CREATE OR REPLACE PROCEDURE submit_leaf_sample(
    IN  p_image_path       VARCHAR,
    OUT p_submission_id    INT,
    IN  p_additional_info  TEXT        DEFAULT NULL,
    IN  p_ip_address       INET        DEFAULT NULL,
    IN  p_user_agent       TEXT        DEFAULT NULL
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = leaflense, public
AS $$
BEGIN
    IF p_image_path IS NULL OR TRIM(p_image_path) = '' THEN
        RAISE EXCEPTION 'Image path cannot be empty.';
    END IF;

    INSERT INTO Submissions (image_path, status, additional_info, ip_address, user_agent)
    VALUES (p_image_path, 'pending', p_additional_info, p_ip_address, p_user_agent)
    RETURNING submission_id INTO p_submission_id;

    INSERT INTO SubmissionStatusHistory (submission_id, old_status, new_status, changed_by)
    VALUES (p_submission_id, NULL, 'pending', 'system');

    RAISE NOTICE 'Submission % created successfully.', p_submission_id;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Failed to create submission: %', SQLERRM;
END;
$$;

ALTER PROCEDURE submit_leaf_sample(VARCHAR, TEXT, INET, TEXT) OWNER TO leaflense_admin;
GRANT EXECUTE ON PROCEDURE submit_leaf_sample(VARCHAR, TEXT, INET, TEXT) TO leaflense_admin, leaflense_app;

COMMENT ON PROCEDURE submit_leaf_sample(VARCHAR, TEXT, INET, TEXT)
    IS 'Creates a new farmer submission with status "pending" without requiring login.';

-- ============================================================================
-- PROCEDURE 2: record_prediction()
-- ----------------------------------------------------------------------------
-- Stores a model prediction for a submission. When the prediction is marked
-- as the top prediction (is_top_prediction = TRUE), the procedure
-- automatically routes the submission:
--   • confidence >= threshold  →  status = 'processed'
--   • confidence <  threshold  →  status = 'low_confidence'
-- ============================================================================

CREATE OR REPLACE PROCEDURE record_prediction(
    IN p_submission_id      INT,
    IN p_model_id           INT,
    IN p_disease_id         INT,
    IN p_confidence_score   NUMERIC,
    IN p_is_top_prediction  BOOLEAN DEFAULT FALSE
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = leaflense, public
AS $$
DECLARE
    v_current_status    submission_status;
    v_threshold         NUMERIC(5,4);
    v_new_status        submission_status;
    v_prediction_id     INT;
BEGIN
    SELECT status INTO v_current_status
      FROM Submissions
     WHERE submission_id = p_submission_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Submission % does not exist.', p_submission_id;
    END IF;

    IF v_current_status <> 'pending' THEN
        RAISE EXCEPTION 'Submission % has status "%" – predictions can only be added to "pending" submissions.',
            p_submission_id, v_current_status;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM Models WHERE model_id = p_model_id AND is_active = TRUE) THEN
        RAISE EXCEPTION 'Model % does not exist or is not active.', p_model_id;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM Diseases WHERE disease_id = p_disease_id) THEN
        RAISE EXCEPTION 'Disease % does not exist.', p_disease_id;
    END IF;

    IF p_confidence_score < 0 OR p_confidence_score > 1 THEN
        RAISE EXCEPTION 'Confidence score must be between 0 and 1. Received: %', p_confidence_score;
    END IF;

    INSERT INTO Predictions (submission_id, model_id, disease_id, confidence_score, is_top_prediction)
    VALUES (p_submission_id, p_model_id, p_disease_id, p_confidence_score, p_is_top_prediction)
    RETURNING prediction_id INTO v_prediction_id;

    RAISE NOTICE 'Prediction % recorded (confidence: %).', v_prediction_id, p_confidence_score;

    IF p_is_top_prediction = TRUE THEN
        SELECT confidence_threshold INTO v_threshold
          FROM Models
         WHERE model_id = p_model_id;

        IF p_confidence_score >= v_threshold THEN
            v_new_status := 'processed';
        ELSE
            v_new_status := 'low_confidence';
        END IF;

        UPDATE Submissions
           SET status = v_new_status
         WHERE submission_id = p_submission_id;

        INSERT INTO SubmissionStatusHistory (submission_id, old_status, new_status, changed_by)
        VALUES (p_submission_id, 'pending', v_new_status, 'system');

        RAISE NOTICE 'Submission % routed to status "%".', p_submission_id, v_new_status;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Failed to record prediction: %', SQLERRM;
END;
$$;

ALTER PROCEDURE record_prediction(INT, INT, INT, NUMERIC, BOOLEAN) OWNER TO leaflense_admin;
GRANT EXECUTE ON PROCEDURE record_prediction(INT, INT, INT, NUMERIC, BOOLEAN) TO leaflense_admin, leaflense_app;

COMMENT ON PROCEDURE record_prediction(INT, INT, INT, NUMERIC, BOOLEAN)
    IS 'Stores a prediction and auto-routes the submission based on confidence vs threshold.';

-- ============================================================================
-- PROCEDURE 3: review_low_confidence_case()
-- ----------------------------------------------------------------------------
-- Records an admin's assessment of a low-confidence submission.
-- Enforces admin privilege via session token (or leaflense_admin/postgres)
-- and updates the submission status to 'reviewed'.
-- ============================================================================

DROP PROCEDURE IF EXISTS review_low_confidence_case(INT, INT, INT, BOOLEAN, TEXT);
DROP PROCEDURE IF EXISTS review_low_confidence_case(INT, INT, INT, BOOLEAN, TEXT, TEXT);

CREATE OR REPLACE PROCEDURE review_low_confidence_case(
    IN p_submission_id       INT,
    IN p_admin_id            INT     DEFAULT NULL,
    IN p_assessed_disease_id INT     DEFAULT NULL,
    IN p_is_correct          BOOLEAN DEFAULT NULL,
    IN p_notes               TEXT    DEFAULT NULL,
    IN p_session_token       TEXT    DEFAULT NULL
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = leaflense, public
AS $$
DECLARE
    v_auth_admin_id     INT;
    v_effective_admin   INT;
    v_current_status    submission_status;
    v_admin_username    VARCHAR(100);
    v_admin_role        admin_role;
    v_review_id         INT;
BEGIN
    v_auth_admin_id := fn_require_admin_privilege(p_session_token);

    IF v_auth_admin_id IS NOT NULL THEN
        IF p_admin_id IS NOT NULL AND p_admin_id <> v_auth_admin_id THEN
            RAISE EXCEPTION 'Session admin (%) does not match provided p_admin_id (%).', v_auth_admin_id, p_admin_id;
        END IF;
        v_effective_admin := v_auth_admin_id;
    ELSE
        IF p_admin_id IS NULL THEN
            RAISE EXCEPTION 'p_admin_id is required when calling without an admin session token.';
        END IF;
        v_effective_admin := p_admin_id;
    END IF;

    SELECT status INTO v_current_status
      FROM Submissions
     WHERE submission_id = p_submission_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Submission % does not exist.', p_submission_id;
    END IF;

    IF v_current_status <> 'low_confidence' THEN
        RAISE EXCEPTION 'Submission % has status "%" – only "low_confidence" submissions can be reviewed.',
            p_submission_id, v_current_status;
    END IF;

    SELECT username, role
      INTO v_admin_username, v_admin_role
      FROM AdminUsers
     WHERE admin_id = v_effective_admin AND is_active = TRUE;

    IF NOT FOUND OR v_admin_role <> 'admin' THEN
        RAISE EXCEPTION 'Admin % does not exist or is inactive.', v_effective_admin;
    END IF;

    PERFORM set_config('leaflense.current_admin', v_admin_username, true);

    IF p_assessed_disease_id IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM Diseases WHERE disease_id = p_assessed_disease_id) THEN
            RAISE EXCEPTION 'Assessed disease % does not exist.', p_assessed_disease_id;
        END IF;
    END IF;

    INSERT INTO AdminReviews (submission_id, admin_id, assessed_disease_id, is_correct, notes)
    VALUES (p_submission_id, v_effective_admin, p_assessed_disease_id, p_is_correct, p_notes)
    RETURNING review_id INTO v_review_id;

    UPDATE Submissions
       SET status = 'reviewed'
     WHERE submission_id = p_submission_id;

    INSERT INTO SubmissionStatusHistory (submission_id, old_status, new_status, changed_by)
    VALUES (p_submission_id, 'low_confidence', 'reviewed', v_admin_username);

    RAISE NOTICE 'Review % recorded by admin "%" for submission %.', v_review_id, v_admin_username, p_submission_id;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Failed to record review: %', SQLERRM;
END;
$$;

ALTER PROCEDURE review_low_confidence_case(INT, INT, INT, BOOLEAN, TEXT, TEXT) OWNER TO leaflense_admin;
GRANT EXECUTE ON PROCEDURE review_low_confidence_case(INT, INT, INT, BOOLEAN, TEXT, TEXT) TO leaflense_admin, leaflense_app;

COMMENT ON PROCEDURE review_low_confidence_case(INT, INT, INT, BOOLEAN, TEXT, TEXT)
    IS 'Records an admin review for a low-confidence submission and updates its status.';

-- ============================================================================
-- PROCEDURE 4: reject_submission()
-- ----------------------------------------------------------------------------
-- Allows an authenticated admin to reject an invalid, blurry, or duplicate
-- submission (transitions status to 'rejected').
-- ============================================================================

DROP PROCEDURE IF EXISTS reject_submission(INT, TEXT, INT, TEXT);

CREATE OR REPLACE PROCEDURE reject_submission(
    IN p_submission_id  INT,
    IN p_reason         TEXT DEFAULT NULL,
    IN p_admin_id       INT  DEFAULT NULL,
    IN p_session_token  TEXT DEFAULT NULL
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = leaflense, public
AS $$
DECLARE
    v_auth_admin_id     INT;
    v_effective_admin   INT;
    v_current_status    submission_status;
    v_admin_username    VARCHAR(100);
    v_admin_role        admin_role;
BEGIN
    v_auth_admin_id := fn_require_admin_privilege(p_session_token);

    v_effective_admin := COALESCE(v_auth_admin_id, p_admin_id);
    IF v_effective_admin IS NULL THEN
        RAISE EXCEPTION 'Admin identity or session token is required to reject a submission.';
    END IF;

    SELECT username, role
      INTO v_admin_username, v_admin_role
      FROM AdminUsers
     WHERE admin_id = v_effective_admin AND is_active = TRUE;

    IF NOT FOUND OR v_admin_role <> 'admin' THEN
        RAISE EXCEPTION 'Admin % does not exist or is inactive.', v_effective_admin;
    END IF;

    SELECT status INTO v_current_status
      FROM Submissions
     WHERE submission_id = p_submission_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Submission % does not exist.', p_submission_id;
    END IF;

    IF v_current_status NOT IN ('pending', 'low_confidence') THEN
        RAISE EXCEPTION 'Submission % has status "%" and cannot be rejected.', p_submission_id, v_current_status;
    END IF;

    PERFORM set_config('leaflense.current_admin', v_admin_username, true);

    INSERT INTO AdminReviews (submission_id, admin_id, assessed_disease_id, is_correct, notes)
    VALUES (
        p_submission_id,
        v_effective_admin,
        NULL,
        FALSE,
        COALESCE(NULLIF(TRIM(p_reason), ''), 'Submission rejected by administrator.')
    );

    UPDATE Submissions
       SET status = 'rejected'
     WHERE submission_id = p_submission_id;

    INSERT INTO SubmissionStatusHistory (submission_id, old_status, new_status, changed_by)
    VALUES (p_submission_id, v_current_status, 'rejected', v_admin_username);

    RAISE NOTICE 'Submission % rejected by admin "%".', p_submission_id, v_admin_username;
END;
$$;

ALTER PROCEDURE reject_submission(INT, TEXT, INT, TEXT) OWNER TO leaflense_admin;
GRANT EXECUTE ON PROCEDURE reject_submission(INT, TEXT, INT, TEXT) TO leaflense_admin, leaflense_app;

COMMENT ON PROCEDURE reject_submission(INT, TEXT, INT, TEXT)
    IS 'Rejects a pending or low_confidence submission and logs the admin decision.';

-- ============================================================================
-- END OF FILE
-- ============================================================================
