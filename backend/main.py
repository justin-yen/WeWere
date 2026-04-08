from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from config import settings
from routers import auth, events, feed, photos, places, profiles, push, reactions

app = FastAPI(
    title="WeWere API",
    version="1.0.0",
    description="Backend API for the WeWere disposable film camera app",
)

# CORS -- allow all origins for development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(auth.router)
app.include_router(events.router)
app.include_router(photos.router)
app.include_router(profiles.router)
app.include_router(push.router)
app.include_router(places.router)
app.include_router(reactions.router)
app.include_router(feed.router)


@app.get("/", tags=["health"])
async def health_check():
    """Health check endpoint."""
    return {"status": "ok", "service": "WeWere API", "version": "1.0.0"}


@app.get("/.well-known/apple-app-site-association", tags=["universal-links"])
async def apple_app_site_association():
    """Return the Apple App Site Association file for universal links."""
    aasa = {
        "applinks": {
            "apps": [],
            "details": [
                {
                    "appID": f"{settings.APNS_TEAM_ID}.{settings.APP_BUNDLE_ID}",
                    "paths": ["/event/*"],
                }
            ],
        }
    }
    return JSONResponse(
        content=aasa,
        media_type="application/json",
    )


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
