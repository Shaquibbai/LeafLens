-- ============================================================================
-- LeafLense Complete All-in-One Database Setup Script
-- File: leaflense_all_in_one.sql
-- Description: Self-contained setup script designed for pgAdmin Query Tool
--              or psql. Creates schema, types, roles, 11 tables, indexes,
--              functions, procedures, triggers, and seed data in one run.
-- ============================================================================

-- ============================================================================
-- 1. SCHEMA SETUP
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS leaflense;
SET search_path = leaflense, public;

-- Password hashing & cryptographic token generation (crypt, gen_salt, gen_random_bytes, digest)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================================
-- 2. CUSTOM ENUM TYPES
-- ============================================================================
DO $$ BEGIN
    CREATE TYPE submission_status AS ENUM (
        'pending',
        'processed',
        'low_confidence',
        'reviewed',
        'rejected'
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE admin_role AS ENUM (
        'admin'
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE audit_action AS ENUM (
        'INSERT',
        'UPDATE',
        'DELETE',
        'STATUS_CHANGE',
        'BULK_UPDATE',
        'LOGIN',
        'LOGOUT',
        'LOGIN_FAILED'
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'LOGIN';
ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'LOGOUT';
ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'LOGIN_FAILED';

-- ============================================================================
-- 3. ROLES SETUP
-- ============================================================================
DO $$ BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'leaflense_admin') THEN
        CREATE ROLE leaflense_admin LOGIN PASSWORD 'admin_secure_pass';
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'leaflense_app') THEN
        CREATE ROLE leaflense_app LOGIN PASSWORD 'app_secure_pass';
    END IF;
END $$;

-- ============================================================================
-- 4. TABLES (12 TABLES)
-- ============================================================================

CREATE TABLE IF NOT EXISTS AdminUsers (
    admin_id                SERIAL          PRIMARY KEY,
    username                VARCHAR(100)    UNIQUE NOT NULL,
    password_hash           VARCHAR(255)    NOT NULL,
    full_name               VARCHAR(150),
    email                   VARCHAR(255),
    role                    admin_role      NOT NULL DEFAULT 'admin',
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    last_login_at           TIMESTAMPTZ,
    failed_login_attempts   INT             NOT NULL DEFAULT 0,
    locked_until            TIMESTAMPTZ,
    is_active               BOOLEAN         NOT NULL DEFAULT TRUE
);

ALTER TABLE AdminUsers ADD COLUMN IF NOT EXISTS full_name VARCHAR(150);
ALTER TABLE AdminUsers ADD COLUMN IF NOT EXISTS email VARCHAR(255);
ALTER TABLE AdminUsers ADD COLUMN IF NOT EXISTS last_login_at TIMESTAMPTZ;
ALTER TABLE AdminUsers ADD COLUMN IF NOT EXISTS failed_login_attempts INT NOT NULL DEFAULT 0;
ALTER TABLE AdminUsers ADD COLUMN IF NOT EXISTS locked_until TIMESTAMPTZ;

CREATE TABLE IF NOT EXISTS AdminSessions (
    session_id          SERIAL          PRIMARY KEY,
    admin_id            INT             NOT NULL REFERENCES AdminUsers (admin_id) ON DELETE CASCADE,
    token_hash          VARCHAR(64)     UNIQUE NOT NULL,
    ip_address          INET,
    user_agent          TEXT,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    last_activity_at    TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    expires_at          TIMESTAMPTZ     NOT NULL,
    is_revoked          BOOLEAN         NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_admin_sessions_admin ON AdminSessions (admin_id);
CREATE INDEX IF NOT EXISTS idx_admin_sessions_active ON AdminSessions (token_hash) WHERE is_revoked = FALSE;

CREATE TABLE IF NOT EXISTS Models (
    model_id                SERIAL          PRIMARY KEY,
    model_name              VARCHAR(200)    NOT NULL,
    version                 VARCHAR(50)     NOT NULL,
    confidence_threshold    NUMERIC(5,4)    NOT NULL CHECK (confidence_threshold BETWEEN 0 AND 1),
    is_active               BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_model_name_version UNIQUE (model_name, version)
);

CREATE TABLE IF NOT EXISTS Diseases (
    disease_id      SERIAL          PRIMARY KEY,
    disease_name    VARCHAR(200)    UNIQUE NOT NULL,
    description     TEXT,
    symptoms        TEXT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS Submissions (
    submission_id   SERIAL              PRIMARY KEY,
    image_path      VARCHAR(500)        NOT NULL,
    submitted_at    TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
    status          submission_status   NOT NULL DEFAULT 'pending',
    additional_info TEXT,                                       -- Farmer additional info / symptoms description
    ip_address      INET,
    user_agent      TEXT,
    created_at      TIMESTAMPTZ         NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_submissions_status ON Submissions (status);
CREATE INDEX IF NOT EXISTS idx_submissions_submitted_at ON Submissions (submitted_at DESC);

CREATE TABLE IF NOT EXISTS Predictions (
    prediction_id       SERIAL          PRIMARY KEY,
    submission_id       INT             NOT NULL REFERENCES Submissions (submission_id) ON DELETE CASCADE,
    model_id            INT             NOT NULL REFERENCES Models (model_id),
    disease_id          INT             NOT NULL REFERENCES Diseases (disease_id),
    confidence_score    NUMERIC(5,4)    NOT NULL CHECK (confidence_score BETWEEN 0 AND 1),
    predicted_at        TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    is_top_prediction   BOOLEAN         NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_predictions_submission ON Predictions (submission_id);
CREATE INDEX IF NOT EXISTS idx_predictions_confidence ON Predictions (confidence_score);
CREATE INDEX IF NOT EXISTS idx_predictions_model ON Predictions (model_id);

CREATE TABLE IF NOT EXISTS ModelClasses (
    model_class_id  SERIAL          PRIMARY KEY,
    model_id        INT             NOT NULL REFERENCES Models (model_id) ON DELETE CASCADE,
    disease_id      INT             NOT NULL REFERENCES Diseases (disease_id),
    class_label     VARCHAR(100)    NOT NULL,
    CONSTRAINT uq_model_disease UNIQUE (model_id, disease_id)
);

CREATE TABLE IF NOT EXISTS AdminReviews (
    review_id           SERIAL          PRIMARY KEY,
    submission_id       INT             NOT NULL REFERENCES Submissions (submission_id),
    admin_id            INT             NOT NULL REFERENCES AdminUsers (admin_id),
    assessed_disease_id INT             REFERENCES Diseases (disease_id),
    notes               TEXT,
    reviewed_at         TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    is_correct          BOOLEAN
);

CREATE INDEX IF NOT EXISTS idx_reviews_submission ON AdminReviews (submission_id);
CREATE INDEX IF NOT EXISTS idx_reviews_admin ON AdminReviews (admin_id);

CREATE TABLE IF NOT EXISTS Recommendations (
    recommendation_id   SERIAL          PRIMARY KEY,
    title               VARCHAR(300)    NOT NULL,
    description         TEXT            NOT NULL,
    source              VARCHAR(200),
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS DiseaseRecommendations (
    disease_id          INT NOT NULL REFERENCES Diseases (disease_id) ON DELETE CASCADE,
    recommendation_id   INT NOT NULL REFERENCES Recommendations (recommendation_id) ON DELETE CASCADE,
    PRIMARY KEY (disease_id, recommendation_id)
);

CREATE TABLE IF NOT EXISTS SubmissionStatusHistory (
    history_id      SERIAL              PRIMARY KEY,
    submission_id   INT                 NOT NULL REFERENCES Submissions (submission_id) ON DELETE CASCADE,
    old_status      submission_status,
    new_status      submission_status   NOT NULL,
    changed_at      TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
    changed_by      VARCHAR(100)        NOT NULL DEFAULT 'system'
);

CREATE INDEX IF NOT EXISTS idx_status_history_submission ON SubmissionStatusHistory (submission_id);

CREATE TABLE IF NOT EXISTS AuditLogs (
    audit_id        SERIAL          PRIMARY KEY,
    actor           VARCHAR(100)    NOT NULL DEFAULT 'system',
    action          audit_action    NOT NULL,
    table_name      VARCHAR(100)    NOT NULL,
    record_id       INT,
    old_values      JSONB,
    new_values      JSONB,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_table_record ON AuditLogs (table_name, record_id);
CREATE INDEX IF NOT EXISTS idx_audit_created ON AuditLogs (created_at DESC);

-- ============================================================================
-- 5. GRANTS & PERMISSIONS
-- ============================================================================
GRANT USAGE ON SCHEMA leaflense TO leaflense_admin, leaflense_app;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA leaflense TO leaflense_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA leaflense TO leaflense_admin;

GRANT SELECT, INSERT, UPDATE ON Submissions, Predictions, SubmissionStatusHistory, AuditLogs TO leaflense_app;
GRANT SELECT ON Diseases, Models, ModelClasses, Recommendations, DiseaseRecommendations, AdminReviews TO leaflense_app;

-- Protect password_hash and AdminSessions from direct SELECT by app role
REVOKE ALL ON AdminUsers FROM leaflense_app;
GRANT SELECT (admin_id, username, full_name, email, role, created_at, last_login_at, is_active)
    ON AdminUsers TO leaflense_app;
REVOKE ALL ON AdminSessions FROM leaflense_app;

GRANT USAGE ON SEQUENCE submissions_submission_id_seq, predictions_prediction_id_seq, submissionstatushistory_history_id_seq, auditlogs_audit_id_seq TO leaflense_app;

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
-- 5a. FRONTEND INTEGRATION: ADMIN AUTHENTICATION & PRIVILEGE HELPERS
-- ============================================================================

DROP VIEW IF EXISTS v_admin_users_public CASCADE;

CREATE OR REPLACE VIEW v_admin_users_public AS
SELECT admin_id, username, full_name, email, role, is_active, last_login_at, created_at
FROM AdminUsers;

GRANT SELECT ON v_admin_users_public TO leaflense_admin, leaflense_app;

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

        UPDATE AdminSessions SET last_activity_at = NOW() WHERE token_hash = v_token_hash;
        PERFORM set_config('leaflense.current_admin', v_username, true);
        RETURN v_admin_id;
    END IF;

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
        RETURN QUERY SELECT FALSE, NULL::INT, NULL::VARCHAR, NULL::VARCHAR, NULL::admin_role, NULL::JSONB, NULL::TEXT, NULL::TIMESTAMPTZ, 'Username and password are required.'::TEXT;
        RETURN;
    END IF;

    SELECT * INTO v_user FROM AdminUsers u WHERE u.username = v_clean_username;

    IF NOT FOUND THEN
        INSERT INTO AuditLogs (actor, action, table_name, record_id, new_values)
        VALUES (v_clean_username, 'LOGIN_FAILED', 'admin_users', NULL, jsonb_build_object('reason', 'unknown_username', 'ip_address', p_ip_address));
        RETURN QUERY SELECT FALSE, NULL::INT, NULL::VARCHAR, NULL::VARCHAR, NULL::admin_role, NULL::JSONB, NULL::TEXT, NULL::TIMESTAMPTZ, 'Invalid username or password.'::TEXT;
        RETURN;
    END IF;

    IF v_user.is_active = FALSE THEN
        INSERT INTO AuditLogs (actor, action, table_name, record_id, new_values)
        VALUES (v_user.username, 'LOGIN_FAILED', 'admin_users', v_user.admin_id, jsonb_build_object('reason', 'account_inactive', 'ip_address', p_ip_address));
        RETURN QUERY SELECT FALSE, NULL::INT, NULL::VARCHAR, NULL::VARCHAR, NULL::admin_role, NULL::JSONB, NULL::TEXT, NULL::TIMESTAMPTZ, 'Account is deactivated. Contact a super administrator.'::TEXT;
        RETURN;
    END IF;

    IF v_user.locked_until IS NOT NULL AND v_user.locked_until > NOW() THEN
        RETURN QUERY SELECT FALSE, NULL::INT, NULL::VARCHAR, NULL::VARCHAR, NULL::admin_role, NULL::JSONB, NULL::TEXT, NULL::TIMESTAMPTZ, 'Account temporarily locked due to too many failed login attempts. Try again later.'::TEXT;
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
               locked_until = CASE WHEN v_attempts >= 5 THEN NOW() + INTERVAL '15 minutes' ELSE NULL END
         WHERE AdminUsers.admin_id = v_user.admin_id;
        INSERT INTO AuditLogs (actor, action, table_name, record_id, new_values)
        VALUES (v_user.username, 'LOGIN_FAILED', 'admin_users', v_user.admin_id, jsonb_build_object('reason', 'invalid_password', 'attempt', v_attempts, 'ip_address', p_ip_address));
        RETURN QUERY SELECT FALSE, NULL::INT, NULL::VARCHAR, NULL::VARCHAR, NULL::admin_role, NULL::JSONB, NULL::TEXT, NULL::TIMESTAMPTZ, 'Invalid username or password.'::TEXT;
        RETURN;
    END IF;

    UPDATE AdminUsers SET failed_login_attempts = 0, locked_until = NULL, last_login_at = NOW() WHERE AdminUsers.admin_id = v_user.admin_id;

    v_raw_token  := encode(gen_random_bytes(32), 'hex');
    v_token_hash := encode(digest(v_raw_token, 'sha256'), 'hex');
    v_expires_at := NOW() + INTERVAL '12 hours';

    INSERT INTO AdminSessions (admin_id, token_hash, ip_address, user_agent, expires_at)
    VALUES (v_user.admin_id, v_token_hash, p_ip_address, p_user_agent, v_expires_at);

    INSERT INTO AuditLogs (actor, action, table_name, record_id, new_values)
    VALUES (v_user.username, 'LOGIN', 'admin_users', v_user.admin_id, jsonb_build_object('role', v_user.role, 'ip_address', p_ip_address));

    RETURN QUERY SELECT TRUE, v_user.admin_id, v_user.username, v_user.full_name, v_user.role, fn_get_role_privileges(v_user.role), v_raw_token, v_expires_at, 'Login successful.'::TEXT;
END;
$$;

ALTER FUNCTION login_admin(VARCHAR, TEXT, INET, TEXT) OWNER TO leaflense_admin;
GRANT EXECUTE ON FUNCTION login_admin(VARCHAR, TEXT, INET, TEXT) TO leaflense_admin, leaflense_app;

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

    SELECT u.admin_id, u.username, u.full_name, u.role, s.expires_at
      INTO v_rec
      FROM AdminSessions s
      INNER JOIN AdminUsers u ON u.admin_id = s.admin_id
     WHERE s.token_hash = v_token_hash AND s.is_revoked = FALSE AND s.expires_at > NOW() AND u.is_active = TRUE;

    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, NULL::INT, NULL::VARCHAR, NULL::VARCHAR, NULL::admin_role, NULL::JSONB, NULL::TIMESTAMPTZ;
        RETURN;
    END IF;

    UPDATE AdminSessions SET last_activity_at = NOW() WHERE token_hash = v_token_hash;
    RETURN QUERY SELECT TRUE, v_rec.admin_id, v_rec.username, v_rec.full_name, v_rec.role, fn_get_role_privileges(v_rec.role), v_rec.expires_at;
END;
$$;

ALTER FUNCTION verify_admin_session(TEXT) OWNER TO leaflense_admin;
GRANT EXECUTE ON FUNCTION verify_admin_session(TEXT) TO leaflense_admin, leaflense_app;

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

    UPDATE AdminSessions s SET is_revoked = TRUE
      FROM AdminUsers u
     WHERE s.admin_id = u.admin_id AND s.token_hash = v_token_hash AND s.is_revoked = FALSE
     RETURNING s.admin_id, u.username INTO v_admin_id, v_username;

    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;

    INSERT INTO AuditLogs (actor, action, table_name, record_id, new_values)
    VALUES (v_username, 'LOGOUT', 'admin_sessions', v_admin_id, jsonb_build_object('revoked', TRUE));

    RETURN TRUE;
END;
$$;

ALTER FUNCTION logout_admin(TEXT) OWNER TO leaflense_admin;
GRANT EXECUTE ON FUNCTION logout_admin(TEXT) TO leaflense_admin, leaflense_app;

-- ============================================================================

-- ============================================================================
-- 5b. FRONTEND INTEGRATION: PENDING LOW-CONFIDENCE VIEW & FUNCTION
-- ----------------------------------------------------------------------------
-- This view and function power the "Pending Low-Confidence Reviews" tab
-- in the Administrator GUI dashboard.
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
    IS 'Powers the frontend admin dashboard tab showing all pending low-confidence submissions with farmer notes, sorted by lowest score first.';

-- Dedicated function returning the same dataset (admin-privileged)
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
-- 5c. FRONTEND INTEGRATION: FARMER SUBMISSION REPORT VIEW & FUNCTION
-- ----------------------------------------------------------------------------
-- Powers the Farmer Report Lookup field by submission_id.
--   • 'pending' / 'low_confidence' -> status = 'pending', prediction &
--     recommendations = NULL.
--   • 'processed' -> AI prediction, symptoms, and recommendations.
--   • 'reviewed'  -> Admin-assessed disease, notes, symptoms, recommendations.
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

-- ============================================================================
-- 7. PROCEDURES
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
END;
$$;

ALTER PROCEDURE submit_leaf_sample(VARCHAR, TEXT, INET, TEXT) OWNER TO leaflense_admin;
GRANT EXECUTE ON PROCEDURE submit_leaf_sample(VARCHAR, TEXT, INET, TEXT) TO leaflense_admin, leaflense_app;

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
    SELECT status INTO v_current_status FROM Submissions WHERE submission_id = p_submission_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Submission % does not exist.', p_submission_id;
    END IF;

    IF v_current_status <> 'pending' THEN
        RAISE EXCEPTION 'Submission % has status "%" – predictions can only be added to "pending" submissions.', p_submission_id, v_current_status;
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

    IF p_is_top_prediction = TRUE THEN
        SELECT confidence_threshold INTO v_threshold FROM Models WHERE model_id = p_model_id;

        IF p_confidence_score >= v_threshold THEN
            v_new_status := 'processed';
        ELSE
            v_new_status := 'low_confidence';
        END IF;

        UPDATE Submissions SET status = v_new_status WHERE submission_id = p_submission_id;

        INSERT INTO SubmissionStatusHistory (submission_id, old_status, new_status, changed_by)
        VALUES (p_submission_id, 'pending', v_new_status, 'system');
    END IF;
END;
$$;

ALTER PROCEDURE record_prediction(INT, INT, INT, NUMERIC, BOOLEAN) OWNER TO leaflense_admin;
GRANT EXECUTE ON PROCEDURE record_prediction(INT, INT, INT, NUMERIC, BOOLEAN) TO leaflense_admin, leaflense_app;

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

    SELECT status INTO v_current_status FROM Submissions WHERE submission_id = p_submission_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Submission % does not exist.', p_submission_id;
    END IF;

    IF v_current_status <> 'low_confidence' THEN
        RAISE EXCEPTION 'Submission % has status "%" – only "low_confidence" submissions can be reviewed.', p_submission_id, v_current_status;
    END IF;

    SELECT username, role INTO v_admin_username, v_admin_role FROM AdminUsers WHERE admin_id = v_effective_admin AND is_active = TRUE;
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

    UPDATE Submissions SET status = 'reviewed' WHERE submission_id = p_submission_id;

    INSERT INTO SubmissionStatusHistory (submission_id, old_status, new_status, changed_by)
    VALUES (p_submission_id, 'low_confidence', 'reviewed', v_admin_username);
END;
$$;

ALTER PROCEDURE review_low_confidence_case(INT, INT, INT, BOOLEAN, TEXT, TEXT) OWNER TO leaflense_admin;
GRANT EXECUTE ON PROCEDURE review_low_confidence_case(INT, INT, INT, BOOLEAN, TEXT, TEXT) TO leaflense_admin, leaflense_app;

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

    SELECT username, role INTO v_admin_username, v_admin_role FROM AdminUsers WHERE admin_id = v_effective_admin AND is_active = TRUE;
    IF NOT FOUND OR v_admin_role <> 'admin' THEN
        RAISE EXCEPTION 'Admin % does not exist or is inactive.', v_effective_admin;
    END IF;

    SELECT status INTO v_current_status FROM Submissions WHERE submission_id = p_submission_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Submission % does not exist.', p_submission_id; END IF;
    IF v_current_status NOT IN ('pending', 'low_confidence') THEN
        RAISE EXCEPTION 'Submission % has status "%" and cannot be rejected.', p_submission_id, v_current_status;
    END IF;

    PERFORM set_config('leaflense.current_admin', v_admin_username, true);

    INSERT INTO AdminReviews (submission_id, admin_id, assessed_disease_id, is_correct, notes)
    VALUES (p_submission_id, v_effective_admin, NULL, FALSE, COALESCE(NULLIF(TRIM(p_reason), ''), 'Submission rejected by administrator.'));

    UPDATE Submissions SET status = 'rejected' WHERE submission_id = p_submission_id;

    INSERT INTO SubmissionStatusHistory (submission_id, old_status, new_status, changed_by)
    VALUES (p_submission_id, v_current_status, 'rejected', v_admin_username);
END;
$$;

ALTER PROCEDURE reject_submission(INT, TEXT, INT, TEXT) OWNER TO leaflense_admin;
GRANT EXECUTE ON PROCEDURE reject_submission(INT, TEXT, INT, TEXT) TO leaflense_admin, leaflense_app;

-- ============================================================================
-- 8. TRIGGERS
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_validate_prediction()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_model_active BOOLEAN;
BEGIN
    IF NEW.confidence_score < 0 OR NEW.confidence_score > 1 THEN
        RAISE EXCEPTION 'Invalid confidence_score: %. Must be between 0 and 1.', NEW.confidence_score;
    END IF;

    SELECT is_active INTO v_model_active FROM Models WHERE model_id = NEW.model_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Model with ID % does not exist.', NEW.model_id;
    END IF;
    IF v_model_active = FALSE THEN
        RAISE EXCEPTION 'Model % is not active.', NEW.model_id;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM ModelClasses WHERE model_id = NEW.model_id AND disease_id = NEW.disease_id
    ) THEN
        RAISE EXCEPTION 'Disease % is not a supported class for model %.', NEW.disease_id, NEW.model_id;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_prediction ON Predictions;
CREATE TRIGGER trg_validate_prediction
    BEFORE INSERT OR UPDATE ON Predictions
    FOR EACH ROW EXECUTE FUNCTION fn_validate_prediction();

CREATE OR REPLACE FUNCTION fn_audit_submission_changes()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO AuditLogs (actor, action, table_name, record_id, new_values)
        VALUES (COALESCE(NULLIF(current_setting('leaflense.current_admin', true), ''), current_user), 'INSERT', 'submissions', NEW.submission_id, row_to_json(NEW)::JSONB);
    ELSIF TG_OP = 'UPDATE' THEN
        IF OLD.status IS DISTINCT FROM NEW.status THEN
            INSERT INTO AuditLogs (actor, action, table_name, record_id, old_values, new_values)
            VALUES (COALESCE(NULLIF(current_setting('leaflense.current_admin', true), ''), current_user), 'STATUS_CHANGE', 'submissions', NEW.submission_id,
                    jsonb_build_object('status', OLD.status), jsonb_build_object('status', NEW.status));
            IF pg_trigger_depth() <= 1 THEN
                INSERT INTO SubmissionStatusHistory (submission_id, old_status, new_status, changed_by)
                VALUES (NEW.submission_id, OLD.status, NEW.status, COALESCE(NULLIF(current_setting('leaflense.current_admin', true), ''), current_user));
            END IF;
        ELSE
            INSERT INTO AuditLogs (actor, action, table_name, record_id, old_values, new_values)
            VALUES (COALESCE(NULLIF(current_setting('leaflense.current_admin', true), ''), current_user), 'UPDATE', 'submissions', NEW.submission_id, row_to_json(OLD)::JSONB, row_to_json(NEW)::JSONB);
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_submission_changes ON Submissions;
CREATE TRIGGER trg_audit_submission_changes
    AFTER INSERT OR UPDATE ON Submissions
    FOR EACH ROW EXECUTE FUNCTION fn_audit_submission_changes();

CREATE OR REPLACE FUNCTION fn_audit_prediction_insert()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO AuditLogs (actor, action, table_name, record_id, new_values)
    VALUES (COALESCE(NULLIF(current_setting('leaflense.current_admin', true), ''), current_user), 'INSERT', 'predictions', NEW.prediction_id, row_to_json(NEW)::JSONB);
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_prediction_insert ON Predictions;
CREATE TRIGGER trg_audit_prediction_insert
    AFTER INSERT ON Predictions
    FOR EACH ROW EXECUTE FUNCTION fn_audit_prediction_insert();

CREATE OR REPLACE FUNCTION fn_audit_bulk_changes()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_action audit_action;
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_action := CASE WHEN pg_trigger_depth() > 1 THEN 'BULK_UPDATE' ELSE 'INSERT' END;
        INSERT INTO AuditLogs (actor, action, table_name, record_id, new_values)
        VALUES (COALESCE(NULLIF(current_setting('leaflense.current_admin', true), ''), current_user), v_action, 'admin_reviews', NEW.review_id, row_to_json(NEW)::JSONB);
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO AuditLogs (actor, action, table_name, record_id, old_values, new_values)
        VALUES (COALESCE(NULLIF(current_setting('leaflense.current_admin', true), ''), current_user), 'BULK_UPDATE', 'admin_reviews', NEW.review_id, row_to_json(OLD)::JSONB, row_to_json(NEW)::JSONB);
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_bulk_changes ON AdminReviews;
CREATE TRIGGER trg_audit_bulk_changes
    AFTER INSERT OR UPDATE ON AdminReviews
    FOR EACH ROW EXECUTE FUNCTION fn_audit_bulk_changes();

CREATE OR REPLACE FUNCTION fn_update_model_timestamp()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_update_model_timestamp ON Models;
CREATE TRIGGER trg_update_model_timestamp
    BEFORE UPDATE ON Models
    FOR EACH ROW EXECUTE FUNCTION fn_update_model_timestamp();

-- ============================================================================
-- 9. SEED DATA
-- ============================================================================

INSERT INTO AdminUsers (admin_id, username, password_hash, full_name, email, role) VALUES
    (1, 'dr_patel',       crypt('Admin@123',    gen_salt('bf', 12)), 'Dr. Aarav Patel', 'dr.patel@leaflense.org', 'admin'),
    (2, 'agri_expert_01', crypt('Reviewer@123', gen_salt('bf', 12)), 'Maya Lin',        'maya.lin@leaflense.org', 'admin')
ON CONFLICT (admin_id) DO UPDATE
    SET password_hash = EXCLUDED.password_hash,
        full_name     = COALESCE(AdminUsers.full_name, EXCLUDED.full_name),
        email         = COALESCE(AdminUsers.email, EXCLUDED.email),
        role          = 'admin'
  WHERE AdminUsers.password_hash LIKE '%hashed_placeholder%'
     OR AdminUsers.role::TEXT <> 'admin';
DELETE FROM AdminUsers WHERE admin_id = 3 AND username = 'data_analyst';
SELECT setval('adminusers_admin_id_seq', (SELECT COALESCE(MAX(admin_id), 0) FROM AdminUsers));

INSERT INTO Diseases (disease_id, disease_name, description, symptoms) VALUES
    (1, 'Tomato Late Blight',
        'Fungal disease caused by Phytophthora infestans. One of the most destructive diseases affecting tomato and potato crops worldwide.',
        'Dark brown to black water-soaked spots on leaves, white fuzzy growth on undersides, rapid wilting.'),
    (2, 'Tomato Leaf Mold',
        'Caused by the fungus Passalora fulva. Common in greenhouse conditions with high humidity.',
        'Pale green to yellow spots on upper leaf surface, olive-green to grayish-purple velvety mold on undersides.'),
    (3, 'Potato Early Blight',
        'Caused by the fungus Alternaria solani. Affects older leaves first.',
        'Dark concentric rings forming target-like spots on older leaves, yellowing around lesions.'),
    (4, 'Corn Common Rust',
        'Fungal disease caused by Puccinia sorghi. Favoured by moderate temperatures and high humidity.',
        'Small reddish-brown pustules on both upper and lower leaf surfaces, powdery spores.'),
    (5, 'Rice Blast',
        'Caused by the fungus Magnaporthe oryzae. Capable of destroying entire harvests.',
        'Diamond-shaped or elliptical lesions with gray or white centers and brown margins on leaves.'),
    (6, 'Healthy',
        'No disease detected – the leaf appears healthy.',
        'No visible symptoms of disease. Uniform green coloration, intact leaf margins.')
ON CONFLICT (disease_id) DO NOTHING;
SELECT setval('diseases_disease_id_seq', (SELECT COALESCE(MAX(disease_id), 0) FROM Diseases));

INSERT INTO Models (model_id, model_name, version, confidence_threshold, is_active) VALUES
    (1, 'LeafNet-ResNet50',         'v2.1', 0.7500, TRUE),
    (2, 'CropGuard-EfficientNet',   'v1.0', 0.8000, FALSE)
ON CONFLICT (model_id) DO NOTHING;
SELECT setval('models_model_id_seq', (SELECT COALESCE(MAX(model_id), 0) FROM Models));

INSERT INTO ModelClasses (model_class_id, model_id, disease_id, class_label) VALUES
    ( 1, 1, 1, 'tomato_late_blight'),
    ( 2, 1, 2, 'tomato_leaf_mold'),
    ( 3, 1, 3, 'potato_early_blight'),
    ( 4, 1, 4, 'corn_common_rust'),
    ( 5, 1, 5, 'rice_blast'),
    ( 6, 1, 6, 'healthy'),
    ( 7, 2, 1, 'tomato_late_blight'),
    ( 8, 2, 2, 'tomato_leaf_mold'),
    ( 9, 2, 3, 'potato_early_blight'),
    (10, 2, 4, 'corn_common_rust'),
    (11, 2, 5, 'rice_blast'),
    (12, 2, 6, 'healthy')
ON CONFLICT (model_class_id) DO NOTHING;
SELECT setval('modelclasses_model_class_id_seq', (SELECT COALESCE(MAX(model_class_id), 0) FROM ModelClasses));

INSERT INTO Recommendations (recommendation_id, title, description, source) VALUES
    (1, 'Apply Fungicide Treatment', 'Apply a copper-based or systemic fungicide according to label directions.', 'State Agricultural Extension Service'),
    (2, 'Practice Crop Rotation', 'Rotate crops with non-host plants for at least 2-3 years.', 'FAO Crop Management Guidelines'),
    (3, 'Use Resistant Varieties', 'Select and plant disease-resistant cultivars appropriate for your region.', 'International Crop Research Institute'),
    (4, 'Improve Irrigation Management', 'Avoid overhead irrigation that wets foliage. Use drip irrigation.', 'USDA Water Management Bulletin'),
    (5, 'Remove and Destroy Infected Plants', 'Promptly remove infected plant material and destroy it by burning or deep burial.', 'Plant Pathology Handbook'),
    (6, 'Improve Air Circulation', 'Space plants adequately and prune lower branches to improve airflow.', 'Greenhouse Management Best Practices'),
    (7, 'Apply Soil Treatment', 'Treat soil with approved soil fumigants or bio-fungicides before planting.', 'Soil Health Institute Recommendations'),
    (8, 'Consult Local Extension Service', 'Contact your local agricultural extension office for region-specific advice.', 'National Agricultural Advisory Service')
ON CONFLICT (recommendation_id) DO NOTHING;
SELECT setval('recommendations_recommendation_id_seq', (SELECT COALESCE(MAX(recommendation_id), 0) FROM Recommendations));

INSERT INTO DiseaseRecommendations (disease_id, recommendation_id) VALUES
    (1, 1), (1, 3), (1, 5),
    (2, 6), (2, 4), (2, 1),
    (3, 2), (3, 1), (3, 7),
    (4, 3), (4, 1),
    (5, 3), (5, 4), (5, 8),
    (6, 8)
ON CONFLICT DO NOTHING;

INSERT INTO Submissions (submission_id, image_path, submitted_at, status, ip_address, user_agent) VALUES
    (1, '/uploads/2026/11/leaf_001.jpg', NOW() - INTERVAL '28 days', 'processed', '192.168.1.10', 'Mozilla/5.0 (Android; Mobile)'),
    (2, '/uploads/2026/11/leaf_002.jpg', NOW() - INTERVAL '25 days', 'processed', '10.0.0.45',    'LeafLense-Mobile/1.2'),
    (3, '/uploads/2026/11/leaf_003.jpg', NOW() - INTERVAL '20 days', 'processed', '172.16.0.88',  'Mozilla/5.0 (iPhone; Safari)'),
    (4, '/uploads/2026/11/leaf_004.jpg', NOW() - INTERVAL '15 days', 'low_confidence', '192.168.2.20', 'LeafLense-Mobile/1.2'),
    (5, '/uploads/2026/11/leaf_005.jpg', NOW() - INTERVAL '10 days', 'low_confidence', '10.0.1.100',   'Mozilla/5.0 (Linux; Chrome)'),
    (6, '/uploads/2026/11/leaf_006.jpg', NOW() - INTERVAL '7 days',  'low_confidence', '192.168.3.5',  'Mozilla/5.0 (Windows; Edge)'),
    (7, '/uploads/2026/11/leaf_007.jpg', NOW() - INTERVAL '5 days',  'reviewed', '10.0.2.200',   'LeafLense-Mobile/1.3'),
    (8, '/uploads/2026/11/leaf_008.jpg', NOW() - INTERVAL '1 day',   'pending', '192.168.1.55', 'Mozilla/5.0 (Android; Chrome)')
ON CONFLICT (submission_id) DO NOTHING;
SELECT setval('submissions_submission_id_seq', (SELECT COALESCE(MAX(submission_id), 0) FROM Submissions));

INSERT INTO Predictions (prediction_id, submission_id, model_id, disease_id, confidence_score, predicted_at, is_top_prediction) VALUES
    ( 1, 1, 1, 1, 0.9230, NOW() - INTERVAL '28 days', TRUE),
    ( 2, 1, 1, 6, 0.0770, NOW() - INTERVAL '28 days', FALSE),
    ( 3, 2, 1, 6, 0.8850, NOW() - INTERVAL '25 days', TRUE),
    ( 4, 3, 1, 4, 0.8100, NOW() - INTERVAL '20 days', TRUE),
    ( 5, 4, 1, 3, 0.5500, NOW() - INTERVAL '15 days', TRUE),
    ( 6, 4, 1, 1, 0.4500, NOW() - INTERVAL '15 days', FALSE),
    ( 7, 5, 1, 5, 0.6200, NOW() - INTERVAL '10 days', TRUE),
    ( 8, 6, 1, 2, 0.4800, NOW() - INTERVAL '7 days',  TRUE),
    ( 9, 7, 1, 1, 0.6900, NOW() - INTERVAL '5 days',  TRUE),
    (10, 3, 1, 6, 0.1900, NOW() - INTERVAL '20 days', FALSE)
ON CONFLICT (prediction_id) DO NOTHING;
SELECT setval('predictions_prediction_id_seq', (SELECT COALESCE(MAX(prediction_id), 0) FROM Predictions));

INSERT INTO AdminReviews (review_id, submission_id, admin_id, assessed_disease_id, is_correct, notes, reviewed_at) VALUES
    (1, 7, 2, 1, TRUE, 'Visual inspection confirms late blight infection.', NOW() - INTERVAL '4 days'),
    (2, 4, 2, 1, FALSE, 'Misclassification: leaf shows late blight symptoms rather than early blight.', NOW() - INTERVAL '3 days')
ON CONFLICT (review_id) DO NOTHING;
SELECT setval('adminreviews_review_id_seq', (SELECT COALESCE(MAX(review_id), 0) FROM AdminReviews));

INSERT INTO SubmissionStatusHistory (history_id, submission_id, old_status, new_status, changed_at, changed_by) VALUES
    ( 1, 1, NULL,              'pending',          NOW() - INTERVAL '28 days', 'system'),
    ( 2, 1, 'pending',         'processed',        NOW() - INTERVAL '28 days', 'system'),
    ( 3, 2, NULL,              'pending',          NOW() - INTERVAL '25 days', 'system'),
    ( 4, 2, 'pending',         'processed',        NOW() - INTERVAL '25 days', 'system'),
    ( 5, 3, NULL,              'pending',          NOW() - INTERVAL '20 days', 'system'),
    ( 6, 3, 'pending',         'processed',        NOW() - INTERVAL '20 days', 'system'),
    ( 7, 4, NULL,              'pending',          NOW() - INTERVAL '15 days', 'system'),
    ( 8, 4, 'pending',         'low_confidence',   NOW() - INTERVAL '15 days', 'system'),
    ( 9, 5, NULL,              'pending',          NOW() - INTERVAL '10 days', 'system'),
    (10, 5, 'pending',         'low_confidence',   NOW() - INTERVAL '10 days', 'system'),
    (11, 6, NULL,              'pending',          NOW() - INTERVAL '7 days',  'system'),
    (12, 6, 'pending',         'low_confidence',   NOW() - INTERVAL '7 days',  'system'),
    (13, 7, NULL,              'pending',          NOW() - INTERVAL '5 days',  'system'),
    (14, 7, 'pending',         'low_confidence',   NOW() - INTERVAL '5 days',  'system'),
    (15, 7, 'low_confidence',  'reviewed',         NOW() - INTERVAL '4 days',  'agri_expert_01'),
    (16, 8, NULL,              'pending',          NOW() - INTERVAL '1 day',   'system')
ON CONFLICT (history_id) DO NOTHING;
SELECT setval('submissionstatushistory_history_id_seq', (SELECT COALESCE(MAX(history_id), 0) FROM SubmissionStatusHistory));

-- ============================================================================
-- SETUP COMPLETED
-- ============================================================================
