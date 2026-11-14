# LeafLens 

An image-based crop leaf disease detection web application developed as a six-member university software development project.

The initial scope supports **rice only**, providing leaf disease identification, model confidence scores, explanations, and verifiable agricultural recommendations.

---

## Technology Stack

* **Frontend:** React 18, TypeScript, Vite, Tailwind CSS, Lucide Icons
* **Backend:** Python (FastAPI, Uvicorn, Pydantic)
* **Image Processing & ML (Planned for Future Milestones):** Pillow, OpenCV, PyTorch / TensorFlow (under evaluation)

---

## Implementation Status

### Implemented(Repository Foundation & Scaffold)
* **Decoupled Architecture:** Clean separation into `frontend/` and `backend/` directories.
* **FastAPI Backend Service:** Running with CORS middleware, discovery route (`GET /`), and health check endpoint (`GET /api/v1/health`).
* **React + Vite Frontend:** Modern React 18 with TypeScript and Tailwind CSS configured with the custom "Paddy & Earth" palette.
* **API Reverse Proxy:** Vite dev server proxies `/api/*` requests directly to `http://127.0.0.1:8000`.
* **System Connectivity Dashboard:** A verification view in `frontend/src/App.tsx` that pings the backend and displays active status and metadata.
* **Deterministic Dependencies:** Frontend dependencies are locked through `frontend/package-lock.json`, while backend dependencies are pinned in `backend/requirements.txt`.

### Planned(Not Yet Implemented)
* Landing page visual layout, brand elements, and crop selector locked to rice.
* Leaf image upload zone, file validation, instant preview, and photography guidance.
* Backend `POST /api/v1/predict` endpoint, Pillow image pipeline, and provisional rice disease knowledge base.
* Diagnostic results view with model confidence meter, symptoms, and actionable recommendations.
* Machine learning model training, weight export, and inference integration.
* Cross-device testing, accessibility audits, and final team presentation polish.

---

## Repository Structure

```
LeafLens/
├── backend/
│   ├── app/
│   │   ├── __init__.py
│   │   └── main.py         # FastAPI entry point with /api/v1/health
│   ├── models/
│   │   └── README.md       # Storage placeholder for ML weights (gitignored)
│   └── requirements.txt    # Pinned backend dependencies
│
├── frontend/
│   ├── src/
│   │   ├── api/
│   │   │   └── client.ts   # Client function for backend health check
│   │   ├── types/
│   │   │   └── api.ts      # TypeScript interfaces for API responses
│   │   ├── App.tsx         # Milestone 1 scaffold & connectivity verification
│   │   ├── index.css       # Tailwind directives & global styling
│   │   └── main.tsx        # React DOM render entry point
│   ├── index.html          # HTML page entry
│   ├── package.json        # Frontend dependencies and npm scripts
│   ├── package-lock.json   # Lockfile for consistent dependency resolution
│   ├── postcss.config.js   # PostCSS configuration
│   ├── tailwind.config.js  # "Paddy & Earth" custom palette configuration
│   ├── tsconfig.app.json   # TypeScript application configuration
│   ├── tsconfig.json       # TypeScript root project references
│   ├── tsconfig.node.json  # TypeScript configuration for Vite
│   └── vite.config.ts      # Vite config with /api proxy to FastAPI
│
├── .gitignore              # Multi-stack gitignore rules
└── README.md               # Project documentation & setup guide
```

---

## Quick Start Guide for Team Members (Windows Setup)

### System Prerequisites
* **Node.js:** v18.0.0 or later (v20+ or v24 LTS recommended)
* **Python:**
  * **Tested & Verified Runtime:** Python 3.9.2 (64-bit on Windows)
  * **Recommended Team Target:** Python 3.11 (or 3.10) for long-term cross-platform compatibility across Windows, macOS, and Linux. *(Note: Python 3.11 was not present on the development machine during verification, so physical execution was verified using Python 3.9.2).*

---

### Step 1: Clone the Repository
```powershell
git clone https://github.com/Shaquibbai/LeafLens.git
cd LeafLens
```

---

### Step 2: Backend Setup (FastAPI)

Open **Terminal 1** (PowerShell) in the project root:

```powershell
# Navigate to the backend directory
cd backend

# Create a virtual environment
python -m venv .venv

# Activate the virtual environment
.\.venv\Scripts\Activate.ps1
# If PowerShell restricts scripts, run once:
# Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process

# Install pinned dependencies
pip install -r requirements.txt

# Start the FastAPI development server
uvicorn app.main:app --reload --port 8000
```

Verify backend URLs:
* API Discovery: `http://127.0.0.1:8000`
* Interactive API Docs (Swagger): `http://127.0.0.1:8000/docs`
* Health Check: `http://127.0.0.1:8000/api/v1/health`

---

### Step 3: Frontend Setup (React + Vite)

Open **Terminal 2** (PowerShell) in the project root:

```powershell
# Navigate to the frontend directory
cd frontend

# Install dependencies using the lockfile for consistent dependency resolution
npm ci

# Start the Vite development server
npm run dev
```

The frontend will start at:
* Local URL: `http://127.0.0.1:5173`

Requests to `/api/*` are automatically forwarded by Vite to `http://127.0.0.1:8000`.

---

### Step 4: Verification

Open `http://127.0.0.1:5173` in your browser. You should see the **LeafLens System Connectivity Verification** screen showing an active green status with data fetched from the backend's `/api/v1/health` endpoint:

```json
{
  "status": "healthy",
  "service": "LeafLens Backend",
  "version": "0.1.0",
  "supported_crops": ["rice"],
  "model_status": "provisional"
}
```

---

## Related Academic Component: DBMS

* **Mandatory Database System:** **PostgreSQL** is the required Relational Database Management System (DBMS) for the academic DBMS course component of LeafLens, as specifically instructed by the course teacher.
* **Scope of DBMS Coursework:** The DBMS component will use PostgreSQL for relational database design, implementation, queries, stored procedures, functions, triggers, and other required database operations as mandated by the course curriculum.
* **Separation of Academic Concerns:** This DBMS coursework requirement is a **separate academic component** from the initial Software Development Lab (SDL) application scope.
* **Current SDL Application Scope:** PostgreSQL integration is not part of the current Milestone 1 implementation. The application currently uses a decoupled React frontend and Python + FastAPI backend without database dependencies. Any future database integration will be considered separately if required by the SDL scope.

---

## Team Collaboration Guidelines

* Always work on a feature branch (e.g., `git checkout -b feature/milestone-2-landing-page`).
* Run `npm ci` (not `npm install`) when pulling updates to maintain consistent dependency resolution from `package-lock.json`.
* Keep model files inside `backend/models/`, which is ignored by Git. Never commit raw datasets or `.pth` / `.h5` files.
