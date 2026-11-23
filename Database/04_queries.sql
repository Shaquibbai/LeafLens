-- ============================================================================
-- LeafLense Database – Major Queries
-- File: 04_queries.sql
-- Description: Nine production-ready queries covering submission look-ups,
--              review workflows, analytics, trend analysis, model evaluation,
--              and combined reporting for the LeafLense plant-disease
--              detection platform.
-- ============================================================================

SET search_path = leaflense, public;

-- ============================================================================
-- QUERY 1: Retrieve Submission Details with Predictions & Model Information
-- ----------------------------------------------------------------------------
-- Returns the full picture for a single submission: image path, timestamps,
-- current status, every prediction row with its disease label, the model that
-- produced it, confidence score, and whether it was the top prediction.
--
-- Usage: replace :submission_id with the target submission's ID.
-- ============================================================================

-- Parameter: :submission_id  (INTEGER – the submission to look up)

SELECT
    s.submission_id,
    s.image_path,
    s.submitted_at,
    s.status,
    d.disease_name,
    m.model_name,
    m.version                AS model_version,
    p.confidence_score,
    p.is_top_prediction,
    p.predicted_at
FROM
    Submissions  s
    INNER JOIN Predictions p ON p.submission_id = s.submission_id
    INNER JOIN Models      m ON m.model_id      = p.model_id
    INNER JOIN Diseases    d ON d.disease_id    = p.disease_id
WHERE
    s.submission_id = 1   -- << replace with :submission_id parameter
ORDER BY
    s.submitted_at DESC,
    p.confidence_score DESC;


-- ============================================================================
-- QUERY 2: Find Pending Low-Confidence Submissions (Admin Triage Queue)
-- ----------------------------------------------------------------------------
-- Surfaces submissions whose status is 'low_confidence' and shows only
-- the top prediction for each. Ordered by confidence ascending so the
-- weakest predictions appear first – ideal for a reviewer's work-queue.
--
-- FRONTEND CONNECTIVITY:
-- Your backend API (e.g. GET /api/admin/pending-reviews) can simply run:
--   SELECT * FROM leaflense.v_pending_low_confidence_reviews;
-- Or run this direct query below:
-- ============================================================================

SELECT
    s.submission_id,
    s.image_path,
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
-- original top prediction so the reviewer can compare their assessment
-- with the model's output.
--
-- Two disease joins are needed:
--   • d_assessed  – the disease the admin marked (may be NULL)
--   • d_predicted – the disease from the model's top prediction
--
-- Usage: replace :admin_id with the target administrator's ID.
-- ============================================================================

-- Parameter: :admin_id  (INTEGER – the administrator to query)

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
    -- Disease the admin assessed (nullable – LEFT JOIN)
    LEFT  JOIN Diseases    d_assessed  ON d_assessed.disease_id = ar.assessed_disease_id
    -- Original top prediction for context
    LEFT  JOIN Predictions p           ON p.submission_id  = s.submission_id
                                      AND p.is_top_prediction = TRUE
    LEFT  JOIN Diseases    d_predicted ON d_predicted.disease_id = p.disease_id
WHERE
    ar.admin_id = 1           -- << replace with :admin_id parameter
ORDER BY
    ar.reviewed_at DESC;


-- ============================================================================
-- QUERY 4: Display Diseases with Their Recommendations
-- ----------------------------------------------------------------------------
-- A reference listing of every disease alongside the recommendations
-- linked to it via the DiseaseRecommendations bridge table.
-- Diseases without recommendations still appear (LEFT JOIN).
-- ============================================================================

SELECT
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
-- QUERY 5: Calculate and Rank Disease-Wise Prediction Counts
-- ----------------------------------------------------------------------------
-- Aggregates prediction statistics per disease and ranks them by volume.
-- "High confidence" and "low confidence" are determined dynamically by
-- comparing each prediction's confidence_score against the producing
-- model's confidence_threshold.
-- ============================================================================

SELECT
    d.disease_name,
    COUNT(*)                                               AS total_predictions,
    ROUND(AVG(p.confidence_score), 4)                      AS avg_confidence,
    COUNT(*) FILTER (
        WHERE p.confidence_score >= m.confidence_threshold
    )                                                      AS high_confidence_count,
    COUNT(*) FILTER (
        WHERE p.confidence_score <  m.confidence_threshold
    )                                                      AS low_confidence_count,
    DENSE_RANK() OVER (
        ORDER BY COUNT(*) DESC
    )                                                      AS disease_rank
FROM
    Predictions p
    INNER JOIN Diseases d ON d.disease_id = p.disease_id
    INNER JOIN Models   m ON m.model_id   = p.model_id
GROUP BY
    d.disease_id,
    d.disease_name
ORDER BY
    disease_rank,
    d.disease_name;


