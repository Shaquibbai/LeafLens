-- ============================================================================
-- LeafLense Database – Schema Definition
-- File: 01_schema.sql
-- Description: Creates the database, schema, custom types, roles, all 11
--              tables with constraints and indexes, and grants permissions.
-- ============================================================================

-- ============================================================================
-- 1. SCHEMA & SEARCH PATH
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS leaflense;
SET search_path = leaflense, public;

-- Password hashing & cryptographic token generation (crypt, gen_salt, gen_random_bytes, digest)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================================
-- 2. CUSTOM ENUM TYPES
-- ============================================================================

-- Status lifecycle for leaf-image submissions
DO $$ BEGIN
    CREATE TYPE submission_status AS ENUM (
        'pending',          -- just uploaded, not yet processed
        'processed',        -- model returned a high-confidence prediction
        'low_confidence',   -- model returned a prediction below threshold
        'reviewed',         -- an admin has reviewed the low-confidence case
        'rejected'          -- submission rejected (bad image, duplicate, etc.)
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Role assignable to administrative users (only 'admin')
DO $$ BEGIN
    CREATE TYPE admin_role AS ENUM (
        'admin'             -- reviews low-confidence submissions
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Actions recorded in the audit log
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

-- Ensure auth audit actions exist when upgrading an existing schema
ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'LOGIN';
ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'LOGOUT';
ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'LOGIN_FAILED';

-- ============================================================================
-- 3. DATABASE ROLES
-- ============================================================================

-- leaflense_admin – full access (DDL + DML)
DO $$ BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'leaflense_admin') THEN
        CREATE ROLE leaflense_admin LOGIN PASSWORD 'admin_secure_pass';
    END IF;
END $$;

-- leaflense_app – application-level DML on selected tables
DO $$ BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'leaflense_app') THEN
        CREATE ROLE leaflense_app LOGIN PASSWORD 'app_secure_pass';
    END IF;
END $$;

-- ============================================================================
-- 4. TABLE DEFINITIONS
-- ============================================================================

-- ============================================================================
-- 4a. AdminUsers – administrators who review low-confidence cases
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

-- Idempotent column upgrades for existing installations
ALTER TABLE AdminUsers ADD COLUMN IF NOT EXISTS full_name VARCHAR(150);
ALTER TABLE AdminUsers ADD COLUMN IF NOT EXISTS email VARCHAR(255);
ALTER TABLE AdminUsers ADD COLUMN IF NOT EXISTS last_login_at TIMESTAMPTZ;
ALTER TABLE AdminUsers ADD COLUMN IF NOT EXISTS failed_login_attempts INT NOT NULL DEFAULT 0;
ALTER TABLE AdminUsers ADD COLUMN IF NOT EXISTS locked_until TIMESTAMPTZ;

COMMENT ON TABLE  AdminUsers                        IS 'Platform administrators who can log in and review low-confidence submissions.';
COMMENT ON COLUMN AdminUsers.admin_id               IS 'Auto-generated primary key.';
COMMENT ON COLUMN AdminUsers.username               IS 'Unique login name.';
COMMENT ON COLUMN AdminUsers.password_hash          IS 'Bcrypt hash of the password (compatible with pgcrypto crypt/gen_salt).';
COMMENT ON COLUMN AdminUsers.full_name              IS 'Display name shown in the admin dashboard after login.';
COMMENT ON COLUMN AdminUsers.email                  IS 'Optional administrator contact email.';
COMMENT ON COLUMN AdminUsers.role                   IS 'Administrative role: admin.';
COMMENT ON COLUMN AdminUsers.last_login_at          IS 'Timestamp of the most recent successful admin login.';
COMMENT ON COLUMN AdminUsers.failed_login_attempts  IS 'Consecutive failed login count used for temporary lockout.';
COMMENT ON COLUMN AdminUsers.locked_until           IS 'Temporary lockout expiry timestamp after repeated failed logins.';
COMMENT ON COLUMN AdminUsers.is_active              IS 'Soft-delete flag; FALSE disables login.';

