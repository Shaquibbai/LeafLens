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
        'super_admin',
        'reviewer',
        'analyst'
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE audit_action AS ENUM (
        'INSERT',
        'UPDATE',
        'DELETE',
        'STATUS_CHANGE',
        'BULK_UPDATE'
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

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

DO $$ BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'leaflense_readonly') THEN
        CREATE ROLE leaflense_readonly LOGIN PASSWORD 'readonly_pass';
    END IF;
END $$;

-- ============================================================================
-- 4. TABLES (11 TABLES)
-- ============================================================================

CREATE TABLE IF NOT EXISTS AdminUsers (
    admin_id        SERIAL          PRIMARY KEY,
    username        VARCHAR(100)    UNIQUE NOT NULL,
    password_hash   VARCHAR(255)    NOT NULL,
    role            admin_role      NOT NULL DEFAULT 'reviewer',
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE
);

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
GRANT USAGE ON SCHEMA leaflense TO leaflense_admin, leaflense_app, leaflense_readonly;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA leaflense TO leaflense_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA leaflense TO leaflense_admin;

GRANT SELECT, INSERT, UPDATE ON Submissions, Predictions, SubmissionStatusHistory, AuditLogs TO leaflense_app;
GRANT SELECT ON Diseases, Models, ModelClasses, Recommendations, DiseaseRecommendations, AdminUsers, AdminReviews TO leaflense_app;
GRANT USAGE ON SEQUENCE submissions_submission_id_seq, predictions_prediction_id_seq, submissionstatushistory_history_id_seq, auditlogs_audit_id_seq TO leaflense_app;

GRANT SELECT ON ALL TABLES IN SCHEMA leaflense TO leaflense_readonly;

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

GRANT SELECT ON v_pending_low_confidence_reviews TO leaflense_admin, leaflense_app, leaflense_readonly;

COMMENT ON VIEW v_pending_low_confidence_reviews
    IS 'Powers the frontend admin dashboard tab showing all pending low-confidence submissions with farmer notes, sorted by lowest score first.';

-- Dedicated function returning the same dataset (for backends that call functions)
CREATE OR REPLACE FUNCTION get_pending_low_confidence_submissions()
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
LANGUAGE sql
SECURITY DEFINER
SET search_path = leaflense, public
AS $$
    SELECT
        submission_id,
        image_path,
        farmer_additional_info,
        submitted_at,
        status,
        prediction_id,
        predicted_disease_id,
        predicted_disease_name,
        confidence_score,
        model_name,
        model_version,
        confidence_threshold,
        threshold_gap,
        days_pending
    FROM v_pending_low_confidence_reviews;
$$;

GRANT EXECUTE ON FUNCTION get_pending_low_confidence_submissions() TO leaflense_admin, leaflense_app, leaflense_readonly;

-- ============================================================================
-- 6. FUNCTIONS (ADMIN-RESTRICTED)
-- ============================================================================
CREATE OR REPLACE FUNCTION get_active_confidence_threshold()
RETURNS NUMERIC(5,4)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = leaflense, public
AS $$
DECLARE
    v_threshold NUMERIC(5,4);
BEGIN
    IF NOT pg_has_role(current_user, 'leaflense_admin', 'MEMBER')
       AND current_user <> 'leaflense_admin'
       AND current_user <> 'postgres' THEN
        RAISE EXCEPTION 'Access denied: admin role required. Current user: %', current_user;
    END IF;

    SELECT MIN(confidence_threshold) INTO v_threshold
      FROM Models
     WHERE is_active = TRUE;

    IF v_threshold IS NULL THEN
        RAISE EXCEPTION 'No active model found. Please activate a model first.';
    END IF;

    RETURN v_threshold;
END;
$$;

