# 🍃 LeafLens (LeafLense)

An image-based crop leaf disease detection web application and decision support platform developed as a university software development project.

The initial scope supports **rice crops**, providing disease classification, model confidence scores, visual explanations, and expert-verified agricultural recommendations.

---

## 🏗️ System Architecture & Technology Stack

The project is structured into three modular components:

* **Frontend:** React 18, TypeScript, Vite, Tailwind CSS (custom "Paddy & Earth" palette), Lucide Icons, IndexedDB (client-side demo persistence).
* **Backend:** Python (FastAPI, Uvicorn, Pydantic, CORS middleware).
* **Database (Academic DBMS Component):** PostgreSQL 12+, PL/pgSQL stored procedures & functions, automated trigger pipelines, `pgcrypto` authentication & security audit trails.
* **Computer Vision / ML (Roadmap):** Pillow, OpenCV, PyTorch / TensorFlow (under evaluation).

---

## 🌟 Key Features & Implementation Status

### 1. Public Farmer Experience (Anonymous & Accessible)
* **Frictionless Submission:** Farmers upload leaf photos and symptom notes without login barriers.
* **Automated Confidence Gating:** Predictions meeting or exceeding the model confidence threshold ($\ge 0.75$) are auto-accepted (`processed`).
* **Instant Actionable Guidance:** Auto-linked agricultural treatments and verified cultural practices ensure immediate support.
* **Submission Lookup:** Farmers can look up diagnostic reports using their `submission_id`.

### 2. Specialist / Administrator Portal
* **Low-Confidence Review Queue:** Predictions below the confidence threshold are flagged as `low_confidence` and routed for human expert triage.
* **Authenticated Review Workflow:** Session-based admin review interface backed by cryptographic token verification (`AdminSessions`).
* **Continuous Quality Feedback:** Specialist ground-truth reviews feed back into model evaluation.

### 3. Enterprise Database & Security
* **Dedicated Schema (`leaflense`):** 12 normalized relational tables.
* **Security & Auditing:** Automated trigger-driven audit ledger (`AuditLogs`) capturing all state transitions and admin authentication events (`LOGIN`, `LOGOUT`, `STATUS_CHANGE`).
* **Session Management:** Secure token hashing with SHA-256 and automatic session expiration.

---

## 📁 Repository Structure

```text
softwareProject/
├── backend/                                      # Python FastAPI Backend
│   ├── app/
│   │   ├── __init__.py
│   │   └── main.py                               # FastAPI application entry & health checks
│   ├── models/
│   │   └── README.md                             # ML weight storage placeholder (gitignored)
│   ├── .env.example                              # Backend environment variable template
│   └── requirements.txt                          # Pinned Python dependencies
│
├── Database/                                     # PostgreSQL Relational Database Architecture
│   ├── 00_run_all.sql                            # Master CLI execution runner for psql
│   ├── 01_schema.sql                             # DDL: 12 tables, custom ENUMs, roles, indexes
│   ├── 02_functions_procedures.sql               # PL/pgSQL: Auth, review workflow & farmer procedures
│   ├── 03_triggers.sql                           # Triggers: Prediction validator & audit logging
│   ├── 04_queries.sql                            # Production farmer lookup & admin review queries
│   ├── 05_seed_data.sql                          # Comprehensive sample seed data for all 12 tables
│   ├── leaflense_all_in_one.sql                  # Single self-contained script for pgAdmin 4
│   ├── LeafLense_Requirement_Database_Mapping.doc# Requirement-to-schema mapping documentation
│   ├── LeafLense_System_Catalogue_and_Workflow.md# Architectural workflow & catalogue reference
│   └── README.md                                 # Database-specific setup & testing guide
│
├── frontend/                                     # React + Vite + TypeScript Frontend
│   ├── src/
│   │   ├── api/                                  # API client connectors
│   │   ├── components/                           # UI components (Admin, Common, Upload)
│   │   ├── pages/                                # Route pages (Landing, Detect, Result, Admin)
│   │   ├── services/                             # Local persistence, simulation & mock auth
│   │   ├── types/                                # TypeScript definitions (api, disease, submission)
│   │   ├── App.tsx                               # Router configuration
│   │   ├── index.css                             # Tailwind styling
│   │   └── main.tsx                              # React DOM mount point
│   ├── package.json                              # Dependencies & build scripts
│   ├── package-lock.json                         # Pinned frontend lockfile
│   ├── tailwind.config.js                        # Custom Tailwind styling configuration
│   └── vite.config.ts                            # Vite configuration & /api reverse proxy
│
├── .gitignore                                    # Multi-stack gitignore rules
└── README.md                                     # Master project documentation & onboarding guide
```

---

## 🚀 Quick Start Guide

### Prerequisites
* **Node.js:** v18.0.0 or later (v20+ LTS recommended)
* **Python:** v3.9+ (Python 3.10 or 3.11 recommended)
* **PostgreSQL:** v12+ (with pgAdmin 4 or `psql` CLI)

---

### Step 1: Database Setup (PostgreSQL)

Choose either pgAdmin 4 or the command line:

#### Option A: Using pgAdmin 4 (Recommended - 1 Click)
1. Open **pgAdmin 4** and connect to your local PostgreSQL server.
2. Select or create your target database (e.g., `postgres` or `leaflense_db`).
3. Open **Tools** &rarr; **Query Tool**.
4. Open `Database/leaflense_all_in_one.sql` and run (**F5**).
5. Refresh the tree to see the `leaflense` schema with 12 tables and seed data.

#### Option B: Using `psql` CLI
```powershell
# Navigate into the Database directory
cd Database

# Execute master runner script
psql -U postgres -d postgres -f 00_run_all.sql
cd ..
```

---

### Step 2: Backend Setup (FastAPI)

Open a terminal in the project root:

```powershell
# Navigate to the backend directory
cd backend

# Create a virtual environment
python -m venv .venv

# Activate the virtual environment
# On Windows PowerShell:
.\.venv\Scripts\Activate.ps1
# On Linux / macOS:
# source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Start the development server
uvicorn app.main:app --reload --port 8000
```

Verify backend endpoints:
* **API Discovery:** [http://127.0.0.1:8000](http://127.0.0.1:8000)
* **Interactive Docs (Swagger):** [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)
* **Health Check:** [http://127.0.0.1:8000/api/v1/health](http://127.0.0.1:8000/api/v1/health)

---

### Step 3: Frontend Setup (React + Vite)

Open a second terminal in the project root:

```powershell
# Navigate to the frontend directory
cd frontend

# Install pinned dependencies
npm ci

# Start the Vite development server
npm run dev
```

The frontend will run at [http://127.0.0.1:5173](http://127.0.0.1:5173). Requests to `/api/*` are proxied to `http://127.0.0.1:8000`.

---

## 🎓 Academic Coursework Alignment

* **Software Development Lab (SDL):** Full-stack web application development, decoupled frontend/backend architecture, client UX, and ML model inference pipeline.
* **Database Management Systems (DBMS):** PostgreSQL schema design, entity-relationship integrity, stored procedures, audit triggers, index optimization, and role-based security in `Database/`.

---

## 👥 Team Collaboration Guidelines

* Always work on a feature branch (e.g., `git checkout -b feature/milestone-2-landing-page`).
* Run `npm ci` (not `npm install`) when pulling updates to maintain deterministic frontend dependencies.
* Never commit raw training datasets or model weight binaries (`.pth`, `.h5`) to git; store them inside `backend/models/`.
* When updating database schema or procedures, keep both individual migration scripts (`01`-`05`) and `Database/leaflense_all_in_one.sql` synchronized.