-- ============================================================================
-- 4a-2. AdminSessions – active authenticated admin sessions
-- ============================================================================
CREATE TABLE IF NOT EXISTS AdminSessions (
    session_id          SERIAL          PRIMARY KEY,
    admin_id            INT             NOT NULL
                        REFERENCES AdminUsers (admin_id) ON DELETE CASCADE,
    token_hash          VARCHAR(64)     UNIQUE NOT NULL,
    ip_address          INET,
    user_agent          TEXT,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    last_activity_at    TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    expires_at          TIMESTAMPTZ     NOT NULL,
    is_revoked          BOOLEAN         NOT NULL DEFAULT FALSE
);

COMMENT ON TABLE  AdminSessions             IS 'Server-side session tokens issued when an admin logs in via username/password.';
COMMENT ON COLUMN AdminSessions.token_hash  IS 'SHA-256 hex digest of the opaque session token returned to the client.';
COMMENT ON COLUMN AdminSessions.expires_at  IS 'Session expiration timestamp.';
COMMENT ON COLUMN AdminSessions.is_revoked  IS 'TRUE when the admin logs out or the session is invalidated.';

CREATE INDEX IF NOT EXISTS idx_admin_sessions_admin
    ON AdminSessions (admin_id);
CREATE INDEX IF NOT EXISTS idx_admin_sessions_active
    ON AdminSessions (token_hash)
    WHERE is_revoked = FALSE;

-- ============================================================================
-- 4b. Models – ML models used for leaf disease classification
-- ============================================================================
CREATE TABLE IF NOT EXISTS Models (
    model_id                SERIAL          PRIMARY KEY,
    model_name              VARCHAR(200)    NOT NULL,
    version                 VARCHAR(50)     NOT NULL,
    confidence_threshold    NUMERIC(5,4)    NOT NULL
                            CHECK (confidence_threshold BETWEEN 0 AND 1),
    is_active               BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_model_name_version UNIQUE (model_name, version)
);

COMMENT ON TABLE  Models                          IS 'Registry of image-classification models.';
COMMENT ON COLUMN Models.confidence_threshold     IS 'Minimum confidence score to auto-accept a prediction (0-1).';
COMMENT ON COLUMN Models.is_active                IS 'Only active models are used for new predictions.';

