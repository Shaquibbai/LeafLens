# LeafLense: Complete System Catalogue & Architectural Workflow Guide

**System:** Crop Leaf Disease Detection & Decision Support Platform  
**Database Engine:** PostgreSQL 12+ (Tested on PostgreSQL 18)  
**Workspace Directory:** `e:\softwareProject\softwareProject\`  
**Date of Implementation:** November 2026  

---

## 1. Executive Summary & Core Concept

**LeafLense** is an enterprise-grade, web-based agricultural disease identification platform designed for farmers, agricultural extension workers, and plant pathologists. 

Farmers can upload leaf images anonymously (no registration barrier) to identify plant infections through an image classification neural network. The system records submissions, predictions, confidence scores, and model metadata. 

Predictions falling below the active model's confidence threshold are automatically sequestered into a triage work queue for administrator review. This guarantees diagnosis reliability for farmers while continuously producing an expert-verified ground-truth dataset for model retraining.

---

## 2. End-to-End System Workflow

```
   [ FARMER / PUBLIC USER ]
             |
             | 1. Uploads leaf photo (No registration required)
             v
   [ Web / Mobile Frontend ]
             |
             | 2. Saves file to local storage (e.g., /uploads/leaf_001.jpg)
             | 3. Calls: submit_leaf_sample('/uploads/leaf_001.jpg', OUT v_id)
             v
   [ PostgreSQL: Submissions Table ]  --> Status = 'pending'
             |                        --> SubmissionStatusHistory record added
             v
   [ AI Classification Model ]
             | 4. Runs inference (e.g., LeafNet-ResNet50 v2.1)
             | 5. Produces top prediction: (Tomato Late Blight, score = 0.6200)
             v
   [ Procedure: record_prediction() ]
             |
             | Checks against active model confidence_threshold (0.7500)
             +------------------------------+-------------------------------+
             |                                                              |
    [ Score >= Threshold ]                                         [ Score < Threshold ]
             |                                                              |
   Status -> 'processed'                                          Status -> 'low_confidence'
             |                                                              |
   * Frontend immediately displays:                               * Frontend shows:
     - Disease Name                                                 "Image submitted for expert
     - Symptoms                                                      agricultural review."
     - Treatment Recommendations                                            |
                                                                            v
                                                               [ Admin Review Dashboard ]
                                                               (Query 2 fetches pending cases)
                                                                            |
                                                                            | 6. Expert inspects leaf
                                                                            | 7. Calls review procedure
                                                                            v
                                                               [ Procedure: review_low_confidence_case() ]
                                                                            |
                                                                            | Saves AdminReviews record
                                                                            v
                                                                 Status -> 'reviewed'
                                                                 (Feeds Model Evaluation Metrics)
