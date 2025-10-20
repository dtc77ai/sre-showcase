"""
Unit tests for SRE Showcase API
"""

import pytest
import sys
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from fastapi.testclient import TestClient
from main import app, app_state

client = TestClient(app)


class TestHealthEndpoints:
    """Test health check endpoints"""
    
    def test_health_check_healthy(self):
        """Test health endpoint when app is healthy"""
        app_state["healthy"] = True
        response = client.get("/health")
        
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert "timestamp" in data
        assert "uptime_seconds" in data
    
    def test_health_check_unhealthy(self):
        """Test health endpoint when app is unhealthy"""
        app_state["healthy"] = False
        response = client.get("/health")
        
        assert response.status_code == 503
        
        # Restore state
        app_state["healthy"] = True
    
    def test_readiness_check_ready(self):
        """Test readiness endpoint when app is ready"""
        app_state["ready"] = True
        response = client.get("/ready")
        
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "ready"
        assert "dependencies" in data
    
    def test_readiness_check_not_ready(self):
        """Test readiness endpoint when app is not ready"""
        app_state["ready"] = False
        response = client.get("/ready")
        
        assert response.status_code == 503
        
        # Restore state
        app_state["ready"] = True


class TestAPIEndpoints:
    """Test API endpoints"""
    
    def test_root_endpoint(self):
        """Test root endpoint"""
        response = client.get("/")
        
        assert response.status_code == 200
        data = response.json()
        assert data["message"] == "SRE Showcase API"
        assert data["version"] == "1.0.0"
        assert data["status"] == "operational"
        assert "endpoints" in data
    
    def test_get_data_endpoint(self):
        """Test /api/data endpoint"""
        response = client.get("/api/data")
        
        assert response.status_code == 200
        data = response.json()
        assert "data" in data
        assert data["processed"] is True
        assert "processing_time_ms" in data
        assert len(data["data"]) == 3
    
    def test_get_status_endpoint(self):
        """Test /api/status endpoint"""
        response = client.get("/api/status")
        
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "operational"
        assert data["version"] == "1.0.0"
        assert "uptime_seconds" in data
        assert "total_requests" in data
    
    def test_slow_endpoint(self):
        """Test /api/slow endpoint"""
        response = client.get("/api/slow")
        
        assert response.status_code == 200
        data = response.json()
        assert "delay_seconds" in data
        assert data["delay_seconds"] >= 0.5
    
    def test_flaky_endpoint_success(self):
        """Test /api/flaky endpoint (may succeed or fail)"""
        # Run multiple times to test both scenarios
        success_count = 0
        failure_count = 0
        
        for _ in range(20):
            response = client.get("/api/flaky")
            if response.status_code == 200:
                success_count += 1
            elif response.status_code == 500:
                failure_count += 1
        
        # Should have mostly successes (90% success rate)
        assert success_count > 0


class TestMetricsEndpoint:
    """Test metrics endpoint"""
    
    def test_metrics_endpoint(self):
        """Test Prometheus metrics endpoint"""
        response = client.get("/metrics")
        
        assert response.status_code == 200
        assert "text/plain" in response.headers["content-type"]
        
        # Check for expected metrics
        content = response.text
        assert "http_requests_total" in content
        assert "http_request_duration_seconds" in content
        assert "app_info" in content


class TestAdminEndpoints:
    """Test admin endpoints"""
    
    def test_break_and_fix_app(self):
        """Test breaking and fixing the application"""
        # Break the app
        response = client.post("/admin/break")
        assert response.status_code == 200
        assert app_state["healthy"] is False
        
        # Verify health check fails
        health_response = client.get("/health")
        assert health_response.status_code == 503
        
        # Fix the app
        response = client.post("/admin/fix")
        assert response.status_code == 200
        assert app_state["healthy"] is True
        
        # Verify health check passes
        health_response = client.get("/health")
        assert health_response.status_code == 200


class TestMiddleware:
    """Test middleware functionality"""
    
    def test_request_counting(self):
        """Test that requests are counted"""
        initial_count = app_state["request_count"]
        
        client.get("/")
        client.get("/api/data")
        
        assert app_state["request_count"] > initial_count


class TestLifespan:
    """Test lifespan events"""
    
    def test_app_state_initialized(self):
        """Test that app state is properly initialized"""
        assert "start_time" in app_state
        assert "request_count" in app_state
        assert "healthy" in app_state
        assert "ready" in app_state
        assert app_state["healthy"] is True
        assert app_state["ready"] is True


# Run tests
if __name__ == "__main__":
    pytest.main([__file__, "-v"])
