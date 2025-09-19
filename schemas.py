from pydantic import BaseModel, Field, ConfigDict
from typing import Optional, List

class TriageRequest(BaseModel):
    symptom: str = Field(..., min_length=1, max_length=500, description="Patient symptom description")

class TriageResponse(BaseModel):
    status: str = Field(..., description="Triage status: EMERGENCY, URGENT, or SELF-CARE")
    recommendation: Optional[str] = Field(None, description="Additional recommendation")

class ServiceBase(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    location: str = Field(..., min_length=1, max_length=200)
    contact: str = Field(..., min_length=1, max_length=50)
    latitude: Optional[float] = Field(None, ge=-90, le=90, description="Latitude of the service")
    longitude: Optional[float] = Field(None, ge=-180, le=180, description="Longitude of the service")

class ServiceCreate(ServiceBase):
    pass

class ServiceUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    location: Optional[str] = Field(None, min_length=1, max_length=200)
    contact: Optional[str] = Field(None, min_length=1, max_length=50)
    latitude: Optional[float] = Field(None, ge=-90, le=90)
    longitude: Optional[float] = Field(None, ge=-180, le=180)

class ServiceOut(ServiceBase):
    id: int
    
    model_config = ConfigDict(from_attributes=True)

# ---- AI Schemas ----

class AITriageAdviceRequest(BaseModel):
    symptom: str = Field(..., min_length=1, max_length=1000)
    age: Optional[int] = Field(None, ge=0, le=120)
    sex: Optional[str] = Field(None, description="male|female|other")
    pregnant: Optional[bool] = None
    chronic_conditions: Optional[List[str]] = None
    location: Optional[str] = None
    language: Optional[str] = Field(None, description="Target response language, e.g., English, Arabic")

class AITriageAdviceResponse(BaseModel):
    advice: str
    confidence: float | None = Field(None, ge=0, le=1, description="Model self-reported or heuristic confidence (0-1)")

class AIChatMessage(BaseModel):
    role: str = Field(..., description="user or assistant")
    content: str = Field(..., min_length=1)

class AIChatRequest(BaseModel):
    history: List[AIChatMessage] = Field(..., description="Ordered list of messages")
    language: Optional[str] = Field(None, description="Target response language")

class AIChatResponse(BaseModel):
    reply: str
