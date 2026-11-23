-- ============================================================================
-- LeafLense Database – Core Queries
-- File: 04_queries.sql
-- Description: Production queries covering farmer submission lookup,
--              admin low-confidence review queue, admin review history,
--              disease recommendations, and admin login/session integration.
-- ============================================================================

SET search_path = leaflense, public;

-- ============================================================================
-- QUERY 1: Retrieve Farmer Submission Report by submission_id
-- ----------------------------------------------------------------------------
-- Returns the complete farmer-facing report for a single submission_id:
--   • Uses LEFT JOINs so 'pending' submissions still return a row.
--   • If status is 'pending' or 'low_confidence', status is returned as
--     'pending' and prediction, disease, and recommendation columns are NULL.
--   • If status is 'processed', returns the AI prediction, symptoms, and
--     linked treatment recommendations.
--   • If status is 'reviewed', returns the admin-verified diagnosis, admin
--     notes, symptoms, and linked treatment recommendations.
--
-- FRONTEND CONNECTIVITY:
-- Your backend API (e.g. GET /api/submissions/:id/report) can run:
--   SELECT * FROM leaflense.get_farmer_submission_report(:submission_id);
-- Or query the view directly:
--   SELECT * FROM leaflense.v_farmer_submission_reports WHERE submission_id = $1;
-- ============================================================================

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
FROM
    v_farmer_submission_reports
WHERE
    submission_id = 1;   -- << replace with :submission_id parameter


-- ============================================================================
-- QUERY 2: Find Pending Low-Confidence Submissions (Admin Triage Queue)
-- ----------------------------------------------------------------------------
-- Surfaces submissions whose status is 'low_confidence' and shows only
-- the top prediction for each. Ordered by confidence ascending so the
-- weakest predictions appear first – ideal for the admin review queue.
--
-- FRONTEND CONNECTIVITY:
-- Your backend API (e.g. GET /api/admin/pending-reviews) can run:
--   SELECT * FROM leaflense.get_pending_low_confidence_submissions(:session_token);
-- Or query the view directly when connected as an admin role:
--   SELECT * FROM leaflense.v_pending_low_confidence_reviews;
-- ============================================================================

SELECT
    s.submission_id,
    s.image_path,
    s.additional_info        AS farmer_additional_info,
    s.submitted_at,
    d.disease_name           AS top_predicted_disease,
    p.confidence_score,
    m.model_name
FROM
    Submissions  s
    INNER JOIN Predictions p ON p.submission_id  = s.submission_id
    INNER JOIN Models      m ON m.model_id       = p.model_id
    INNER JOIN Diseases    d ON d.disease_id     = p.disease_id
WHERE
    s.status            = 'low_confidence'
    AND p.is_top_prediction = TRUE
ORDER BY
    p.confidence_score ASC;    -- worst confidence first


-- ============================================================================
-- QUERY 3: Retrieve Submissions Reviewed by a Specific Administrator
-- ----------------------------------------------------------------------------
-- For a given admin, lists every review they performed alongside the
-- original top prediction so the admin can compare their assessment
-- with the model's output.
-- ============================================================================

SELECT
    s.submission_id,
    s.image_path,
    ar.reviewed_at,
    d_assessed.disease_name  AS assessed_disease_name,
    ar.notes,
    ar.is_correct,
    d_predicted.disease_name AS original_predicted_disease,
    p.confidence_score       AS original_confidence_score
FROM
    AdminReviews ar
    INNER JOIN Submissions s           ON s.submission_id  = ar.submission_id
    LEFT  JOIN Diseases    d_assessed  ON d_assessed.disease_id = ar.assessed_disease_id
    LEFT  JOIN Predictions p           ON p.submission_id  = s.submission_id
                                      AND p.is_top_prediction = TRUE
    LEFT  JOIN Diseases    d_predicted ON d_predicted.disease_id = p.disease_id
WHERE
    ar.admin_id = 2           -- << replace with :admin_id parameter
ORDER BY
    ar.reviewed_at DESC;


-- ============================================================================
-- QUERY 4: Display Diseases with Their Recommendations
-- ----------------------------------------------------------------------------
-- A reference listing of every disease alongside the recommendations
-- linked to it via the DiseaseRecommendations bridge table.
-- ============================================================================

SELECT
    d.disease_id,
    d.disease_name,
    d.description            AS disease_description,
    d.symptoms,
    r.title                  AS recommendation_title,
    r.description            AS recommendation_description,
    r.source                 AS recommendation_source
FROM
    Diseases               d
    LEFT JOIN DiseaseRecommendations dr ON dr.disease_id        = d.disease_id
    LEFT JOIN Recommendations        r  ON r.recommendation_id  = dr.recommendation_id
ORDER BY
    d.disease_name,
    r.title;


-- ============================================================================
-- QUERY 5: Admin Login, Session Verification, Review & Farmer Flow
-- ----------------------------------------------------------------------------
-- Reference queries for connecting the frontend UI through your backend API:
--   • Corner Tab -> Admin Login Page (username + password -> session_token)
--   • Admin Review Queue & Submit Review (session_token protected)
--   • Farmer Submission & Report Lookup (no login required)
-- ============================================================================

-- 5a. Admin Login (POST /api/admin/login)
SELECT *
FROM login_admin(
    p_username   := 'dr_patel',
    p_password   := 'Admin@123',
    p_ip_address := '127.0.0.1'::INET,
    p_user_agent := 'LeafLense-Web/1.0'
);

-- 5b. Verify Admin Session (GET /api/admin/me)
-- SELECT * FROM verify_admin_session(:session_token);

-- 5c. Fetch Pending Low-Confidence Reviews (GET /api/admin/pending-reviews)
-- SELECT * FROM get_pending_low_confidence_submissions(:session_token);

-- 5d. Submit Admin Review for Low-Confidence Case (POST /api/admin/submit-review)
-- CALL review_low_confidence_case(
--     p_submission_id       := 4,
--     p_assessed_disease_id := 1,
--     p_is_correct          := FALSE,
--     p_notes               := 'Confirmed Tomato Late Blight.',
--     p_session_token       := :session_token
-- );

-- 5e. Admin Logout (POST /api/admin/logout)
-- SELECT logout_admin(:session_token);

-- 5f. Anonymous Farmer Image Submission (POST /api/submissions - NO LOGIN)
-- CALL submit_leaf_sample('/uploads/leaf_new.jpg', NULL, 'Yellow spots on tomato leaf');


-- ============================================================================
-- END OF FILE
-- ============================================================================
