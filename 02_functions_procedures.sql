-- ============================================================================
-- LeafLense Database – Functions & Procedures
-- File: 02_functions_procedures.sql
-- Description: Admin-restricted functions (SECURITY DEFINER) and application
--              procedures for submission lifecycle management.
-- ============================================================================

SET search_path = leaflense, public;

-- ============================================================================
-- FRONTEND INTEGRATION: PENDING LOW-CONFIDENCE VIEW & FUNCTION
-- ----------------------------------------------------------------------------
-- Powers the "Pending Low-Confidence Reviews" tab in the Admin GUI dashboard.
-- ============================================================================

DROP VIEW IF EXISTS v_pending_low_confidence_reviews CASCADE;

CREATE OR REPLACE VIEW v_pending_low_confidence_reviews AS
SELECT
    s.submission_id,
    s.image_path,
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
    IS 'Powers the frontend admin dashboard tab showing all pending low-confidence submissions.';

CREATE OR REPLACE FUNCTION get_pending_low_confidence_submissions()
RETURNS TABLE (
    submission_id           INT,
    image_path              VARCHAR,
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
-- FRONTEND INTEGRATION: FARMER SUBMISSION REPORT VIEW & FUNCTION
-- ----------------------------------------------------------------------------
-- Powers the Farmer Report Lookup field by submission_id.
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

GRANT SELECT ON v_farmer_submission_reports TO leaflense_admin, leaflense_app, leaflense_readonly;

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

GRANT EXECUTE ON FUNCTION get_farmer_submission_report(INT) TO leaflense_admin, leaflense_app, leaflense_readonly;

COMMENT ON FUNCTION get_farmer_submission_report(INT)
    IS 'Fetches the farmer report for a given submission_id, returning NULL for predictions/recommendations while pending or low_confidence.';

-- ============================================================================
-- FUNCTION 1: get_active_confidence_threshold()
-- ----------------------------------------------------------------------------
-- Returns the confidence threshold of the currently active model.
-- If multiple models are active, returns the MINIMUM threshold (most lenient).
-- Restricted to leaflense_admin role members.
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
    -- ---- Access control: admin only ----
    IF NOT pg_has_role(current_user, 'leaflense_admin', 'MEMBER')
       AND current_user <> 'leaflense_admin' THEN
        RAISE EXCEPTION 'Access denied: admin role required. Current user: %', current_user;
    END IF;

    -- ---- Fetch the minimum threshold from active models ----
    SELECT MIN(confidence_threshold)
      INTO v_threshold
      FROM Models
     WHERE is_active = TRUE;

    IF v_threshold IS NULL THEN
        RAISE EXCEPTION 'No active model found. Please activate a model first.';
    END IF;

    RETURN v_threshold;
END;
$$;

ALTER FUNCTION get_active_confidence_threshold() OWNER TO leaflense_admin;

COMMENT ON FUNCTION get_active_confidence_threshold()
    IS 'Returns the confidence threshold of the active model (admin-only).';

-- ============================================================================
-- FUNCTION 2: calculate_model_performance(p_model_id)
-- ----------------------------------------------------------------------------
-- Computes accuracy metrics for a specific model by comparing its predictions
-- with admin-verified labels (AdminReviews).
-- Returns: total_predictions, verified_predictions, correct_predictions,
--          accuracy (%), avg_confidence.
-- Restricted to leaflense_admin role members.
-- ============================================================================

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
    -- ---- Access control: admin only ----
    IF NOT pg_has_role(current_user, 'leaflense_admin', 'MEMBER')
       AND current_user <> 'leaflense_admin' THEN
        RAISE EXCEPTION 'Access denied: admin role required. Current user: %', current_user;
    END IF;

    -- ---- Validate model exists ----
    IF NOT EXISTS (SELECT 1 FROM Models WHERE model_id = p_model_id) THEN
        RAISE EXCEPTION 'Model with ID % does not exist.', p_model_id;
    END IF;

    RETURN QUERY
    SELECT
        -- Total predictions made by this model
        COUNT(*)::BIGINT                                            AS total_predictions,

        -- Predictions whose submission has been reviewed by an admin
        COUNT(ar.review_id)::BIGINT                                 AS verified_predictions,

        -- Predictions verified as correct
        COUNT(CASE WHEN ar.is_correct = TRUE THEN 1 END)::BIGINT   AS correct_predictions,

        -- Accuracy = correct / verified × 100 (handle division by zero)
        CASE
            WHEN COUNT(ar.review_id) = 0 THEN 0.00
            ELSE ROUND(
                COUNT(CASE WHEN ar.is_correct = TRUE THEN 1 END)::NUMERIC
                / COUNT(ar.review_id) * 100,
                2
            )
        END                                                         AS accuracy,

        -- Average confidence score across all predictions
        ROUND(AVG(p.confidence_score), 4)                           AS avg_confidence

    FROM Predictions p
    LEFT JOIN AdminReviews ar ON ar.submission_id = p.submission_id
    WHERE p.model_id = p_model_id
      AND p.is_top_prediction = TRUE;
END;
$$;

ALTER FUNCTION calculate_model_performance(INT) OWNER TO leaflense_admin;

COMMENT ON FUNCTION calculate_model_performance(INT)
    IS 'Computes accuracy metrics for a model against admin-verified labels (admin-only).';

-- ============================================================================
-- FUNCTION 3: get_disease_statistics(p_start_date, p_end_date)
-- ----------------------------------------------------------------------------
-- Aggregates prediction statistics per disease, optionally filtered by a
-- date range on predicted_at.
-- Returns per-disease: total cases, avg confidence, high/low confidence
-- counts, reviewed count, first/last detection timestamps.
-- Restricted to leaflense_admin role members.
-- ============================================================================

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
    -- ---- Access control: admin only ----
    IF NOT pg_has_role(current_user, 'leaflense_admin', 'MEMBER')
       AND current_user <> 'leaflense_admin' THEN
        RAISE EXCEPTION 'Access denied: admin role required. Current user: %', current_user;
    END IF;

    -- ---- Get confidence threshold for high/low classification ----
    SELECT MIN(confidence_threshold)
      INTO v_threshold
      FROM Models
     WHERE is_active = TRUE;

    -- Default to 0.75 if no active model (graceful degradation)
    IF v_threshold IS NULL THEN
        v_threshold := 0.7500;
    END IF;

    RETURN QUERY
    SELECT
        d.disease_id,
        d.disease_name,

        -- Total predictions for this disease
        COUNT(*)::BIGINT                        AS total_cases,

        -- Average confidence
        ROUND(AVG(p.confidence_score), 4)       AS avg_confidence,

        -- High confidence: score >= threshold
        COUNT(*) FILTER (
            WHERE p.confidence_score >= v_threshold
        )::BIGINT                               AS high_confidence_cases,

        -- Low confidence: score < threshold
        COUNT(*) FILTER (
            WHERE p.confidence_score < v_threshold
        )::BIGINT                               AS low_confidence_cases,

        -- Reviewed: submissions with at least one admin review
        COUNT(DISTINCT ar.review_id)::BIGINT    AS reviewed_cases,

        -- Temporal range
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

ALTER FUNCTION get_disease_statistics(TIMESTAMPTZ, TIMESTAMPTZ) OWNER TO leaflense_admin;

COMMENT ON FUNCTION get_disease_statistics(TIMESTAMPTZ, TIMESTAMPTZ)
    IS 'Aggregates per-disease prediction statistics within an optional date range (admin-only).';


-- ############################################################################
-- PROCEDURES
-- ############################################################################

-- ============================================================================
-- PROCEDURE 1: submit_leaf_sample()
-- ----------------------------------------------------------------------------
-- Creates a new submission record for an uploaded leaf image.
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
SET search_path = leaflense, public
AS $$
BEGIN
    -- ---- Validate input ----
    IF p_image_path IS NULL OR TRIM(p_image_path) = '' THEN
        RAISE EXCEPTION 'Image path cannot be empty.';
    END IF;

    -- ---- Insert the submission ----
    INSERT INTO Submissions (image_path, status, additional_info, ip_address, user_agent)
    VALUES (p_image_path, 'pending', p_additional_info, p_ip_address, p_user_agent)
    RETURNING submission_id INTO p_submission_id;

    -- ---- Record the initial status in history ----
    INSERT INTO SubmissionStatusHistory (submission_id, old_status, new_status, changed_by)
    VALUES (p_submission_id, NULL, 'pending', 'system');

    RAISE NOTICE 'Submission % created successfully.', p_submission_id;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Failed to create submission: %', SQLERRM;
END;
$$;

COMMENT ON PROCEDURE submit_leaf_sample(VARCHAR, TEXT, INET, TEXT)
    IS 'Creates a new submission with status "pending" and logs the initial status.';

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
SET search_path = leaflense, public
AS $$
DECLARE
    v_current_status    submission_status;
    v_threshold         NUMERIC(5,4);
    v_new_status        submission_status;
    v_prediction_id     INT;
BEGIN
    -- ---- Validate submission exists and is still pending ----
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

    -- ---- Validate model exists and is active ----
    IF NOT EXISTS (SELECT 1 FROM Models WHERE model_id = p_model_id AND is_active = TRUE) THEN
        RAISE EXCEPTION 'Model % does not exist or is not active.', p_model_id;
    END IF;

    -- ---- Validate disease exists ----
    IF NOT EXISTS (SELECT 1 FROM Diseases WHERE disease_id = p_disease_id) THEN
        RAISE EXCEPTION 'Disease % does not exist.', p_disease_id;
    END IF;

    -- ---- Validate confidence score range ----
    IF p_confidence_score < 0 OR p_confidence_score > 1 THEN
        RAISE EXCEPTION 'Confidence score must be between 0 and 1. Received: %', p_confidence_score;
    END IF;

    -- ---- Insert the prediction ----
    INSERT INTO Predictions (submission_id, model_id, disease_id, confidence_score, is_top_prediction)
    VALUES (p_submission_id, p_model_id, p_disease_id, p_confidence_score, p_is_top_prediction)
    RETURNING prediction_id INTO v_prediction_id;

    RAISE NOTICE 'Prediction % recorded (confidence: %).', v_prediction_id, p_confidence_score;

    -- ---- Route submission if this is the top prediction ----
    IF p_is_top_prediction = TRUE THEN
        -- Get the model's confidence threshold
        SELECT confidence_threshold INTO v_threshold
          FROM Models
         WHERE model_id = p_model_id;

        IF p_confidence_score >= v_threshold THEN
            v_new_status := 'processed';
        ELSE
            v_new_status := 'low_confidence';
        END IF;

        -- Update submission status
        UPDATE Submissions
           SET status = v_new_status
         WHERE submission_id = p_submission_id;

        -- Record status transition
        INSERT INTO SubmissionStatusHistory (submission_id, old_status, new_status, changed_by)
        VALUES (p_submission_id, 'pending', v_new_status, 'system');

        RAISE NOTICE 'Submission % routed to status "%".', p_submission_id, v_new_status;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Failed to record prediction: %', SQLERRM;
END;
$$;

COMMENT ON PROCEDURE record_prediction(INT, INT, INT, NUMERIC, BOOLEAN)
    IS 'Stores a prediction and auto-routes the submission based on confidence vs threshold.';

-- ============================================================================
-- PROCEDURE 3: review_low_confidence_case()
-- ----------------------------------------------------------------------------
-- Records an administrator's assessment of a low-confidence submission.
-- Updates the submission status to 'reviewed' and logs the transition.
-- ============================================================================

CREATE OR REPLACE PROCEDURE review_low_confidence_case(
    IN p_submission_id      INT,
    IN p_admin_id           INT,
    IN p_assessed_disease_id INT  DEFAULT NULL,
    IN p_is_correct         BOOLEAN DEFAULT NULL,
    IN p_notes              TEXT    DEFAULT NULL
)
LANGUAGE plpgsql
SET search_path = leaflense, public
AS $$
DECLARE
    v_current_status    submission_status;
    v_admin_username    VARCHAR(100);
    v_review_id         INT;
BEGIN
    -- ---- Validate submission exists and has low_confidence status ----
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

    -- ---- Validate admin exists and is active ----
    SELECT username INTO v_admin_username
      FROM AdminUsers
     WHERE admin_id = p_admin_id AND is_active = TRUE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Admin % does not exist or is inactive.', p_admin_id;
    END IF;

    -- ---- Validate assessed disease if provided ----
    IF p_assessed_disease_id IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM Diseases WHERE disease_id = p_assessed_disease_id) THEN
            RAISE EXCEPTION 'Assessed disease % does not exist.', p_assessed_disease_id;
        END IF;
    END IF;

    -- ---- Insert the admin review ----
    INSERT INTO AdminReviews (submission_id, admin_id, assessed_disease_id, is_correct, notes)
    VALUES (p_submission_id, p_admin_id, p_assessed_disease_id, p_is_correct, p_notes)
    RETURNING review_id INTO v_review_id;

    -- ---- Update submission status to 'reviewed' ----
    UPDATE Submissions
       SET status = 'reviewed'
     WHERE submission_id = p_submission_id;

    -- ---- Record the status change ----
    INSERT INTO SubmissionStatusHistory (submission_id, old_status, new_status, changed_by)
    VALUES (p_submission_id, 'low_confidence', 'reviewed', v_admin_username);

    RAISE NOTICE 'Review % recorded by admin "%" for submission %.', v_review_id, v_admin_username, p_submission_id;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Failed to record review: %', SQLERRM;
END;
$$;

COMMENT ON PROCEDURE review_low_confidence_case(INT, INT, INT, BOOLEAN, TEXT)
    IS 'Records an admin review for a low-confidence submission and updates its status.';

-- ============================================================================
-- END OF FILE
-- ============================================================================
