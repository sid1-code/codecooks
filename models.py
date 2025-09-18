from sqlalchemy import Column, Integer, String, Float
from database import Base

class Service(Base):
    __tablename__ = "services"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    location = Column(String, nullable=False)
    contact = Column(String, nullable=False)
    # Geolocation (nullable for backward compatibility)
    # Latitude ranges from -90 to 90, Longitude from -180 to 180
    # Using String or Float? Use String simplifies SQLite ALTER in some cases, but Float is appropriate.
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
