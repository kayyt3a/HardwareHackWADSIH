"""
Per-user profile storage: dosage-relevant facts (age, weight, conditions,
allergies) and a voice-built reminders list ("remember this", "what do I
have coming up"). Flat JSON file for hackathon simplicity — swap for a real
DB if this needs to survive across devices/demos reliably.

Deliberately NOT a medical record: this store only ever holds what the user
themselves typed in or asked the device to remember. No inference, no
diagnosis, nothing derived server-side.
"""
import json
import os
import threading
from datetime import datetime, timezone
from typing import Optional

_STORE_PATH = os.environ.get("PROFILE_STORE_PATH", "profiles.json")
_lock = threading.Lock()


def _load_all() -> dict:
    if not os.path.exists(_STORE_PATH):
        return {}
    with open(_STORE_PATH, "r") as f:
        return json.load(f)


def _save_all(data: dict) -> None:
    tmp_path = _STORE_PATH + ".tmp"
    with open(tmp_path, "w") as f:
        json.dump(data, f, indent=2)
    os.replace(tmp_path, _STORE_PATH)


def get_profile(user_id: str) -> dict:
    with _lock:
        all_profiles = _load_all()
    return all_profiles.get(user_id, {
        "user_id": user_id,
        "profile_type": None,  # "dosage" or "reminders", set at setup time
        "age": None,
        "weight_kg": None,
        "conditions": [],
        "allergies": [],
        "reminders": [],
    })


def set_profile_fields(user_id: str, **fields) -> dict:
    with _lock:
        all_profiles = _load_all()
        profile = all_profiles.get(user_id, get_profile(user_id))
        profile.update({k: v for k, v in fields.items() if v is not None})
        profile["user_id"] = user_id
        all_profiles[user_id] = profile
        _save_all(all_profiles)
    return profile


def add_reminder(user_id: str, text: str) -> dict:
    with _lock:
        all_profiles = _load_all()
        profile = all_profiles.get(user_id, get_profile(user_id))
        profile.setdefault("reminders", []).append({
            "text": text,
            "added_at": datetime.now(timezone.utc).isoformat(),
        })
        profile["user_id"] = user_id
        all_profiles[user_id] = profile
        _save_all(all_profiles)
    return profile


def list_reminders(user_id: str) -> list:
    return get_profile(user_id).get("reminders", [])


def dosage_context_summary(user_id: str) -> Optional[str]:
    """A short plain-text summary handed to the vision model as context —
    facts only, never a recommendation. Returns None if no dosage-relevant
    fields are set, so the prompt doesn't mention a profile that doesn't
    exist."""
    profile = get_profile(user_id)
    if profile.get("profile_type") != "dosage":
        return None
    parts = []
    if profile.get("age"):
        parts.append(f"age {profile['age']}")
    if profile.get("weight_kg"):
        parts.append(f"weight {profile['weight_kg']}kg")
    if profile.get("conditions"):
        parts.append(f"known conditions: {', '.join(profile['conditions'])}")
    if profile.get("allergies"):
        parts.append(f"known allergies: {', '.join(profile['allergies'])}")
    return "; ".join(parts) if parts else None
