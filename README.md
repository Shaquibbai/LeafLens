# 🍃 LeafLense: Crop Leaf Disease Detection & Decision Support Database

[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-12%2B-blue.svg)](https://www.postgresql.org/)
[![pgAdmin](https://img.shields.io/badge/pgAdmin-4-green.svg)](https://www.pgadmin.org/)
[![License](https://img.shields.io/badge/License-MIT-brightgreen.svg)](#)

**LeafLense** is an enterprise-grade relational database architecture for a web-based agricultural disease detection system. 

Farmers and agricultural workers can upload leaf photos without registration to identify crop diseases through an AI image classification model. Low-confidence predictions are automatically sequestered for administrator review, ensuring high diagnostic reliability while building an expert-verified dataset for continuous model retraining.

---

## 📌 Key System Features

* **Anonymous Farmer Submissions:** Frictionless upload process; farmers submit photos and symptom notes without login barriers.
* **Automated Confidence Gating:** Predictions meeting or exceeding active model threshold (e.g., $\ge 0.75$) are auto-accepted (`processed`).
* **Human-in-the-Loop Triage:** Predictions below threshold are flagged as `low_confidence` for agricultural specialist assessment.
* **Auto-Linked Treatments:** Pre-mapped disease-to-recommendation links guarantee farmers receive verified agricultural advice.
* **Immutable State Audit Trail:** Every status change is captured in `SubmissionStatusHistory` and `AuditLogs` via triggers.
* **Continuous Model Evaluation:** Ground-truth admin reviews dynamically feed accuracy and precision metrics (`calculate_model_performance`).

---

## 🗄️ Database Schema (11 Tables)

All tables reside in the dedicated **`leaflense`** schema:

| Table Name | Primary Key | Foreign Keys | Purpose |
| :--- | :--- | :--- | :--- |
| **`AdminUsers`** | `admin_id` | — | Platform administrators, review specialists, and analysts. |
| **`Models`** | `model_id` | — | Computer vision model registry and active confidence thresholds. |
| **`Diseases`** | `disease_id` | — | Disease catalogue (symptoms description + baseline Healthy class). |
| **`Submissions`** | `submission_id` | — | Farmer uploads, image paths, additional notes, and lifecycle status. |
| **`Predictions`** | `prediction_id` | `submission_id`, `model_id`, `disease_id` | Model classification scores and top prediction flags. |
| **`ModelClasses`** | `model_class_id` | `model_id`, `disease_id` | Certified disease classes supported by each AI model (M:N). |
| **`AdminReviews`** | `review_id` | `submission_id`, `admin_id`, `assessed_disease_id` | Human specialist review records for low-confidence cases. |
| **`Recommendations`**| `recommendation_id`| — | Agricultural treatment advice, cultural practices, and citations. |
| **`DiseaseRecommendations`** | `(disease_id, recommendation_id)` | `disease_id`, `recommendation_id` | M:N mapping linking verified treatments to each specific disease. |
| **`SubmissionStatusHistory`** | `history_id` | `submission_id` | State transition audit ledger (`pending` &rarr; `low_confidence` &rarr; `reviewed`). |
| **`AuditLogs`** | `audit_id` | — | Immutable security audit trail with JSONB before/after snapshots. |

---

## 🚀 Quick Setup Guide (First-Time Load)

### Option 1: Using pgAdmin 4 (Recommended - 1 Click)

1. Open **pgAdmin 4** and connect to your local PostgreSQL server.
2. In the left tree panel, click on your target database (e.g., **`postgres`** or create `leaflense_db`).
3. In the top navigation bar, open **Tools** &rarr; **Query Tool**.
4. Click the **Folder icon (Open File)** and select:
   ```text
   leaflense_all_in_one.sql
   ```
   *(Or copy and paste the contents of `leaflense_all_in_one.sql` into the Query Tool).*
5. Click the **Play button** (or press **`F5`**).
6. In the left panel, right-click **Schemas** &rarr; select **Refresh**.
7. Expand **`leaflense` &rarr; `Tables`** to inspect all 11 tables with preloaded test data!

---

### Option 2: Using the Command Line (`psql`)

Open PowerShell or Command Prompt, navigate to the project directory, and run:

```bash
cd /d e:\softwareProject\softwareProject
psql -U postgres -d postgres -f 00_run_all.sql
```
*(Enter your PostgreSQL password when prompted. All schemas, logic, and seed data will be loaded automatically).*

---

## 🧪 Testing & Verifying in pgAdmin

Once loaded, open pgAdmin's **Query Tool** and test the system components:

```sql
SET search_path = leaflense, public;

-- 1. Check the active model threshold (returns 0.7500)
SELECT get_active_confidence_threshold();

-- 2. Check model performance & accuracy against admin ground-truth reviews
SELECT * FROM calculate_model_performance(1);

-- 3. View disease outbreak statistics & high vs low confidence counts
SELECT * FROM get_disease_statistics();

-- 4. View the Pending Low-Confidence Review Queue (For Admin GUI Tab)
SELECT * FROM v_pending_low_confidence_reviews;

-- 5. Test reviewing a low-confidence case (Moves submission #5 to 'reviewed')
CALL review_low_confidence_case(
    5,                                                  -- submission_id
    2,                                                  -- admin_id
    5,                                                  -- assessed_disease_id (Rice Blast)
    TRUE,                                               -- is_correct
    'Confirmed Rice Blast after manual leaf inspection' -- expert notes
);
```

---

## 🔌 Frontend & Backend Integration

The database is built ready to connect to any backend framework (**Python FastAPI/Flask** or **Node.js Express**):

### 1. Farmer Form (Submit Leaf + Notes)
* **API Route:** `POST /api/submit`
* **Calls:**
  ```sql
  CALL submit_leaf_sample('/uploads/leaf_010.jpg', v_id, 'Yellow spots on lower leaves');
  ```

### 2. Admin Review Tab (View Pending Cases)
* **API Route:** `GET /api/admin/pending-reviews`
* **Queries:**
  ```sql
  SELECT * FROM v_pending_low_confidence_reviews;
  ```
* **Returns:** JSON array with leaf image path, farmer notes, AI diagnosis, confidence score, and days pending.

### 3. Admin Assessment Form (Submit Diagnosis)
* **API Route:** `POST /api/admin/submit-review`
* **Calls:**
  ```sql
  CALL review_low_confidence_case(
      p_submission_id       := 4,
      p_admin_id            := 2,
      p_assessed_disease_id := 1,     -- Selected Disease
      p_is_correct          := FALSE, -- Verdict
      p_notes               := 'Confirmed Late Blight.' -- Expert Notes
  );
  ```

---

## 📁 Repository Structure

```text
├── 00_run_all.sql                                -- Master execution runner for psql CLI
├── 01_schema.sql                                 -- DDL: 11 tables, custom ENUMs, roles, indexes
├── 02_functions_procedures.sql                    -- PL/pgSQL: Admin functions & state procedures
├── 03_triggers.sql                               -- Triggers: Prediction validator & audit logging
├── 04_queries.sql                                -- 9 analytical & reporting queries
├── 05_seed_data.sql                              -- Sample test data for all tables
├── leaflense_all_in_one.sql                      -- Single consolidated file for pgAdmin 4
├── LeafLense_Requirement_Database_Mapping.doc    -- Word doc: Feature-to-column mapping table
├── LeafLense_System_Catalogue_and_Workflow.doc   -- Word doc: Full system architectural guide
├── LeafLense_System_Catalogue_and_Workflow.md    -- Markdown: Architectural workflow reference
└── README.md                                     -- Project documentation & onboarding guide
```

---

## 📄 License
This project is licensed under the MIT License.
