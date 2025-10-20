"""
SRE Showcase API - FastAPI Application
Demonstrates observability, health checks, and metrics exposure
"""

from fastapi import FastAPI, Response, HTTPException, Request
from fastapi.responses import JSONResponse
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
from contextlib import asynccontextmanager
import time
import random
import logging
import sys
from datetime import datetime
from typing import Dict, Any

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger(__name__)

# Application state
app_state = {
    "start_time": datetime.utcnow(),
    "request_count": 0,
    "healthy": True,
    "ready": True
}


# Lifespan event handler
@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Lifespan event handler for startup and shutdown
    BROKEN VERSION - Crashes on startup
    """
    # Startup - INTENTIONALLY BROKEN
    logger.info("=" * 50)
    logger.info("SRE Showcase API Starting")
    logger.info("=" * 50)
    logger.error("SIMULATED FAILURE: Database connection failed!")
    logger.error("Unable to connect to database at db.example.com:5432")
    raise Exception("Database connection failed - connection refused")
    
    yield
    
    # Shutdown (never reached due to crash)
    logger.info("Shutting down...")


# Initialize FastAPI app with lifespan
app = FastAPI(
    title="SRE Showcase API",
    description="Production-ready API demonstrating SRE best practices",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan
)

# Prometheus metrics
REQUEST_COUNT = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

REQUEST_LATENCY = Histogram(
    'http_request_duration_seconds',
    'HTTP request latency in seconds',
    ['method', 'endpoint']
)

REQUEST_IN_PROGRESS = Gauge(
    'http_requests_in_progress',
    'Number of HTTP requests in progress',
    ['method', 'endpoint']
)

ERROR_COUNT = Counter(
    'http_errors_total',
    'Total HTTP errors',
    ['method', 'endpoint', 'error_type']
)

APP_INFO = Gauge(
    'app_info',
    'Application information',
    ['version', 'environment']
)

# Set app info
APP_INFO.labels(version='1.0.0', environment='demo').set(1)


# Middleware for metrics
@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    """Middleware to track request metrics"""
    
    method = request.method
    endpoint = request.url.path
    
    # Track in-progress requests
    REQUEST_IN_PROGRESS.labels(method=method, endpoint=endpoint).inc()
    
    # Track latency
    start_time = time.time()
    
    try:
        response = await call_next(request)
        status = response.status_code
        
        # Record metrics
        REQUEST_COUNT.labels(method=method, endpoint=endpoint, status=status).inc()
        
        duration = time.time() - start_time
        REQUEST_LATENCY.labels(method=method, endpoint=endpoint).observe(duration)
        
        # Log request
        logger.info(
            f"{method} {endpoint} - Status: {status} - Duration: {duration:.3f}s"
        )
        
        return response
        
    except Exception as e:
        # Track errors
        ERROR_COUNT.labels(
            method=method,
            endpoint=endpoint,
            error_type=type(e).__name__
        ).inc()
        
        logger.error(f"Error processing request: {str(e)}")
        raise
        
    finally:
        # Decrement in-progress counter
        REQUEST_IN_PROGRESS.labels(method=method, endpoint=endpoint).dec()
        app_state["request_count"] += 1


# Root endpoint
@app.get("/", tags=["General"])
async def root() -> Dict[str, Any]:
    """Root endpoint with API information"""
    uptime = (datetime.utcnow() - app_state["start_time"]).total_seconds()
    
    return {
        "message": "SRE Showcase API",
        "version": "1.0.0",
        "status": "operational",
        "uptime_seconds": round(uptime, 2),
        "total_requests": app_state["request_count"],
        "endpoints": {
            "health": "/health",
            "ready": "/ready",
            "metrics": "/metrics",
            "docs": "/docs",
            "api": "/api/*"
        }
    }


# Health check endpoint
@app.get("/health", tags=["Health"])
async def health() -> Dict[str, Any]:
    """
    Health check endpoint for liveness probe
    Returns 200 if application is alive, 503 if unhealthy
    """
    if not app_state["healthy"]:
        logger.warning("Health check failed - application unhealthy")
        raise HTTPException(status_code=503, detail="Application unhealthy")
    
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "uptime_seconds": (datetime.utcnow() - app_state["start_time"]).total_seconds()
    }


# Readiness check endpoint
@app.get("/ready", tags=["Health"])
async def ready() -> Dict[str, Any]:
    """
    Readiness check endpoint for readiness probe
    Returns 200 if application is ready to serve traffic
    """
    if not app_state["ready"]:
        logger.warning("Readiness check failed - application not ready")
        raise HTTPException(status_code=503, detail="Application not ready")
    
    # Check dependencies (simulated)
    dependencies = {
        "database": "connected",  # Simulated
        "cache": "connected",     # Simulated
    }
    
    return {
        "status": "ready",
        "timestamp": datetime.utcnow().isoformat(),
        "dependencies": dependencies
    }


# Metrics endpoint for Prometheus
@app.get("/metrics", tags=["Monitoring"])
async def metrics():
    """Prometheus metrics endpoint"""
    return Response(
        content=generate_latest(),
        media_type=CONTENT_TYPE_LATEST
    )


# API endpoints
@app.get("/api/data", tags=["API"])
async def get_data() -> Dict[str, Any]:
    """
    Sample API endpoint that returns data
    Simulates processing time
    """
    # Simulate processing
    processing_time = random.uniform(0.01, 0.1)
    time.sleep(processing_time)
    
    return {
        "data": [
            {"id": 1, "name": "Item 1", "value": random.randint(1, 100)},
            {"id": 2, "name": "Item 2", "value": random.randint(1, 100)},
            {"id": 3, "name": "Item 3", "value": random.randint(1, 100)},
        ],
        "processed": True,
        "processing_time_ms": round(processing_time * 1000, 2),
        "timestamp": datetime.utcnow().isoformat()
    }


@app.get("/api/status", tags=["API"])
async def get_status() -> Dict[str, Any]:
    """Get application status and statistics"""
    uptime = (datetime.utcnow() - app_state["start_time"]).total_seconds()
    
    return {
        "status": "operational",
        "version": "1.0.0",
        "uptime_seconds": round(uptime, 2),
        "uptime_human": format_uptime(uptime),
        "total_requests": app_state["request_count"],
        "healthy": app_state["healthy"],
        "ready": app_state["ready"],
        "timestamp": datetime.utcnow().isoformat()
    }


@app.get("/api/slow", tags=["API"])
async def slow_endpoint() -> Dict[str, Any]:
    """
    Intentionally slow endpoint for testing
    Useful for latency testing and alerting
    """
    delay = random.uniform(0.5, 2.0)
    time.sleep(delay)
    
    return {
        "message": "This endpoint is intentionally slow",
        "delay_seconds": round(delay, 2),
        "timestamp": datetime.utcnow().isoformat()
    }


@app.get("/api/flaky", tags=["API"])
async def flaky_endpoint() -> Dict[str, Any]:
    """
    Flaky endpoint that randomly fails
    Useful for error rate testing and alerting
    """
    # 10% chance of failure
    if random.random() < 0.1:
        logger.error("Flaky endpoint triggered failure")
        ERROR_COUNT.labels(
            method="GET",
            endpoint="/api/flaky",
            error_type="SimulatedError"
        ).inc()
        raise HTTPException(
            status_code=500,
            detail="Simulated random failure"
        )
    
    return {
        "status": "success",
        "message": "Request succeeded",
        "timestamp": datetime.utcnow().isoformat()
    }


# Admin endpoints (for incident simulation)
@app.post("/admin/break", tags=["Admin"])
async def break_app() -> Dict[str, str]:
    """
    Break the application (for incident simulation)
    Sets health check to fail
    """
    logger.warning("Application manually set to unhealthy state")
    app_state["healthy"] = False
    app_state["ready"] = False
    
    return {
        "message": "Application set to unhealthy state",
        "status": "broken"
    }


@app.post("/admin/fix", tags=["Admin"])
async def fix_app() -> Dict[str, str]:
    """
    Fix the application (restore from incident)
    Sets health check to pass
    """
    logger.info("Application manually restored to healthy state")
    app_state["healthy"] = True
    app_state["ready"] = True
    
    return {
        "message": "Application restored to healthy state",
        "status": "fixed"
    }


# Utility functions
def format_uptime(seconds: float) -> str:
    """Format uptime in human-readable format"""
    days = int(seconds // 86400)
    hours = int((seconds % 86400) // 3600)
    minutes = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    
    parts = []
    if days > 0:
        parts.append(f"{days}d")
    if hours > 0:
        parts.append(f"{hours}h")
    if minutes > 0:
        parts.append(f"{minutes}m")
    parts.append(f"{secs}s")
    
    return " ".join(parts)


# Exception handlers
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Global exception handler"""
    logger.error(f"Unhandled exception: {str(exc)}", exc_info=True)
    
    ERROR_COUNT.labels(
        method=request.method,
        endpoint=request.url.path,
        error_type=type(exc).__name__
    ).inc()
    
    return JSONResponse(
        status_code=500,
        content={
            "error": "Internal server error",
            "message": str(exc),
            "timestamp": datetime.utcnow().isoformat()
        }
    )


if __name__ == "__main__":
    import uvicorn
    
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        log_level="info",
        access_log=True
    )
