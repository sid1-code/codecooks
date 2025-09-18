from sqlalchemy.orm import Session
from sqlalchemy.exc import SQLAlchemyError
from typing import List, Optional
from sqlalchemy import or_
import models
import schemas
import logging
import math

logger = logging.getLogger(__name__)

def get_services(db: Session, skip: int = 0, limit: int = 100) -> List[models.Service]:
    """Get all services with pagination"""
    try:
        return db.query(models.Service).offset(skip).limit(limit).all()
    except SQLAlchemyError as e:
        logger.error(f"Error fetching services: {e}")
        raise

def get_service(db: Session, service_id: int) -> Optional[models.Service]:
    """Get a single service by ID"""
    try:
        return db.query(models.Service).filter(models.Service.id == service_id).first()
    except SQLAlchemyError as e:
        logger.error(f"Error fetching service {service_id}: {e}")
        raise

def create_service(db: Session, service: schemas.ServiceCreate) -> models.Service:
    """Create a new service"""
    try:
        db_service = models.Service(**service.model_dump())
        db.add(db_service)
        db.commit()
        db.refresh(db_service)
        logger.info(f"Created service: {db_service.name}")
        return db_service
    except SQLAlchemyError as e:
        db.rollback()
        logger.error(f"Error creating service: {e}")
        raise

def update_service(db: Session, service_id: int, service_update: schemas.ServiceUpdate) -> Optional[models.Service]:
    """Update an existing service"""
    try:
        db_service = get_service(db, service_id)
        if not db_service:
            return None
        
        update_data = service_update.model_dump(exclude_unset=True)
        for field, value in update_data.items():
            setattr(db_service, field, value)
        
        db.commit()
        db.refresh(db_service)
        logger.info(f"Updated service {service_id}")
        return db_service
    except SQLAlchemyError as e:
        db.rollback()
        logger.error(f"Error updating service {service_id}: {e}")
        raise

def delete_service(db: Session, service_id: int) -> bool:
    """Delete a service"""
    try:
        db_service = get_service(db, service_id)
        if not db_service:
            return False
        
        db.delete(db_service)
        db.commit()
        logger.info(f"Deleted service {service_id}")
        return True
    except SQLAlchemyError as e:
        db.rollback()
        logger.error(f"Error deleting service {service_id}: {e}")
        raise

def search_services(db: Session, query: str, limit: int = 20) -> List[models.Service]:
    """Simple text search across name, location, and contact fields."""
    try:
        like = f"%{query}%"
        return (
            db.query(models.Service)
            .filter(
                or_(
                    models.Service.name.ilike(like),
                    models.Service.location.ilike(like),
                    models.Service.contact.ilike(like),
                )
            )
            .limit(limit)
            .all()
        )
    except SQLAlchemyError as e:
        logger.error(f"Error searching services with query '{query}': {e}")
        raise

def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate Haversine distance between two points in kilometers."""
    R = 6371.0
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi/2)**2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c

def nearby_services(db: Session, lat: float, lon: float, radius_km: float = 10.0, limit: int = 20) -> List[models.Service]:
    """Return services within radius_km of (lat, lon), sorted by distance ascending."""
    try:
        # Fetch candidates with non-null coordinates
        candidates = (
            db.query(models.Service)
            .filter(models.Service.latitude.isnot(None), models.Service.longitude.isnot(None))
            .all()
        )
        with_dist = []
        for s in candidates:
            try:
                d = haversine_km(lat, lon, float(s.latitude), float(s.longitude))
            except Exception:
                continue
            if d <= radius_km:
                with_dist.append((d, s))
        with_dist.sort(key=lambda x: x[0])
        return [s for d, s in with_dist[:limit]]
    except SQLAlchemyError as e:
        logger.error(f"Error computing nearby services: {e}")
        raise
