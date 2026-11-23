# LeafLense: Complete System Catalogue & Architectural Workflow Guide

**System:** Crop Leaf Disease Detection & Decision Support Platform  
**Database Engine:** PostgreSQL 12+ (Tested on PostgreSQL 18)  
**Workspace Directory:** `e:\softwareProject\softwareProject\`  
**Date of Implementation:** November 2026  

---

## 1. Executive Summary & Core Concept

**LeafLense** is an enterprise-grade, web-based agricultural disease identification platform designed for farmers, agricultural extension workers, and plant pathologists. 

Farmers can upload leaf images anonymously (no registration barrier) and look up their submission report by submission ID. The system records submissions, predictions, confidence scores, and model metadata. 

Predictions falling below the active model's confidence threshold are automatically queued for administrator review. Admins log in from the corner-tab login page using a username and password, review pending low-confidence submissions, and confirm or correct the diagnosis (or reject invalid uploads) so farmers receive verified results.

---

## 2. End-to-End System Workflow

```
   [ FARMER / PUBLIC USER ]
             |
             | 1. Uploads leaf photo (No login required)
             v
   [ Web / Mobile Frontend ]
             |
             | 2. Saves file to local storage (e.g., /uploads/leaf_001.jpg)
             | 3. Calls: submit_leaf_sample('/uploads/leaf_001.jpg', OUT v_id, p_additional_info)
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
   * Farmer report immediately shows:                             * Farmer report shows:
     - Disease Name, Symptoms,                                      status = 'pending'
       Treatment Recommendations                                    (predictions kept hidden)
                                                                            |
                                                                            v
                                                               [ Corner Tab -> Admin Login ]
                                                                login_admin(username, password)
                                                                            |
                                                                            v
                                                               [ Admin Review Queue ]
                                                                get_pending_low_confidence_submissions(token)
                                                                            |
                                                                            | 6. Admin inspects leaf
                                                                            | 7. Calls review_low_confidence_case()
                                                                            |    or reject_submission()
                                                                            v
                                                                 Status -> 'reviewed' / 'rejected'
                                                                 (Farmer report now shows verified result)
