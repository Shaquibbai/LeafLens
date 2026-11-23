-- ============================================================================
-- LeafLense Database – Triggers
-- File: 03_triggers.sql
-- Description: Trigger functions and triggers for validation, auditing, and
--              automatic timestamp updates.
-- ============================================================================

SET search_path = leaflense, public;

-- ============================================================================
-- TRIGGER 1: trg_validate_prediction
-- ----------------------------------------------------------------------------
-- BEFORE INSERT OR UPDATE on Predictions
-- Validates:
--   • confidence_score is between 0 and 1
--   • The referenced model is active (is_active = TRUE)
--   • The disease class is supported by the model (exists in ModelClasses)
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_validate_prediction()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_model_active BOOLEAN;
BEGIN
    -- ---- Validate confidence score range ----
    IF NEW.confidence_score < 0 OR NEW.confidence_score > 1 THEN
        RAISE EXCEPTION 'Invalid confidence_score: %. Must be between 0 and 1.',
            NEW.confidence_score;
    END IF;

    -- ---- Validate model is active ----
    SELECT is_active INTO v_model_active
      FROM Models
     WHERE model_id = NEW.model_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Model with ID % does not exist.', NEW.model_id;
    END IF;

    IF v_model_active = FALSE THEN
        RAISE EXCEPTION 'Model % is not active. Only active models can produce predictions.',
            NEW.model_id;
    END IF;

    -- ---- Validate disease is a supported class for this model ----
    IF NOT EXISTS (
        SELECT 1
          FROM ModelClasses
         WHERE model_id  = NEW.model_id
           AND disease_id = NEW.disease_id
    ) THEN
        RAISE EXCEPTION 'Disease % is not a supported class for model %. '
                         'Register it in ModelClasses first.',
            NEW.disease_id, NEW.model_id;
    END IF;

    RETURN NEW;
END;
$$;

-- Drop existing trigger before creating (idempotent)
DROP TRIGGER IF EXISTS trg_validate_prediction ON Predictions;

CREATE TRIGGER trg_validate_prediction
    BEFORE INSERT OR UPDATE
    ON Predictions
    FOR EACH ROW
    EXECUTE FUNCTION fn_validate_prediction();

COMMENT ON FUNCTION fn_validate_prediction()
    IS 'Validates confidence score range, model status, and disease-model compatibility.';

-- ============================================================================
-- TRIGGER 2: trg_audit_submission_changes
-- ----------------------------------------------------------------------------
-- AFTER INSERT OR UPDATE on Submissions
-- On INSERT:
--   • Logs the new submission to AuditLogs (action = INSERT)
-- On UPDATE:
--   • If status changed: logs STATUS_CHANGE and records in SubmissionStatusHistory
--   • Otherwise: logs a general UPDATE with old/new values
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_audit_submission_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- ---- Log new submission creation ----
        INSERT INTO AuditLogs (actor, action, table_name, record_id, new_values)
        VALUES (
            COALESCE(NULLIF(current_setting('leaflense.current_admin', true), ''), current_user),
            'INSERT',
            'submissions',
            NEW.submission_id,
            row_to_json(NEW)::JSONB
        );

    ELSIF TG_OP = 'UPDATE' THEN
        IF OLD.status IS DISTINCT FROM NEW.status THEN
            -- ---- Status change: special audit entry + history ----
            INSERT INTO AuditLogs (actor, action, table_name, record_id, old_values, new_values)
            VALUES (
                COALESCE(NULLIF(current_setting('leaflense.current_admin', true), ''), current_user),
                'STATUS_CHANGE',
                'submissions',
                NEW.submission_id,
                jsonb_build_object('status', OLD.status),
                jsonb_build_object('status', NEW.status)
            );

            -- Record in SubmissionStatusHistory
            -- (Note: procedures also insert into this table, so we check
            --  pg_trigger_depth to avoid duplicate entries when called from
            --  a procedure that already handles history)
            IF pg_trigger_depth() <= 1 THEN
                INSERT INTO SubmissionStatusHistory (
                    submission_id, old_status, new_status, changed_by
                ) VALUES (
                    NEW.submission_id,
                    OLD.status,
                    NEW.status,
                    COALESCE(NULLIF(current_setting('leaflense.current_admin', true), ''), current_user)
                );
            END IF;

        ELSE
            -- ---- Non-status update: log full row changes ----
            INSERT INTO AuditLogs (actor, action, table_name, record_id, old_values, new_values)
            VALUES (
                COALESCE(NULLIF(current_setting('leaflense.current_admin', true), ''), current_user),
                'UPDATE',
                'submissions',
                NEW.submission_id,
                row_to_json(OLD)::JSONB,
                row_to_json(NEW)::JSONB
            );
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_submission_changes ON Submissions;

