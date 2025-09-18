"""
Comprehensive test suite for the BMS API
"""

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from main import app, get_db
from database import Base
import models

# Test database setup
SQLALCHEMY_DATABASE_URL = "sqlite:///./test.db"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base.metadata.create_all(bind=engine)

def override_get_db():
    try:
        db = TestingSessionLocal()
        yield db
    finally:
        db.close()

app.dependency_overrides[get_db] = override_get_db

client = TestClient(app)

@pytest.fixture
def test_db():
    """Create a fresh database for each test"""
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)

class TestHealthCheck:
    def test_health_check(self):
        """Test health check endpoint"""
        response = client.get("/health")
        assert response.status_code == 200
        assert response.json() == {"status": "healthy", "message": "BMS API is running"}

class TestTriage:
    def test_triage_emergency(self):
        """Test emergency triage classification"""
        response = client.post("/triage", json={"symptom": "chest pain"})
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "EMERGENCY"
        assert "911" in data["recommendation"]

    def test_triage_urgent(self):
        """Test urgent triage classification"""
        response = client.post("/triage", json={"symptom": "high fever"})
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "URGENT"
        assert "24 hours" in data["recommendation"]

    def test_triage_self_care(self):
        """Test self-care triage classification"""
        response = client.post("/triage", json={"symptom": "mild headache"})
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "SELF-CARE"

    def test_triage_empty_symptom(self):
        """Test triage with empty symptom"""
        response = client.post("/triage", json={"symptom": ""})
        assert response.status_code == 422  # Validation error

    def test_triage_invalid_input(self):
        """Test triage with invalid input"""
        response = client.post("/triage", json={})
        assert response.status_code == 422

class TestServices:
    def test_get_services_empty(self, test_db):
        """Test getting services when database is empty"""
        response = client.get("/services")
        assert response.status_code == 200
        assert response.json() == []

    def test_create_service(self, test_db):
        """Test creating a new service"""
        service_data = {
            "name": "Test Hospital",
            "location": "123 Test St",
            "contact": "555-0123"
        }
        response = client.post("/services", json=service_data)
        assert response.status_code == 201
        data = response.json()
        assert data["name"] == service_data["name"]
        assert data["location"] == service_data["location"]
        assert data["contact"] == service_data["contact"]
        assert "id" in data

    def test_create_service_invalid_data(self, test_db):
        """Test creating service with invalid data"""
        response = client.post("/services", json={"name": ""})
        assert response.status_code == 422

    def test_get_service_by_id(self, test_db):
        """Test getting a specific service by ID"""
        # First create a service
        service_data = {
            "name": "Test Hospital",
            "location": "123 Test St",
            "contact": "555-0123"
        }
        create_response = client.post("/services", json=service_data)
        service_id = create_response.json()["id"]

        # Then get it by ID
        response = client.get(f"/services/{service_id}")
        assert response.status_code == 200
        data = response.json()
        assert data["name"] == service_data["name"]

    def test_get_nonexistent_service(self, test_db):
        """Test getting a service that doesn't exist"""
        response = client.get("/services/999")
        assert response.status_code == 404

    def test_update_service(self, test_db):
        """Test updating an existing service"""
        # First create a service
        service_data = {
            "name": "Test Hospital",
            "location": "123 Test St",
            "contact": "555-0123"
        }
        create_response = client.post("/services", json=service_data)
        service_id = create_response.json()["id"]

        # Then update it
        update_data = {"name": "Updated Hospital"}
        response = client.put(f"/services/{service_id}", json=update_data)
        assert response.status_code == 200
        data = response.json()
        assert data["name"] == "Updated Hospital"
        assert data["location"] == service_data["location"]  # Should remain unchanged

    def test_update_nonexistent_service(self, test_db):
        """Test updating a service that doesn't exist"""
        response = client.put("/services/999", json={"name": "Updated"})
        assert response.status_code == 404

    def test_delete_service(self, test_db):
        """Test deleting a service"""
        # First create a service
        service_data = {
            "name": "Test Hospital",
            "location": "123 Test St",
            "contact": "555-0123"
        }
        create_response = client.post("/services", json=service_data)
        service_id = create_response.json()["id"]

        # Then delete it
        response = client.delete(f"/services/{service_id}")
        assert response.status_code == 204

        # Verify it's deleted
        get_response = client.get(f"/services/{service_id}")
        assert get_response.status_code == 404

    def test_delete_nonexistent_service(self, test_db):
        """Test deleting a service that doesn't exist"""
        response = client.delete("/services/999")
        assert response.status_code == 404

    def test_get_services_pagination(self, test_db):
        """Test services pagination"""
        # Create multiple services
        for i in range(5):
            service_data = {
                "name": f"Hospital {i}",
                "location": f"{i} Test St",
                "contact": f"555-000{i}"
            }
            client.post("/services", json=service_data)

        # Test pagination
        response = client.get("/services?skip=2&limit=2")
        assert response.status_code == 200
        data = response.json()
        assert len(data) == 2

class TestValidation:
    def test_service_name_too_long(self, test_db):
        """Test service creation with name too long"""
        service_data = {
            "name": "x" * 101,  # Exceeds max length of 100
            "location": "123 Test St",
            "contact": "555-0123"
        }
        response = client.post("/services", json=service_data)
        assert response.status_code == 422

    def test_symptom_too_long(self):
        """Test triage with symptom too long"""
        response = client.post("/triage", json={"symptom": "x" * 501})  # Exceeds max length
        assert response.status_code == 422

class TestErrorHandling:
    def test_invalid_service_id_type(self, test_db):
        """Test with invalid service ID type"""
        response = client.get("/services/invalid")
        assert response.status_code == 422

    def test_malformed_json(self, test_db):
        """Test with malformed JSON"""
        response = client.post(
            "/services",
            content="invalid json",
            headers={"Content-Type": "application/json"}
        )
        assert response.status_code == 422

if __name__ == "__main__":
    pytest.main([__file__, "-v"])

class TestNearby:
    def test_nearby_no_services(self, test_db):
        """Nearby search returns empty when no services exist"""
        response = client.get("/services/nearby?lat=28.61&lon=77.20&radius_km=10")
        assert response.status_code == 200
        assert response.json() == []

    def test_nearby_with_services(self, test_db):
        """Nearby search returns services within radius, sorted by distance"""
        # Create services with coordinates
        s1 = {"name": "Clinic A", "location": "Loc A", "contact": "555-0001", "latitude": 28.6139, "longitude": 77.2090}
        s2 = {"name": "Clinic B", "location": "Loc B", "contact": "555-0002", "latitude": 28.5355, "longitude": 77.3910}
        s3 = {"name": "Clinic C", "location": "Loc C", "contact": "555-0003", "latitude": 28.7041, "longitude": 77.1025}
        for s in (s1, s2, s3):
            r = client.post("/services", json=s)
            assert r.status_code == 201

        # Query near a central point
        response = client.get("/services/nearby?lat=28.61&lon=77.20&radius_km=50&limit=5")
        assert response.status_code == 200
        data = response.json()
        # Should return at least the three we added
        names = [d["name"] for d in data]
        assert "Clinic A" in names and "Clinic B" in names and "Clinic C" in names

    def test_nearby_validation(self, test_db):
        """Nearby endpoint requires lat and lon and validates ranges"""
        r1 = client.get("/services/nearby?lat=100&lon=0")  # invalid latitude
        assert r1.status_code == 422
        r2 = client.get("/services/nearby?lon=77.20")  # missing lat
        assert r2.status_code == 422
        r3 = client.get("/services/nearby?lat=28.61")  # missing lon
        assert r3.status_code == 422
