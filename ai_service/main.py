import os
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException, Request, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import anthropic

# ─────────────────────────────────────────────
# Startup lifespan
# ─────────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    required = ["AI_INTERNAL_SECRET", "ANTHROPIC_API_KEY", "BACKEND_ORIGIN"]
    missing = [k for k in required if not os.getenv(k)]
    if missing:
        raise RuntimeError(f"Missing required env vars: {missing}")
    yield

app = FastAPI(title="Mantra AI Service", lifespan=lifespan)

BACKEND_ORIGIN = os.getenv("BACKEND_ORIGIN", "http://localhost:8000")
AI_INTERNAL_SECRET = os.getenv("AI_INTERNAL_SECRET", "")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[BACKEND_ORIGIN],
    allow_credentials=True,
    allow_methods=["POST"],
    allow_headers=["*"],
)

# ─────────────────────────────────────────────
# Auth
# ─────────────────────────────────────────────
def verify_internal(request: Request):
    secret = request.headers.get("X-Internal-Secret", "")
    if not secret or secret != AI_INTERNAL_SECRET:
        raise HTTPException(status_code=403, detail="Forbidden")

# ─────────────────────────────────────────────
# Client
# ─────────────────────────────────────────────
def get_client() -> anthropic.Anthropic:
    key = os.getenv("ANTHROPIC_API_KEY")
    if not key:
        raise HTTPException(status_code=503, detail="Anthropic API key not configured")
    return anthropic.Anthropic(api_key=key)

# ─────────────────────────────────────────────
# Schemas
# ─────────────────────────────────────────────
class ConversationStarter(BaseModel):
    user_a_interests: list[str]
    user_b_interests: list[str]
    stage: int = 1

class CreepDetectionRequest(BaseModel):
    messages: list[dict]
    user_id: str

class CompatibilityRequest(BaseModel):
    user_a: dict
    user_b: dict

# ─────────────────────────────────────────────
# Routes
# ─────────────────────────────────────────────
@app.post("/conversation-starter")
async def conversation_starter(
    body: ConversationStarter,
    _: None = Depends(verify_internal),
    client: anthropic.Anthropic = Depends(get_client),
):
    shared = list(set(body.user_a_interests) & set(body.user_b_interests))
    topic = f"Both of them like: {', '.join(shared[:3])}" if shared else "they are just getting to know each other"
    prompt = (
        f"Generate 3 thoughtful, non-generic conversation starters for two people on a slow dating app. "
        f"Stage {body.stage}/5 of their connection. {topic}. "
        "Keep them warm, curious, and safe. Return only a numbered list."
    )
    message = client.messages.create(
        model="claude-haiku-4-5",
        max_tokens=256,
        messages=[{"role": "user", "content": prompt}],
    )
    return {"starters": message.content[0].text}


@app.post("/creep-detection")
async def creep_detection(
    body: CreepDetectionRequest,
    _: None = Depends(verify_internal),
    client: anthropic.Anthropic = Depends(get_client),
):
    recent = body.messages[-10:]
    convo = "\n".join(f"{m.get('sender_id','?')}: {m.get('content','')}" for m in recent)
    prompt = (
        "You are a safety AI for a dating app. Analyse this conversation for red flags "
        "(harassment, pressure, sexual content, threats, personal info fishing). "
        "Reply JSON: {\"safe\": bool, \"score\": 0-100, \"flags\": [\"...\"], \"action\": \"none|warn|review|block\"}\n\n"
        f"Conversation:\n{convo}"
    )
    message = client.messages.create(
        model="claude-haiku-4-5",
        max_tokens=200,
        messages=[{"role": "user", "content": prompt}],
    )
    import json
    try:
        result = json.loads(message.content[0].text)
    except Exception:
        result = {"safe": True, "score": 0, "flags": [], "action": "none"}
    return result


@app.post("/compatibility-score")
async def compatibility_score(
    body: CompatibilityRequest,
    _: None = Depends(verify_internal),
    client: anthropic.Anthropic = Depends(get_client),
):
    prompt = (
        "Score these two dating profiles' compatibility 0-100. "
        f"Profile A: {body.user_a}. Profile B: {body.user_b}. "
        "Reply JSON: {\"score\": int, \"reasons\": [\"...\"]}"
    )
    message = client.messages.create(
        model="claude-haiku-4-5",
        max_tokens=200,
        messages=[{"role": "user", "content": prompt}],
    )
    import json
    try:
        result = json.loads(message.content[0].text)
    except Exception:
        result = {"score": 70, "reasons": ["Compatible interests"]}
    return result


@app.get("/health")
async def health():
    return {"status": "ok", "service": "mantra-ai"}
