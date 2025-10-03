"""
Pi-hole Security Suite API
FastAPI application for monitoring and managing the Pi-hole security stack
"""
from fastapi import FastAPI, HTTPException, Depends, Header
from typing import Optional
import subprocess
import json

app = FastAPI(
    title="Pi-hole Security Suite API",
    description="API for monitoring and managing Pi-hole + Unbound + NetAlertX",
    version="1.0.0"
API_KEY = os.getenv("SUITE_API_KEY", "")
def get_api_key(x_api_key: Optional[str] = Header(None)) -> str:
    """Validate API key from header"""
    if not API_KEY or x_api_key != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid or missing API key")
    return x_api_key
@app.get("/health")
def health():
    """Health check endpoint - no auth required"""
    return {"status": "ok", "api": "running", "version": "1.0.0"}
@app.get("/info")
def info(api_key: str = Depends(get_api_key)):
    """Get system information - requires API key"""
        # Check service statuses
        services = {}
        for service in ["unbound", "pihole-FTL", "pihole-suite"]:
            try:
                result = subprocess.run(
                    ["systemctl", "is-active", service],
                    capture_output=True, text=True, check=False
                )
                services[service] = result.stdout.strip()
            except Exception:
                services[service] = "unknown"
        
        # Check Docker containers
        containers = {}
            result = subprocess.run(
                ["docker", "ps", "--format", "json"],
                capture_output=True, text=True, check=False
            if result.returncode == 0:
                for line in result.stdout.strip().split('\n'):
                    if line:
                        container = json.loads(line)
                        containers[container.get('Names', 'unknown')] = container.get('State', 'unknown')
        except Exception:
            containers = {"error": "docker_unavailable"}
        
        return {
            "services": services,
            "containers": containers,
            "api_key_configured": bool(API_KEY)
        }
        raise HTTPException(status_code=500, detail=f"Error getting system info: {str(e)}")
    port = int(os.getenv("SUITE_PORT", "8090"))
    print(f"Starting Pi-hole Security Suite API on port {port}")
    print(f"API Key configured: {'Yes' if API_KEY else 'No'}")
    uvicorn.run(app, host="127.0.0.1", port=port)

