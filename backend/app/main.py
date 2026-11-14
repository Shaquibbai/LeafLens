from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from typing import Dict, Any

app = FastAPI(
    title="LeafLens API",
    description="Backend API for LeafLens crop leaf disease detection",
    version="0.1.0",
)

# Configure CORS for local development
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:5173",
        "http://127.0.0.1:5173",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
def read_root() -> Dict[str, str]:
    """Root endpoint for basic ping and API discovery."""
    return {
        "message": "LeafLens Backend API is running.",
        "docs_url": "/docs",
        "health_check": "/api/v1/health",
    }


@app.get("/api/v1/health")
def health_check() -> Dict[str, Any]:
    """Health check endpoint to verify backend operational readiness.Returns service metadata, supported crop list, and provisional model status."""
    return {
        "status": "healthy",
        "service": "LeafLens Backend",
        "version": "0.1.0",
        "supported_crops": ["rice"],
        "model_status": "provisional",
    }
