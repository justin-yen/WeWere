from __future__ import annotations

from datetime import datetime
from typing import Any, Optional
from uuid import UUID

from pydantic import BaseModel, Field


# ---------- Auth ----------

class SendOTPRequest(BaseModel):
    phone_number: str = Field(..., description="E.164 formatted phone number")


class VerifyOTPRequest(BaseModel):
    phone_number: str
    code: str = Field(..., min_length=4, max_length=8)


class UserProfile(BaseModel):
    id: UUID
    first_name: str
    last_name: str
    instagram_handle: Optional[str] = None
    phone_number: Optional[str] = None
    avatar_url: Optional[str] = None
    created_at: Optional[datetime] = None


class VerifyOTPResponse(BaseModel):
    access_token: str
    refresh_token: str
    user: Optional[UserProfile] = None
    needs_profile: bool


# ---------- Profiles ----------

class CreateProfileRequest(BaseModel):
    first_name: str = Field(..., min_length=1, max_length=100)
    last_name: str = Field(..., min_length=1, max_length=100)
    instagram_handle: Optional[str] = None
    phone_number: str


class UpdateProfileRequest(BaseModel):
    first_name: Optional[str] = Field(None, min_length=1, max_length=100)
    last_name: Optional[str] = Field(None, min_length=1, max_length=100)
    instagram_handle: Optional[str] = None


class ProfileResponse(BaseModel):
    id: UUID
    first_name: str
    last_name: str
    instagram_handle: Optional[str] = None
    phone_number: Optional[str] = None
    avatar_url: Optional[str] = None
    created_at: Optional[datetime] = None


# ---------- Events ----------

class CreateEventRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=200)
    description: Optional[str] = None
    location: Optional[str] = None
    location_name: Optional[str] = None
    location_address: Optional[str] = None
    location_lat: Optional[float] = None
    location_lng: Optional[float] = None
    start_time: datetime
    end_time: Optional[datetime] = None
    cover_photo_url: Optional[str] = None
    cover_photo_attribution: Optional[str] = None


class EventResponse(BaseModel):
    id: UUID
    name: str
    description: Optional[str] = None
    location: Optional[str] = None
    location_name: Optional[str] = None
    location_address: Optional[str] = None
    location_lat: Optional[float] = None
    location_lng: Optional[float] = None
    start_time: datetime
    end_time: Optional[datetime] = None
    share_code: Optional[str] = None
    host_id: UUID
    status: str = "live"
    created_at: Optional[datetime] = None
    photo_count: Optional[int] = None
    member_count: Optional[int] = None
    membership: Optional[dict[str, Any]] = None
    cover_photo_url: Optional[str] = None
    cover_photo_attribution: Optional[str] = None


class EventDetailResponse(EventResponse):
    members: list[dict[str, Any]] = []
    has_developed: bool = False


class MemberResponse(BaseModel):
    id: UUID
    user_id: UUID
    event_id: UUID
    role: str
    has_developed: bool = False
    joined_at: Optional[datetime] = None
    user: Optional[ProfileResponse] = None


# ---------- Photos ----------

class PhotoResponse(BaseModel):
    id: UUID
    event_id: UUID
    user_id: UUID
    storage_path: str
    signed_url: Optional[str] = None
    created_at: Optional[datetime] = None
    user: Optional[ProfileResponse] = None


class PhotoCountResponse(BaseModel):
    count: int


class PeakTimeResponse(BaseModel):
    peak_start: Optional[datetime] = None
    peak_end: Optional[datetime] = None
    photo_count: int = 0


# ---------- Reactions ----------


class AddReactionRequest(BaseModel):
    emoji: str = Field(..., description="Reaction emoji key (heart, fire, sparkles, film, moon)")


class ReactionResponse(BaseModel):
    id: UUID
    photo_id: UUID
    user_id: UUID
    emoji: str
    created_at: Optional[datetime] = None
    user: Optional[ProfileResponse] = None


class MyReactionsResponse(BaseModel):
    emojis: list[str]


# ---------- Push ----------

class RegisterPushTokenRequest(BaseModel):
    token: str


class SendPushRequest(BaseModel):
    event_id: UUID
    type: str
    message: str


# ---------- Comments ----------


class AddCommentRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=500)


class CommentResponse(BaseModel):
    id: UUID
    photo_id: UUID
    user_id: UUID
    text: str
    created_at: Optional[datetime] = None
    user: Optional[ProfileResponse] = None


# ---------- Common ----------

class ErrorResponse(BaseModel):
    detail: str


class SuccessResponse(BaseModel):
    success: bool = True