```

---

## 3. Database Table Catalogue (11 Tables)

| Table Name | Primary Key | Foreign Keys & Relationships | Core Business Purpose |
| :--- | :--- | :--- | :--- |
| **`AdminUsers`** | `admin_id` (`SERIAL`) | None | System administrators, review specialists, and analysts. Stores roles (`super_admin`, `reviewer`, `analyst`) and password hashes. |
| **`Models`** | `model_id` (`SERIAL`) | None (Unique on `model_name, version`) | Registry of computer vision models. Stores active status flag and the dynamic `confidence_threshold` ($0.0 - 1.0$). |
| **`Diseases`** | `disease_id` (`SERIAL`) | None (Unique on `disease_name`) | Catalogue of crop diseases. Includes symptoms description shown to farmers and contains a baseline `Healthy` class. |
| **`Submissions`** | `submission_id` (`SERIAL`) | None (Referenced by Predictions, Reviews, History) | Farmer leaf image uploads. Tracks local file path, submission timestamp, client IP, and lifecycle status. |
| **`Predictions`** | `prediction_id` (`SERIAL`) | `submission_id`, `model_id`, `disease_id` | Classification output scores. Flags the top winning prediction per submission via `is_top_prediction`. |
| **`ModelClasses`** | `model_class_id` (`SERIAL`) | `model_id`, `disease_id` | Many-to-Many bridge defining which disease classes each model is certified to predict. |
| **`AdminReviews`** | `review_id` (`SERIAL`) | `submission_id`, `admin_id`, `assessed_disease_id` | Manual expert reviews of low-confidence cases. Records diagnosis, correctness verdict, and observational notes. |
| **`Recommendations`** | `recommendation_id` (`SERIAL`) | None | Curated treatment advice, chemical/biological remedies, cultural practices, and advisory citations. |
| **`DiseaseRecommendations`** | `(disease_id, recommendation_id)` | `disease_id`, `recommendation_id` | Many-to-Many mapping associating multiple treatments and management guidelines to each specific disease. |
| **`SubmissionStatusHistory`** | `history_id` (`SERIAL`) | `submission_id` | Immutable state transition ledger tracking status progression (e.g., `pending` $\rightarrow$ `low_confidence` $\rightarrow$ `reviewed`). |
| **`AuditLogs`** | `audit_id` (`SERIAL`) | None | System-wide security and compliance ledger capturing actor identity, action type, and old/new JSONB row snapshots. |

---

## 4. Stored Functions (Admin Role-Guarded)

All administrative functions are enforced using `SECURITY DEFINER` and verify that the caller is a member of the `leaflense_admin` role or superuser.

### 1. `get_active_confidence_threshold() -> NUMERIC(5,4)`
* **Description:** Dynamically returns the minimum operational confidence threshold across all currently active models.
* **Usage:** Used by API engines to determine whether a diagnosis can be auto-accepted or requires human intervention.
* **Example Call:** `SELECT get_active_confidence_threshold();` $\rightarrow$ Returns `0.7500`.

### 2. `calculate_model_performance(p_model_id INT) -> TABLE(...)`
* **Description:** Computes precision metrics for a model by evaluating its predictions against human administrator verified labels (`AdminReviews`).
* **Returned Columns:** `total_predictions`, `verified_predictions`, `correct_predictions`, `accuracy (%)`, `avg_confidence`.
* **Example Call:** `SELECT * FROM calculate_model_performance(1);`

### 3. `get_disease_statistics(p_start_date, p_end_date) -> TABLE(...)`
* **Description:** Aggregates disease detection frequency, average confidence scores, high-vs-low confidence distributions, and temporal detection spans within an optional date window.
* **Example Call:** `SELECT * FROM get_disease_statistics(NOW() - INTERVAL '30 days', NOW());`

---

## 5. Stored Procedures (Application State Machine)

### 1. `submit_leaf_sample(IN p_image_path, OUT p_submission_id, IN p_ip_address, IN p_user_agent)`
* Atomically creates an immutable submission record with initial status `'pending'`.
* Immediately writes the initial baseline entry into `SubmissionStatusHistory`.
* Returns the newly generated `submission_id` for frontend reference.

### 2. `record_prediction(IN p_submission_id, IN p_model_id, IN p_disease_id, IN p_confidence_score, IN p_is_top_prediction)`
* Validates model status, class support, and confidence range ($0.0 - 1.0$).
* Inserts the prediction row into `Predictions`.
* **Automated Routing:** If `p_is_top_prediction = TRUE`:
  * If `p_confidence_score >= threshold` $\rightarrow$ Sets status to `'processed'`.
  * If `p_confidence_score < threshold` $\rightarrow$ Sets status to `'low_confidence'`.
  * Logs the transition into `SubmissionStatusHistory`.

### 3. `review_low_confidence_case(IN p_submission_id, IN p_admin_id, IN p_assessed_disease_id, IN p_is_correct, IN p_notes)`
* Validates that the target submission is currently in `'low_confidence'` state.
* Records the specialist's assessment and correctness verdict in `AdminReviews`.
* Updates the submission status to `'reviewed'`.
* Records the specialist's username and timestamp in `SubmissionStatusHistory`.

---

## 6. Database Triggers

1. **`trg_validate_prediction`** (`BEFORE INSERT OR UPDATE ON Predictions`):
   * Validates confidence score is within $[0.0, 1.0]$.
   * Rejects predictions from inactive models (`is_active = FALSE`).
   * Validates that the predicted disease is an authorized class mapped in `ModelClasses`.
2. **`trg_audit_submission_changes`** (`AFTER INSERT OR UPDATE ON Submissions`):
   * Logs row creation to `AuditLogs` with action `INSERT`.
   * Detects status transitions and logs an explicit `STATUS_CHANGE` audit entry with before/after state diffs.
3. **`trg_audit_prediction_insert`** (`AFTER INSERT ON Predictions`):
   * Records every ML inference event to `AuditLogs`.
4. **`trg_audit_bulk_changes`** (`AFTER INSERT OR UPDATE ON AdminReviews`):
   * Logs review entries; tags multi-row or cascaded modifications as `BULK_UPDATE`.
5. **`trg_update_model_timestamp`** (`BEFORE UPDATE ON Models`):
   * Maintains `updated_at` automatically whenever model hyperparameters or thresholds change.

---

## 7. Analytical Query Suite (9 Major Queries)

| # | Query Title | Business Function |
| :--- | :--- | :--- |
| **Q1** | Submission Full Detail | Fetches submission metadata, image path, model version, disease name, and confidence score for a given ID. |
| **Q2** | **Pending Low-Confidence Queue** | Populates the admin triage dashboard. Filters `status = 'low_confidence'` and sorts by confidence ascending (weakest first). |
| **Q3** | Admin Review History | Lists all reviews performed by a given specialist, comparing original predictions against expert diagnoses. |
| **Q4** | Disease Recommendations | Displays full treatment instructions, cultural practices, and citations linked to each disease. |
| **Q5** | Disease Volume Ranking | Ranks diseases by prediction frequency using `DENSE_RANK()`, with high vs. low confidence breakdowns. |
| **Q6** | Period Trend Comparison | Uses dual CTEs and `FULL OUTER JOIN` to compare diagnosis volumes between two 30-day windows and calculate percentage shifts. |
| **Q7** | Multi-Level Confidence Stats | Uses `GROUPING SETS` to generate overall, per-model, and per-disease confidence aggregates in one scan. |
| **Q8** | Ground-Truth Model Evaluation | Calculates true accuracy and per-disease precision by comparing AI predictions with verified `AdminReviews`. |
| **Q9** | Executive Reports (9a, 9b, 9c) | Three modular reporting blocks: (9a) Disease summary, (9b) Model performance scorecard, and (9c) Monthly volume metrics. |

---

## 8. Local File Storage Strategy for Images

In accordance with database best practices, leaf images are not stored as heavy binary blobs in PostgreSQL. Instead, the `Submissions.image_path` column stores clean relative paths.

```text
e:\softwareProject\
├── backend/
│   └── uploads/                  <-- Actual image files stored here
│       ├── leaf_001.jpg
│       └── leaf_002.jpg
└── database/
    └── Submissions.image_path    <-- Stores: '/uploads/leaf_001.jpg'
```

When running locally for demonstrations:
1. Your backend (Express / FastAPI / Flask) saves the uploaded image to the local `uploads/` folder.
2. Your backend serves this directory as static content:
   * **Express:** `app.use('/uploads', express.static('uploads'))`
   * **FastAPI:** `app.mount('/uploads', StaticFiles(directory='uploads'))`
3. Your frontend renders: `<img src="http://localhost:5000/uploads/leaf_001.jpg" />`.

---

## 9. File Execution Reference

* **In pgAdmin 4:** Open `leaflense_all_in_one.sql` in Query Tool $\rightarrow$ Press `F5` $\rightarrow$ Right-click Schemas and Refresh.
* **In Command Line (psql):** `psql -U postgres -d postgres -f 00_run_all.sql`
