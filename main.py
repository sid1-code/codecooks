"""
main.py - FastAPI backend for triage and health services

How to run the server:
    uvicorn main:app --reload

Requirements:
    pip install fastapi uvicorn sqlalchemy pydantic
"""

import logging
import os
from typing import List, Optional

from fastapi import FastAPI, Depends, HTTPException, Query, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session
from sqlalchemy.exc import SQLAlchemyError
from dotenv import load_dotenv

import models
import schemas
import crud

# Load environment variables from .env if present (before loading DB/AI modules)
load_dotenv()

from database import SessionLocal, engine, Base
import ai

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

# Create tables
Base.metadata.create_all(bind=engine)

def init_db():
    """Initialize database with sample data"""
    db = SessionLocal()
    try:
        # Ensure geolocation columns exist (SQLite simple migration)
        try:
            with engine.connect() as conn:
                cols = conn.exec_driver_sql("PRAGMA table_info(services);").fetchall()
                col_names = {row[1] for row in cols}
                if "latitude" not in col_names:
                    conn.exec_driver_sql("ALTER TABLE services ADD COLUMN latitude REAL;")
                if "longitude" not in col_names:
                    conn.exec_driver_sql("ALTER TABLE services ADD COLUMN longitude REAL;")
        except Exception as e:
            logger.warning(f"Skipping geo column migration: {e}")

        if db.query(models.Service).count() == 0:
            example_services = [
                models.Service(name="City Hospital", location="123 Main St", contact="555-1234", latitude=28.6139, longitude=77.2090),
                models.Service(name="Urgent Care Clinic", location="456 Elm St", contact="555-5678", latitude=28.5355, longitude=77.3910),
                models.Service(name="Emergency Room", location="789 Oak Ave", contact="911", latitude=28.4595, longitude=77.0266),
                models.Service(name="Family Clinic", location="321 Pine St", contact="555-9999", latitude=28.7041, longitude=77.1025),
            ]
            db.add_all(example_services)
            db.commit()
            logger.info("Database initialized with sample services")
    except Exception as e:
        logger.error(f"Error initializing database: {e}")
        db.rollback()
    finally:
        db.close()

init_db()