```

---

## 3. Database Table Catalogue (12 Tables)

| Table Name | Primary Key | Foreign Keys & Relationships | Core Business Purpose |
| :--- | :--- | :--- | :--- |
| **`AdminUsers`** | `admin_id` (`SERIAL`) | None | System administrators (`role = 'admin'`). Stores username, bcrypt password hashes, lockout state, and active status. |
| **`AdminSessions`** | `session_id` (`SERIAL`) | `admin_id` | Stores hashed session tokens (`token_hash`), expiration, and revocation flags for logged-in admins. |
| **`Models`** | `model_id` (`SERIAL`) | None (Unique on `model_name, version`) | Registry of computer vision models. Stores active status flag and `confidence_threshold` ($0.0 - 1.0$). |
| **`Diseases`** | `disease_id` (`SERIAL`) | None (Unique on `disease_name`) | Catalogue of crop diseases. Includes symptoms description shown to farmers and contains a baseline `Healthy` class. |
| **`Submissions`** | `submission_id` (`SERIAL`) | None (Referenced by Predictions, Reviews, History) | Farmer leaf image uploads. Tracks local file path, farmer notes, submission timestamp, client IP, and lifecycle status. |
| **`Predictions`** | `prediction_id` (`SERIAL`) | `submission_id`, `model_id`, `disease_id` | Classification output scores. Flags the top winning prediction per submission via `is_top_prediction`. |
| **`ModelClasses`** | `model_class_id` (`SERIAL`) | `model_id`, `disease_id` | Many-to-Many bridge defining which disease classes each model is certified to predict. |
| **`AdminReviews`** | `review_id` (`SERIAL`) | `submission_id`, `admin_id`, `assessed_disease_id` | Manual admin reviews of low-confidence cases. Records diagnosis, correctness verdict, and observational notes. |
| **`Recommendations`** | `recommendation_id` (`SERIAL`) | None | Curated treatment advice, chemical/biological remedies, cultural practices, and advisory citations. |
| **`DiseaseRecommendations`** | `(disease_id, recommendation_id)` | `disease_id`, `recommendation_id` | Many-to-Many mapping associating multiple treatments and management guidelines to each specific disease. |
| **`SubmissionStatusHistory`** | `history_id` (`SERIAL`) | `submission_id` | Immutable state transition ledger tracking status progression (e.g., `pending` $\rightarrow$ `low_confidence` $\rightarrow$ `reviewed`). |
| **`AuditLogs`** | `audit_id` (`SERIAL`) | None | System-wide security and compliance ledger capturing actor identity, action type (including login/logout events), and old/new JSONB row snapshots. |

---

## 4. Stored Functions (Admin Auth & Role-Gated Access)

Administrative functions run as `SECURITY DEFINER` and verify an active `AdminSessions` token belonging to an active `'admin'` user (or `leaflense_admin`/`postgres` DB roles).

### 1. `login_admin(p_username, p_password, p_ip_address, p_user_agent)`
* **Description:** Authenticates an admin from the corner-tab login page using bcrypt (`pgcrypto`), enforces temporary lockouts after repeated failed logins, issues a 12-hour session token, and returns admin profile and capabilities.

### 2. `verify_admin_session(p_session_token)`
* **Description:** Validates an active session token and refreshes `last_activity_at`.

### 3. `logout_admin(p_session_token) -> BOOLEAN`
* **Description:** Revokes an active session token and logs a `LOGOUT` entry in `AuditLogs`.

### 4. `get_pending_low_confidence_submissions(p_session_token)`
* **Description:** Returns all submissions in `'low_confidence'` status sorted by lowest confidence score first for the authenticated admin review queue.

### 5. `get_farmer_submission_report(p_submission_id)`
* **Description:** Login-free farmer report lookup. Hides predictions and recommendations (`NULL`) with `status = 'pending'` while `'pending'` or `'low_confidence'`, and returns the AI or admin-verified diagnosis and recommendations once `'processed'` or `'reviewed'`.

### 6. `fn_get_role_privileges(p_role)` & `fn_require_admin_privilege(p_session_token)`
* **Description:** Internal privilege mapping and session/role enforcement helpers for `'admin'` users.

---

## 5. Stored Procedures (Application State Machine)

### 1. `submit_leaf_sample(IN p_image_path, OUT p_submission_id, IN p_additional_info, IN p_ip_address, IN p_user_agent)`
* Atomically creates an anonymous farmer submission record with initial status `'pending'`.
* Immediately writes the initial baseline entry into `SubmissionStatusHistory`.
* Returns the newly generated `submission_id` for frontend reference.

### 2. `record_prediction(IN p_submission_id, IN p_model_id, IN p_disease_id, IN p_confidence_score, IN p_is_top_prediction)`
* Validates model status, class support, and confidence range ($0.0 - 1.0$).
* Inserts the prediction row into `Predictions`.
* **Automated Routing:** If `p_is_top_prediction = TRUE`:
  * If `p_confidence_score >= threshold` $\rightarrow$ Sets status to `'processed'`.
  * If `p_confidence_score < threshold` $\rightarrow$ Sets status to `'low_confidence'`.
  * Logs the transition into `SubmissionStatusHistory`.

### 3. `review_low_confidence_case(IN p_submission_id, IN p_admin_id, IN p_assessed_disease_id, IN p_is_correct, IN p_notes, IN p_session_token)`
* Validates admin session and that the target submission is currently in `'low_confidence'` state.
* Records the admin's assessment and correctness verdict in `AdminReviews`.
* Updates the submission status to `'reviewed'`.
* Records the admin's username and timestamp in `SubmissionStatusHistory`.

### 4. `reject_submission(IN p_submission_id, IN p_reason, IN p_admin_id, IN p_session_token)`
* Validates admin session and transitions a `'pending'` or `'low_confidence'` submission to `'rejected'`, logging the rejection reason in `AdminReviews` and `SubmissionStatusHistory`.

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
   * Maintains `updated_at` automatically whenever model thresholds or active flags change.

---

## 7. Query Suite (`04_queries.sql`)

| # | Query Title | Business Function |
| :--- | :--- | :--- |
| **Q1** | Farmer Report Lookup | Fetches the farmer-facing submission report for a given `submission_id` without login (`get_farmer_submission_report`). |
| **Q2** | **Pending Low-Confidence Queue** | Populates the admin review queue (`v_pending_low_confidence_reviews`). Filters `status = 'low_confidence'` and sorts by confidence ascending. |
| **Q3** | Admin Review History | Lists all reviews performed by a given admin, comparing original predictions against admin diagnoses. |
| **Q4** | Disease Recommendations | Displays full treatment instructions, cultural practices, and citations linked to each disease. |
| **Q5** | Frontend Integration Smoke Test | Demonstrates the end-to-end SQL calls: `login_admin`, `verify_admin_session`, `get_pending_low_confidence_submissions`, `review_low_confidence_case`, `logout_admin`, and login-free `submit_leaf_sample`. |

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