-- ============================================================================
-- QUERY 6: Compare Disease Trends Across Two Periods
-- ----------------------------------------------------------------------------
-- Uses two CTEs to bucket top-prediction counts into:
--   • period_1 : the most recent 30 days
--   • period_2 : the previous 30 days (60 → 30 days ago)
-- A FULL OUTER JOIN ensures diseases appearing in only one period are
-- still reported.  Results are ordered by the absolute change descending
-- so the biggest movers surface first.
-- ============================================================================

WITH period_1 AS (
    -- Recent 30 days
    SELECT
        p.disease_id,
        COUNT(*) AS prediction_count
    FROM
        Predictions  p
        INNER JOIN Submissions s ON s.submission_id = p.submission_id
    WHERE
        p.is_top_prediction = TRUE
        AND s.submitted_at >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY
        p.disease_id
),
period_2 AS (
    -- Previous 30 days (60-to-30 days ago)
    SELECT
        p.disease_id,
        COUNT(*) AS prediction_count
    FROM
        Predictions  p
        INNER JOIN Submissions s ON s.submission_id = p.submission_id
    WHERE
        p.is_top_prediction = TRUE
        AND s.submitted_at >= CURRENT_DATE - INTERVAL '60 days'
        AND s.submitted_at <  CURRENT_DATE - INTERVAL '30 days'
    GROUP BY
        p.disease_id
)
SELECT
    d.disease_name,
    COALESCE(p1.prediction_count, 0)  AS period_1_count,
    COALESCE(p2.prediction_count, 0)  AS period_2_count,
    COALESCE(p1.prediction_count, 0)
        - COALESCE(p2.prediction_count, 0)
                                      AS change_count,
    CASE
        WHEN COALESCE(p2.prediction_count, 0) = 0 THEN NULL   -- avoid division by zero
        ELSE ROUND(
            (
                (COALESCE(p1.prediction_count, 0) - p2.prediction_count)::NUMERIC
                / p2.prediction_count
            ) * 100,
            2
        )
    END                               AS change_percentage
FROM
    period_1 p1
    FULL OUTER JOIN period_2 p2 ON p2.disease_id = p1.disease_id
    INNER JOIN Diseases d
        ON d.disease_id = COALESCE(p1.disease_id, p2.disease_id)
ORDER BY
    ABS(
        COALESCE(p1.prediction_count, 0)
        - COALESCE(p2.prediction_count, 0)
    ) DESC;


-- ============================================================================
-- QUERY 7: Calculate Average Prediction Confidence (Grouped Statistics)
-- ----------------------------------------------------------------------------
-- Uses GROUPING SETS to produce three levels of aggregation in a single
-- result set:
--   1. Per model + per disease   (most granular)
--   2. Per model only            (disease-level roll-up)
--   3. Grand total               (overall)
--
-- The grouping_level column helps the consumer distinguish the rows.
-- ============================================================================

SELECT
    CASE
        WHEN GROUPING(m.model_name) = 1 AND GROUPING(d.disease_name) = 1
            THEN 'Overall'
        WHEN GROUPING(d.disease_name) = 1
            THEN 'Per Model'
        ELSE 'Per Model & Disease'
    END                                    AS grouping_level,
    m.model_name,
    d.disease_name,
    ROUND(AVG(p.confidence_score), 4)      AS avg_confidence,
    MIN(p.confidence_score)                AS min_confidence,
    MAX(p.confidence_score)                AS max_confidence,
    COUNT(*)                               AS prediction_count
FROM
    Predictions p
    INNER JOIN Models   m ON m.model_id   = p.model_id
    INNER JOIN Diseases d ON d.disease_id = p.disease_id
GROUP BY GROUPING SETS (
    (m.model_name, d.disease_name),   -- per model + disease
    (m.model_name),                   -- per model
    ()                                -- grand total
)
ORDER BY
    GROUPING(m.model_name),
    m.model_name  NULLS LAST,
    GROUPING(d.disease_name),
    d.disease_name NULLS LAST;


-- ============================================================================
-- QUERY 8: Evaluate Model Performance Using Verified Labels
-- ----------------------------------------------------------------------------
-- Leverages admin reviews as ground-truth labels to compute accuracy and
-- per-disease precision for every model.
--
-- CTE breakdown:
--   • verified        – joins predictions with their admin review verdicts
--   • model_summary   – per-model totals, verified counts, accuracy
--   • disease_detail  – per-model-per-disease precision breakdown
--
-- The final SELECT unions the summary row with per-disease rows so the
-- full picture is available in one result set.
-- ============================================================================