def get_db():
    """Database dependency"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# FastAPI app configuration
app = FastAPI(
    title="Business Management System API",
    description="A comprehensive API for triage and health services management",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# (Mock frontend removed) No static files mounted; root path returns 404 by default

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global exception handler
@app.exception_handler(SQLAlchemyError)
async def sqlalchemy_exception_handler(request, exc):
    logger.error(f"Database error: {exc}")
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"detail": "Internal server error"}
    )

@app.exception_handler(Exception)
async def general_exception_handler(request, exc):
    logger.error(f"Unexpected error: {exc}")
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"detail": "Internal server error"}
    )

# Health check endpoint
@app.get("/health")
def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "message": "BMS API is running"}

# Triage endpoint
@app.post("/triage", response_model=schemas.TriageResponse)
def triage(request: schemas.TriageRequest):
    """Perform medical triage based on symptoms"""
    try:
        symptom = request.symptom.lower().strip()
        
        # Emergency conditions
        emergency_keywords = ["breathing", "chest pain", "heart attack", "stroke", "severe bleeding", "unconscious"]
        if any(keyword in symptom for keyword in emergency_keywords):
            return schemas.TriageResponse(
                status="EMERGENCY",
                recommendation="Seek immediate emergency medical attention. Call 911."
            )
        
        # Urgent conditions
        urgent_keywords = ["fever", "diarrhea", "vomiting", "severe pain", "infection"]
        if any(keyword in symptom for keyword in urgent_keywords):
            return schemas.TriageResponse(
                status="URGENT",
                recommendation="Seek medical attention within 24 hours."
            )
        
        # Self-care conditions
        return schemas.TriageResponse(
            status="SELF-CARE",
            recommendation="Monitor symptoms. Consider over-the-counter remedies or consult a healthcare provider if symptoms persist."
        )
    except Exception as e:
        logger.error(f"Error in triage: {e}")
        raise HTTPException(status_code=500, detail="Error processing triage request")

# Service endpoints
@app.get("/services", response_model=List[schemas.ServiceOut])
def get_services(
    skip: int = Query(0, ge=0, description="Number of records to skip"),
    limit: int = Query(100, ge=1, le=1000, description="Maximum number of records to return"),
    db: Session = Depends(get_db)
):
    """Get all services with pagination"""
    try:
        services = crud.get_services(db, skip=skip, limit=limit)
        return services
    except Exception as e:
        logger.error(f"Error fetching services: {e}")
        raise HTTPException(status_code=500, detail="Error fetching services")

# Define static service routes BEFORE the dynamic '/services/{service_id}'
# Service search endpoint
@app.get("/services/search", response_model=List[schemas.ServiceOut])
def search_services(q: str = Query(..., min_length=1, max_length=100), limit: int = Query(20, ge=1, le=100), db: Session = Depends(get_db)):
    """Search services by text query across name, location, contact."""
    try:
        return crud.search_services(db, query=q, limit=limit)
    except Exception as e:
        logger.error(f"Error searching services: {e}")
        raise HTTPException(status_code=500, detail="Error searching services")

# Nearby services endpoint
@app.get("/services/nearby", response_model=List[schemas.ServiceOut])
def services_nearby(
    lat: float = Query(..., ge=-90, le=90, description="Latitude"),
    lon: float = Query(..., ge=-180, le=180, description="Longitude"),
    radius_km: float = Query(10.0, gt=0, le=2000, description="Search radius in kilometers"),
    limit: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
):
    try:
        return crud.nearby_services(db, lat=lat, lon=lon, radius_km=radius_km, limit=limit)
    except Exception as e:
        logger.error(f"Error fetching nearby services: {e}")
        raise HTTPException(status_code=500, detail="Error fetching nearby services")

@app.get("/services/{service_id}", response_model=schemas.ServiceOut)
def get_service(service_id: int, db: Session = Depends(get_db)):
    """Get a specific service by ID"""
    try:
        service = crud.get_service(db, service_id=service_id)
        if service is None:
            raise HTTPException(status_code=404, detail="Service not found")
        return service
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching service {service_id}: {e}")
        raise HTTPException(status_code=500, detail="Error fetching service")

@app.post("/services", response_model=schemas.ServiceOut, status_code=status.HTTP_201_CREATED)
def create_service(service: schemas.ServiceCreate, db: Session = Depends(get_db)):
    """Create a new service"""
    try:
        return crud.create_service(db=db, service=service)
    except Exception as e:
        logger.error(f"Error creating service: {e}")
        raise HTTPException(status_code=500, detail="Error creating service")

@app.put("/services/{service_id}", response_model=schemas.ServiceOut)
def update_service(service_id: int, service_update: schemas.ServiceUpdate, db: Session = Depends(get_db)):
    """Update an existing service"""
    try:
        service = crud.update_service(db=db, service_id=service_id, service_update=service_update)
        if service is None:
            raise HTTPException(status_code=404, detail="Service not found")
        return service
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating service {service_id}: {e}")
        raise HTTPException(status_code=500, detail="Error updating service")

@app.delete("/services/{service_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_service(service_id: int, db: Session = Depends(get_db)):
    """Delete a service"""
    try:
        success = crud.delete_service(db=db, service_id=service_id)
        if not success:
            raise HTTPException(status_code=404, detail="Service not found")
        return None
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting service {service_id}: {e}")
        raise HTTPException(status_code=500, detail="Error deleting service")


# AI endpoints
@app.post("/ai/triage-advice", response_model=schemas.AITriageAdviceResponse)
def ai_triage_advice(req: schemas.AITriageAdviceRequest):
    """AI-generated triage advice with safety prompts and multilingual response."""
    try:
        messages = ai.get_triage_advice_payload(
            symptom=req.symptom,
            age=req.age,
            sex=req.sex,
            pregnant=req.pregnant,
            chronic_conditions=req.chronic_conditions,
            location=req.location,
            language=req.language,
        )
        advice = ai.safe_call(messages)
        return schemas.AITriageAdviceResponse(advice=advice)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"AI triage advice error: {e}")
        raise HTTPException(status_code=500, detail="AI triage advice error")

@app.post("/ai/chat", response_model=schemas.AIChatResponse)
def ai_chat(req: schemas.AIChatRequest):
    """General health information chat with safety constraints."""
    try:
        # Convert schema messages into plain dicts
        history = [{"role": m.role, "content": m.content} for m in req.history]
        messages = ai.get_chat_payload(history=history, language=req.language)
        reply = ai.safe_call(messages)
        return schemas.AIChatResponse(reply=reply)
    except Exception as e:
        logger.error(f"AI chat error: {e}")
        raise HTTPException(status_code=500, detail="AI chat error")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