-- ============================================================================
-- 4c. Diseases – known crop diseases the system can identify
-- ============================================================================
CREATE TABLE IF NOT EXISTS Diseases (
    disease_id      SERIAL          PRIMARY KEY,
    disease_name    VARCHAR(200)    UNIQUE NOT NULL,
    description     TEXT,
    symptoms        TEXT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  Diseases              IS 'Catalogue of crop diseases (includes "Healthy" as a class).';
COMMENT ON COLUMN Diseases.symptoms     IS 'Visible symptoms description shown to farmers.';

-- ============================================================================
-- 4d. Submissions – leaf images uploaded by farmers
-- ============================================================================
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

COMMENT ON TABLE  Submissions                  IS 'Each row represents one leaf-image upload.';
COMMENT ON COLUMN Submissions.image_path       IS 'Server-side file path or object-storage key.';
COMMENT ON COLUMN Submissions.status           IS 'Current lifecycle state of the submission.';
COMMENT ON COLUMN Submissions.additional_info   IS 'Farmer provided notes, observations, or crop details.';
COMMENT ON COLUMN Submissions.ip_address       IS 'IP address of the uploader (privacy-anonymised as needed).';

CREATE INDEX IF NOT EXISTS idx_submissions_status
    ON Submissions (status);
CREATE INDEX IF NOT EXISTS idx_submissions_submitted_at
    ON Submissions (submitted_at DESC);

-- ============================================================================
-- 4e. Predictions – model outputs for each submission
-- ============================================================================
CREATE TABLE IF NOT EXISTS Predictions (
    prediction_id       SERIAL          PRIMARY KEY,
    submission_id       INT             NOT NULL
                        REFERENCES Submissions (submission_id) ON DELETE CASCADE,
    model_id            INT             NOT NULL
                        REFERENCES Models (model_id),
    disease_id          INT             NOT NULL
                        REFERENCES Diseases (disease_id),
    confidence_score    NUMERIC(5,4)    NOT NULL
                        CHECK (confidence_score BETWEEN 0 AND 1),
    predicted_at        TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    is_top_prediction   BOOLEAN         NOT NULL DEFAULT FALSE
);

COMMENT ON TABLE  Predictions                       IS 'One or more disease predictions per submission.';
COMMENT ON COLUMN Predictions.confidence_score       IS 'Model confidence for this class (0-1).';
COMMENT ON COLUMN Predictions.is_top_prediction      IS 'TRUE for the highest-confidence prediction per submission.';

CREATE INDEX IF NOT EXISTS idx_predictions_submission
    ON Predictions (submission_id);
CREATE INDEX IF NOT EXISTS idx_predictions_confidence
    ON Predictions (confidence_score);
CREATE INDEX IF NOT EXISTS idx_predictions_model
    ON Predictions (model_id);

-- ============================================================================
-- 4f. ModelClasses – M:N bridge between Models and Diseases
-- ============================================================================
CREATE TABLE IF NOT EXISTS ModelClasses (
    model_class_id  SERIAL          PRIMARY KEY,
    model_id        INT             NOT NULL
                    REFERENCES Models (model_id) ON DELETE CASCADE,
    disease_id      INT             NOT NULL
                    REFERENCES Diseases (disease_id),
    class_label     VARCHAR(100)    NOT NULL,

    CONSTRAINT uq_model_disease UNIQUE (model_id, disease_id)
);

COMMENT ON TABLE  ModelClasses              IS 'Maps each model to the disease classes it can predict.';
COMMENT ON COLUMN ModelClasses.class_label  IS 'Internal label string used by the model (e.g., tomato_late_blight).';

-- ============================================================================
-- 4g. AdminReviews – administrator assessments of submissions
-- ============================================================================
CREATE TABLE IF NOT EXISTS AdminReviews (
    review_id           SERIAL          PRIMARY KEY,
    submission_id       INT             NOT NULL
                        REFERENCES Submissions (submission_id),
    admin_id            INT             NOT NULL
                        REFERENCES AdminUsers (admin_id),
    assessed_disease_id INT             -- nullable: admin may mark as "uncertain"
                        REFERENCES Diseases (disease_id),
    notes               TEXT,
    reviewed_at         TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    is_correct          BOOLEAN         -- NULL until admin explicitly confirms/denies
);

COMMENT ON TABLE  AdminReviews                       IS 'Manual review records for low-confidence predictions.';
COMMENT ON COLUMN AdminReviews.assessed_disease_id   IS 'Disease the admin believes is correct (NULL if uncertain).';
COMMENT ON COLUMN AdminReviews.is_correct            IS 'Whether the original model prediction was correct.';

CREATE INDEX IF NOT EXISTS idx_reviews_submission
    ON AdminReviews (submission_id);
CREATE INDEX IF NOT EXISTS idx_reviews_admin
    ON AdminReviews (admin_id);

-- ============================================================================
-- 4h. Recommendations – treatment / management advice
-- ============================================================================
CREATE TABLE IF NOT EXISTS Recommendations (
    recommendation_id   SERIAL          PRIMARY KEY,
    title               VARCHAR(300)    NOT NULL,
    description         TEXT            NOT NULL,
    source              VARCHAR(200),
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  Recommendations           IS 'Agricultural recommendations shown to farmers per disease.';
COMMENT ON COLUMN Recommendations.source    IS 'Citation or origin of the recommendation (e.g., university extension).';

-- ============================================================================
-- 4i. DiseaseRecommendations – M:N bridge between Diseases and Recommendations
-- ============================================================================
CREATE TABLE IF NOT EXISTS DiseaseRecommendations (
    disease_id          INT NOT NULL
                        REFERENCES Diseases (disease_id) ON DELETE CASCADE,
    recommendation_id   INT NOT NULL
                        REFERENCES Recommendations (recommendation_id) ON DELETE CASCADE,

    PRIMARY KEY (disease_id, recommendation_id)
);

COMMENT ON TABLE DiseaseRecommendations IS 'Many-to-many link between diseases and their recommendations.';

-- ============================================================================
-- 4j. SubmissionStatusHistory – audit trail of status transitions
-- ============================================================================
CREATE TABLE IF NOT EXISTS SubmissionStatusHistory (
    history_id      SERIAL              PRIMARY KEY,
    submission_id   INT                 NOT NULL
                    REFERENCES Submissions (submission_id) ON DELETE CASCADE,
    old_status      submission_status,                       -- NULL for initial insert
    new_status      submission_status   NOT NULL,
    changed_at      TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
    changed_by      VARCHAR(100)        NOT NULL DEFAULT 'system'
);

COMMENT ON TABLE  SubmissionStatusHistory               IS 'Tracks every status transition for a submission.';
COMMENT ON COLUMN SubmissionStatusHistory.old_status    IS 'Previous status (NULL when the submission is first created).';
COMMENT ON COLUMN SubmissionStatusHistory.changed_by    IS 'Username or "system" that triggered the change.';

CREATE INDEX IF NOT EXISTS idx_status_history_submission
    ON SubmissionStatusHistory (submission_id);

-- ============================================================================
-- 4k. AuditLogs – general-purpose audit trail
-- ============================================================================
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

COMMENT ON TABLE  AuditLogs             IS 'Immutable log of data-changing operations across all tables.';
COMMENT ON COLUMN AuditLogs.old_values  IS 'JSON snapshot of the row before the change.';
COMMENT ON COLUMN AuditLogs.new_values  IS 'JSON snapshot of the row after the change.';

CREATE INDEX IF NOT EXISTS idx_audit_table_record
    ON AuditLogs (table_name, record_id);
CREATE INDEX IF NOT EXISTS idx_audit_created
    ON AuditLogs (created_at DESC);

-- ============================================================================
-- 5. GRANT PERMISSIONS
-- ============================================================================

-- Schema-level access
GRANT USAGE ON SCHEMA leaflense TO leaflense_admin, leaflense_app;

-- ---- leaflense_admin: full access ----
GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA leaflense TO leaflense_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA leaflense TO leaflense_admin;

-- ---- leaflense_app: application-level DML on selected tables ----
GRANT SELECT, INSERT, UPDATE
    ON Submissions, Predictions, SubmissionStatusHistory, AuditLogs
    TO leaflense_app;

GRANT SELECT
    ON Diseases, Models, ModelClasses, Recommendations,
       DiseaseRecommendations, AdminReviews
    TO leaflense_app;

-- Protect password_hash from direct SELECT by the application role;
-- authentication runs through SECURITY DEFINER functions (login_admin, verify_admin_session).
REVOKE ALL ON AdminUsers FROM leaflense_app;
GRANT SELECT (admin_id, username, full_name, email, role, created_at, last_login_at, is_active)
    ON AdminUsers TO leaflense_app;

REVOKE ALL ON AdminSessions FROM leaflense_app;

GRANT USAGE ON SEQUENCE submissions_submission_id_seq,
                        predictions_prediction_id_seq,
                        submissionstatushistory_history_id_seq,
                        auditlogs_audit_id_seq
    TO leaflense_app;

-- Future tables inherit the same grants
ALTER DEFAULT PRIVILEGES IN SCHEMA leaflense
    GRANT ALL ON TABLES TO leaflense_admin;

-- ============================================================================
-- END OF FILE
-- ============================================================================