WITH verified AS (
    -- Match each top prediction with its admin review (if one exists)
    SELECT
        p.prediction_id,
        p.model_id,
        p.disease_id        AS predicted_disease_id,
        p.confidence_score,
        ar.review_id,
        ar.is_correct
    FROM
        Predictions  p
        INNER JOIN Submissions s  ON s.submission_id = p.submission_id
        LEFT  JOIN AdminReviews ar ON ar.submission_id = p.submission_id
    WHERE
        p.is_top_prediction = TRUE
),
model_summary AS (
    -- Aggregate to model level
    SELECT
        v.model_id,
        COUNT(*)                                           AS total_predictions,
        COUNT(v.review_id)                                 AS verified_count,
        COUNT(*) FILTER (WHERE v.is_correct = TRUE)        AS correct_count,
        CASE
            WHEN COUNT(v.review_id) = 0 THEN NULL
            ELSE ROUND(
                COUNT(*) FILTER (WHERE v.is_correct = TRUE)::NUMERIC
                / COUNT(v.review_id) * 100,
                2
            )
        END                                                AS accuracy_pct
    FROM verified v
    GROUP BY v.model_id
),
disease_detail AS (
    -- Per-model, per-disease precision
    SELECT
        v.model_id,
        v.predicted_disease_id,
        COUNT(*)                                           AS disease_predictions,
        COUNT(v.review_id)                                 AS disease_verified,
        COUNT(*) FILTER (WHERE v.is_correct = TRUE)        AS disease_correct,
        CASE
            WHEN COUNT(v.review_id) = 0 THEN NULL
            ELSE ROUND(
                COUNT(*) FILTER (WHERE v.is_correct = TRUE)::NUMERIC
                / COUNT(v.review_id) * 100,
                2
            )
        END                                                AS disease_precision_pct
    FROM verified v
    GROUP BY v.model_id, v.predicted_disease_id
)
-- ---- Model-level summary rows ----
SELECT
    m.model_name,
    m.version                        AS model_version,
    '-- ALL DISEASES --'             AS disease_name,
    ms.total_predictions,
    ms.verified_count,
    ms.correct_count,
    ms.accuracy_pct,
    NULL::NUMERIC                    AS disease_precision_pct
FROM
    model_summary ms
    INNER JOIN Models m ON m.model_id = ms.model_id

UNION ALL

-- ---- Per-disease breakdown rows ----
SELECT
    m.model_name,
    m.version                        AS model_version,
    d.disease_name,
    dd.disease_predictions           AS total_predictions,
    dd.disease_verified              AS verified_count,
    dd.disease_correct               AS correct_count,
    NULL::NUMERIC                    AS accuracy_pct,
    dd.disease_precision_pct
FROM
    disease_detail dd
    INNER JOIN Models   m ON m.model_id   = dd.model_id
    INNER JOIN Diseases d ON d.disease_id = dd.predicted_disease_id

ORDER BY
    model_name,
    model_version,
    CASE WHEN disease_name = '-- ALL DISEASES --' THEN 0 ELSE 1 END,
    disease_name;


-- ============================================================================
-- QUERY 9: Generate Combined Reports
-- ============================================================================
-- Three self-contained sub-queries (designed as views or standalone SELECTs)
-- that can feed dashboards or export pipelines.
-- ============================================================================


-- ============================================================================
-- QUERY 9a: Disease-Wise Report
-- ----------------------------------------------------------------------------
-- For every disease: total cases (top predictions), average confidence,
-- the model that most frequently predicted it, and the first linked
-- recommendation title.
-- ============================================================================

WITH disease_stats AS (
    SELECT
        p.disease_id,
        COUNT(*)                           AS total_cases,
        ROUND(AVG(p.confidence_score), 4)  AS avg_confidence
    FROM Predictions p
    WHERE p.is_top_prediction = TRUE
    GROUP BY p.disease_id
),
most_common_model AS (
    -- For each disease, find the model that produced the most top predictions
    SELECT DISTINCT ON (p.disease_id)
        p.disease_id,
        m.model_name
    FROM
        Predictions p
        INNER JOIN Models m ON m.model_id = p.model_id
    WHERE p.is_top_prediction = TRUE
    GROUP BY p.disease_id, m.model_name
    ORDER BY p.disease_id, COUNT(*) DESC
),
top_recommendation AS (
    -- Pick the first recommendation alphabetically for each disease
    SELECT DISTINCT ON (dr.disease_id)
        dr.disease_id,
        r.title AS top_recommendation_title
    FROM
        DiseaseRecommendations dr
        INNER JOIN Recommendations r ON r.recommendation_id = dr.recommendation_id
    ORDER BY dr.disease_id, r.title
)
SELECT
    d.disease_name,
    COALESCE(ds.total_cases, 0)        AS total_cases,
    ds.avg_confidence,
    mcm.model_name                     AS most_common_model,
    tr.top_recommendation_title        AS top_recommendation