CREATE TRIGGER trg_audit_submission_changes
    AFTER INSERT OR UPDATE
    ON Submissions
    FOR EACH ROW
    EXECUTE FUNCTION fn_audit_submission_changes();

COMMENT ON FUNCTION fn_audit_submission_changes()
    IS 'Audits every INSERT and UPDATE on Submissions; differentiates status changes.';

-- ============================================================================
-- TRIGGER 2b: trg_audit_prediction_insert
-- ----------------------------------------------------------------------------
-- AFTER INSERT on Predictions
-- Logs every new prediction to the AuditLogs table.
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_audit_prediction_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO AuditLogs (actor, action, table_name, record_id, new_values)
    VALUES (
        COALESCE(NULLIF(current_setting('leaflense.current_admin', true), ''), current_user),
        'INSERT',
        'predictions',
        NEW.prediction_id,
        row_to_json(NEW)::JSONB
    );

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_prediction_insert ON Predictions;

CREATE TRIGGER trg_audit_prediction_insert
    AFTER INSERT
    ON Predictions
    FOR EACH ROW
    EXECUTE FUNCTION fn_audit_prediction_insert();

COMMENT ON FUNCTION fn_audit_prediction_insert()
    IS 'Logs every new prediction to the audit trail.';

-- ============================================================================
-- TRIGGER 3: trg_audit_bulk_changes
-- ----------------------------------------------------------------------------
-- AFTER INSERT OR UPDATE on AdminReviews
-- On INSERT: logs the new review (action = INSERT)
-- On UPDATE: logs the change (action = BULK_UPDATE for multi-row operations)
-- Uses pg_trigger_depth() to detect nested/bulk operations.
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_audit_bulk_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_action audit_action;
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- Determine if this is part of a bulk operation
        IF pg_trigger_depth() > 1 THEN
            v_action := 'BULK_UPDATE';
        ELSE
            v_action := 'INSERT';
        END IF;

        INSERT INTO AuditLogs (actor, action, table_name, record_id, new_values)
        VALUES (
            COALESCE(NULLIF(current_setting('leaflense.current_admin', true), ''), current_user),
            v_action,
            'admin_reviews',
            NEW.review_id,
            row_to_json(NEW)::JSONB
        );

    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO AuditLogs (actor, action, table_name, record_id, old_values, new_values)
        VALUES (
            COALESCE(NULLIF(current_setting('leaflense.current_admin', true), ''), current_user),
            'BULK_UPDATE',
            'admin_reviews',
            NEW.review_id,
            row_to_json(OLD)::JSONB,
            row_to_json(NEW)::JSONB
        );
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_bulk_changes ON AdminReviews;

CREATE TRIGGER trg_audit_bulk_changes
    AFTER INSERT OR UPDATE
    ON AdminReviews
    FOR EACH ROW
    EXECUTE FUNCTION fn_audit_bulk_changes();

COMMENT ON FUNCTION fn_audit_bulk_changes()
    IS 'Audits admin review changes; marks bulk/nested operations as BULK_UPDATE.';

-- ============================================================================
-- TRIGGER 4: trg_update_model_timestamp
-- ----------------------------------------------------------------------------
-- BEFORE UPDATE on Models
-- Automatically sets updated_at to NOW() whenever a model row is modified.
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_update_model_timestamp()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_update_model_timestamp ON Models;

CREATE TRIGGER trg_update_model_timestamp
    BEFORE UPDATE
    ON Models
    FOR EACH ROW
    EXECUTE FUNCTION fn_update_model_timestamp();

COMMENT ON FUNCTION fn_update_model_timestamp()
    IS 'Auto-updates the updated_at timestamp on model row changes.';

-- ============================================================================
-- END OF FILE
-- ============================================================================