CREATE OR REPLACE FUNCTION calculate_model_performance(p_model_id INT)
RETURNS TABLE (
    total_predictions       BIGINT,
    verified_predictions    BIGINT,
    correct_predictions     BIGINT,
    accuracy                NUMERIC(5,2),
    avg_confidence          NUMERIC(5,4)
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = leaflense, public
AS $$
BEGIN
    IF NOT pg_has_role(current_user, 'leaflense_admin', 'MEMBER')
       AND current_user <> 'leaflense_admin'
       AND current_user <> 'postgres' THEN
        RAISE EXCEPTION 'Access denied: admin role required. Current user: %', current_user;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM Models WHERE model_id = p_model_id) THEN
        RAISE EXCEPTION 'Model with ID % does not exist.', p_model_id;
    END IF;

    RETURN QUERY
    SELECT
        COUNT(*)::BIGINT                                            AS total_predictions,
        COUNT(ar.review_id)::BIGINT                                 AS verified_predictions,
        COUNT(CASE WHEN ar.is_correct = TRUE THEN 1 END)::BIGINT   AS correct_predictions,
        CASE
            WHEN COUNT(ar.review_id) = 0 THEN 0.00
            ELSE ROUND(
                COUNT(CASE WHEN ar.is_correct = TRUE THEN 1 END)::NUMERIC
                / COUNT(ar.review_id) * 100,
                2
            )
        END                                                         AS accuracy,
        ROUND(AVG(p.confidence_score), 4)                           AS avg_confidence
    FROM Predictions p
    LEFT JOIN AdminReviews ar ON ar.submission_id = p.submission_id
    WHERE p.model_id = p_model_id
      AND p.is_top_prediction = TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION get_disease_statistics(
    p_start_date TIMESTAMPTZ DEFAULT NULL,
    p_end_date   TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE (
    disease_id              INT,
    disease_name            VARCHAR,
    total_cases             BIGINT,
    avg_confidence          NUMERIC(5,4),
    high_confidence_cases   BIGINT,
    low_confidence_cases    BIGINT,
    reviewed_cases          BIGINT,
    first_detected          TIMESTAMPTZ,
    last_detected           TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = leaflense, public
AS $$
DECLARE
    v_threshold NUMERIC(5,4);
BEGIN
    IF NOT pg_has_role(current_user, 'leaflense_admin', 'MEMBER')
       AND current_user <> 'leaflense_admin'
       AND current_user <> 'postgres' THEN
        RAISE EXCEPTION 'Access denied: admin role required. Current user: %', current_user;
    END IF;

    SELECT MIN(confidence_threshold) INTO v_threshold
      FROM Models
     WHERE is_active = TRUE;

    IF v_threshold IS NULL THEN
        v_threshold := 0.7500;
    END IF;

    RETURN QUERY
    SELECT
        d.disease_id,
        d.disease_name,
        COUNT(*)::BIGINT                        AS total_cases,
        ROUND(AVG(p.confidence_score), 4)       AS avg_confidence,
        COUNT(*) FILTER (WHERE p.confidence_score >= v_threshold)::BIGINT AS high_confidence_cases,
        COUNT(*) FILTER (WHERE p.confidence_score < v_threshold)::BIGINT  AS low_confidence_cases,
        COUNT(DISTINCT ar.review_id)::BIGINT    AS reviewed_cases,
        MIN(p.predicted_at)                     AS first_detected,
        MAX(p.predicted_at)                     AS last_detected
    FROM Predictions p
    INNER JOIN Diseases d ON d.disease_id = p.disease_id
    LEFT JOIN AdminReviews ar ON ar.submission_id = p.submission_id
    WHERE p.is_top_prediction = TRUE
      AND (p_start_date IS NULL OR p.predicted_at >= p_start_date)
      AND (p_end_date   IS NULL OR p.predicted_at <= p_end_date)
    GROUP BY d.disease_id, d.disease_name
    ORDER BY total_cases DESC;
END;
$$;

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

CREATE OR REPLACE PROCEDURE record_prediction(
    IN p_submission_id      INT,
    IN p_model_id           INT,
    IN p_disease_id         INT,
    IN p_confidence_score   NUMERIC,
    IN p_is_top_prediction  BOOLEAN DEFAULT FALSE
)
LANGUAGE plpgsql
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

CREATE OR REPLACE PROCEDURE review_low_confidence_case(
    IN p_submission_id       INT,
    IN p_admin_id            INT,
    IN p_assessed_disease_id INT     DEFAULT NULL,
    IN p_is_correct          BOOLEAN DEFAULT NULL,
    IN p_notes               TEXT    DEFAULT NULL
)
LANGUAGE plpgsql
SET search_path = leaflense, public
AS $$
DECLARE
    v_current_status    submission_status;
    v_admin_username    VARCHAR(100);
    v_review_id         INT;
BEGIN
    SELECT status INTO v_current_status FROM Submissions WHERE submission_id = p_submission_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Submission % does not exist.', p_submission_id;
    END IF;

    IF v_current_status <> 'low_confidence' THEN
        RAISE EXCEPTION 'Submission % has status "%" – only "low_confidence" submissions can be reviewed.', p_submission_id, v_current_status;
    END IF;

    SELECT username INTO v_admin_username FROM AdminUsers WHERE admin_id = p_admin_id AND is_active = TRUE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Admin % does not exist or is inactive.', p_admin_id;
    END IF;

    IF p_assessed_disease_id IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM Diseases WHERE disease_id = p_assessed_disease_id) THEN
            RAISE EXCEPTION 'Assessed disease % does not exist.', p_assessed_disease_id;
        END IF;
    END IF;

    INSERT INTO AdminReviews (submission_id, admin_id, assessed_disease_id, is_correct, notes)
    VALUES (p_submission_id, p_admin_id, p_assessed_disease_id, p_is_correct, p_notes)
    RETURNING review_id INTO v_review_id;

    UPDATE Submissions SET status = 'reviewed' WHERE submission_id = p_submission_id;

    INSERT INTO SubmissionStatusHistory (submission_id, old_status, new_status, changed_by)
    VALUES (p_submission_id, 'low_confidence', 'reviewed', v_admin_username);
END;
$$;

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
        VALUES (current_user, 'INSERT', 'submissions', NEW.submission_id, row_to_json(NEW)::JSONB);
    ELSIF TG_OP = 'UPDATE' THEN
        IF OLD.status IS DISTINCT FROM NEW.status THEN
            INSERT INTO AuditLogs (actor, action, table_name, record_id, old_values, new_values)
            VALUES (current_user, 'STATUS_CHANGE', 'submissions', NEW.submission_id,
                    jsonb_build_object('status', OLD.status), jsonb_build_object('status', NEW.status));
        ELSE
            INSERT INTO AuditLogs (actor, action, table_name, record_id, old_values, new_values)
            VALUES (current_user, 'UPDATE', 'submissions', NEW.submission_id, row_to_json(OLD)::JSONB, row_to_json(NEW)::JSONB);
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
    VALUES (current_user, 'INSERT', 'predictions', NEW.prediction_id, row_to_json(NEW)::JSONB);
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
        VALUES (current_user, v_action, 'admin_reviews', NEW.review_id, row_to_json(NEW)::JSONB);
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO AuditLogs (actor, action, table_name, record_id, old_values, new_values)
        VALUES (current_user, 'BULK_UPDATE', 'admin_reviews', NEW.review_id, row_to_json(OLD)::JSONB, row_to_json(NEW)::JSONB);
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

INSERT INTO AdminUsers (admin_id, username, password_hash, role) VALUES
    (1, 'dr_patel',         '$2b$12$LJ3m5ZQxK8Hy9bXtRqS2/.hashed_placeholder_01', 'super_admin'),
    (2, 'agri_expert_01',   '$2b$12$9KpVxWmN4Tz1cDfRqS3/.hashed_placeholder_02',  'reviewer'),
    (3, 'data_analyst',     '$2b$12$mR7sXwPq2Uj8nBgYtE4/.hashed_placeholder_03',   'analyst')
ON CONFLICT (admin_id) DO NOTHING;
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