FROM
    Diseases d
    LEFT JOIN disease_stats      ds  ON ds.disease_id  = d.disease_id
    LEFT JOIN most_common_model  mcm ON mcm.disease_id = d.disease_id
    LEFT JOIN top_recommendation tr  ON tr.disease_id  = d.disease_id
ORDER BY
    d.disease_name;


-- ============================================================================
-- QUERY 9b: Model Performance Report
-- ----------------------------------------------------------------------------
-- One row per model: version, active flag, total predictions, accuracy
-- (from admin reviews), average confidence, and the timestamp of the
-- most recent prediction.
-- ============================================================================

WITH model_pred_stats AS (
    SELECT
        p.model_id,
        COUNT(*)                           AS total_predictions,
        ROUND(AVG(p.confidence_score), 4)  AS avg_confidence,
        MAX(p.predicted_at)                AS last_prediction_date
    FROM Predictions p
    GROUP BY p.model_id
),
model_accuracy AS (
    -- Accuracy based on admin-reviewed top predictions only
    SELECT
        p.model_id,
        CASE
            WHEN COUNT(ar.review_id) = 0 THEN NULL
            ELSE ROUND(
                COUNT(*) FILTER (WHERE ar.is_correct = TRUE)::NUMERIC
                / COUNT(ar.review_id) * 100,
                2
            )
        END AS accuracy_pct
    FROM
        Predictions  p
        INNER JOIN Submissions  s  ON s.submission_id  = p.submission_id
        LEFT  JOIN AdminReviews ar ON ar.submission_id = p.submission_id
    WHERE p.is_top_prediction = TRUE
    GROUP BY p.model_id
)
SELECT
    m.model_name,
    m.version,
    m.is_active,
    COALESCE(mps.total_predictions, 0) AS total_predictions,
    ma.accuracy_pct,
    mps.avg_confidence,
    mps.last_prediction_date
FROM
    Models m
    LEFT JOIN model_pred_stats mps ON mps.model_id = m.model_id
    LEFT JOIN model_accuracy   ma  ON ma.model_id  = m.model_id
ORDER BY
    m.is_active DESC,
    mps.total_predictions DESC NULLS LAST;


-- ============================================================================
-- QUERY 9c: Monthly Submission Report
-- ----------------------------------------------------------------------------
-- One row per calendar month: totals for submissions, processed, low-
-- confidence, reviewed, average confidence of the top prediction, and the
-- most commonly predicted disease that month.
-- ============================================================================

WITH monthly AS (
    SELECT
        DATE_TRUNC('month', s.submitted_at)::DATE     AS month,
        s.submission_id,
        s.status,
        p.confidence_score,
        p.disease_id
    FROM
        Submissions s
        LEFT JOIN Predictions p ON p.submission_id  = s.submission_id
                                AND p.is_top_prediction = TRUE
),
monthly_agg AS (
    SELECT
        m.month,
        COUNT(DISTINCT m.submission_id)                                     AS total_submissions,
        COUNT(DISTINCT m.submission_id) FILTER (
            WHERE m.status = 'processed'
        )                                                                   AS processed_count,
        COUNT(DISTINCT m.submission_id) FILTER (
            WHERE m.status = 'low_confidence'
        )                                                                   AS low_confidence_count,
        COUNT(DISTINCT m.submission_id) FILTER (
            WHERE m.status = 'reviewed'
        )                                                                   AS reviewed_count,
        ROUND(AVG(m.confidence_score), 4)                                   AS avg_confidence
    FROM monthly m
    GROUP BY m.month
),
most_common_disease AS (
    -- Per month, the disease with the highest number of top predictions
    SELECT DISTINCT ON (sub.month)
        sub.month,
        d.disease_name AS most_common_disease
    FROM (
        SELECT
            DATE_TRUNC('month', s.submitted_at)::DATE AS month,
            p.disease_id,
            COUNT(*) AS cnt
        FROM
            Submissions s
            INNER JOIN Predictions p ON p.submission_id  = s.submission_id
                                     AND p.is_top_prediction = TRUE
        GROUP BY
            DATE_TRUNC('month', s.submitted_at)::DATE,
            p.disease_id
    ) sub
    INNER JOIN Diseases d ON d.disease_id = sub.disease_id
    ORDER BY sub.month, sub.cnt DESC
)
SELECT
    ma.month,
    ma.total_submissions,
    ma.processed_count,
    ma.low_confidence_count,
    ma.reviewed_count,
    ma.avg_confidence,
    mcd.most_common_disease
FROM
    monthly_agg         ma
    LEFT JOIN most_common_disease mcd ON mcd.month = ma.month
ORDER BY
    ma.month DESC;


-- ============================================================================
-- END OF FILE
-- ============================================================================
