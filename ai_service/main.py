# ai_service/main.py
# Mantra AI Moderation + Matching Service — FastAPI

from fastapi import FastAPI, HTTPException, Depends, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List
import asyncio
import os
import json
import re
import httpx
import redis.asyncio as aioredis
from functools import lru_cache
import time

app = FastAPI(title="Mantra AI Service", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── Redis ────────────────────────────────────────────────

redis_client: aioredis.Redis = None

@app.on_event("startup")
async def startup():
    global redis_client
    redis_client = await aioredis.from_url(
        os.getenv("REDIS_URL", "redis://localhost:6379"),
        decode_responses=True,
    )

@app.on_event("shutdown")
async def shutdown():
    await redis_client.aclose()

# ─── Models ───────────────────────────────────────────────

class ModerationRequest(BaseModel):
    text: str
    user_id: str
    conversation_id: Optional[str] = None
    context_messages: Optional[List[str]] = []

class ModerationResult(BaseModel):
    toxicity_score: float
    decision: str  # 'pass', 'flag', 'block'
    categories: List[str]
    should_warn_user: bool
    increment_creep_score: bool

class CompatibilityRequest(BaseModel):
    user_a_id: str
    user_b_id: str
    user_a_tags: List[str]
    user_b_tags: List[str]
    user_a_city: str
    user_b_city: str
    user_a_intent: Optional[str] = None
    user_b_intent: Optional[str] = None

class ConversationStarterRequest(BaseModel):
    user_a_profile: dict
    user_b_profile: dict
    stage: int
    last_messages: Optional[List[str]] = []

class FakeProfileRequest(BaseModel):
    user_id: str
    photo_urls: List[str]
    profile_text: str
    account_age_days: int
    message_count: int
    report_count: int

# ─── Toxicity Detection ───────────────────────────────────

# Hardcoded bad patterns (fast regex scan, <2ms)
BAD_PATTERNS = [
    r'\b(nude|nudes|naked|sex|fuck|pussy|dick|cock|boobs|tits)\b',
    r'\b(send\s+pic|send\s+photo|watsapp|whatsapp\s+me|insta\s+me)\b',
    r'\b(come\s+home|meet\s+me\s+alone|hotel|room)\b',
    r'([\+\d\-\(\)\s]{10,})',  # Phone number pattern
    r'@[a-zA-Z0-9._]+',  # Instagram handle
]

HINGLISH_BAD = [
    'bhosdike', 'madarchod', 'bhenchod', 'chutiya', 'randi',
    'gaand', 'lund', 'chut', 'harami', 'saala',
]

def fast_regex_scan(text: str) -> tuple[bool, list]:
    """Fast pre-filter before ML model — <2ms"""
    text_lower = text.lower()
    categories = []

    for pattern in BAD_PATTERNS:
        if re.search(pattern, text_lower):
            categories.append('explicit_or_pii')

    for word in HINGLISH_BAD:
        if word in text_lower:
            categories.append('hinglish_slur')

    return len(categories) > 0, categories

async def get_openai_moderation(text: str) -> dict:
    """Use OpenAI moderation API as ML layer"""
    cache_key = f"mod:{hash(text[:100])}"
    cached = await redis_client.get(cache_key)
    if cached:
        return json.loads(cached)

    try:
        async with httpx.AsyncClient(timeout=3.0) as client:
            resp = await client.post(
                "https://api.openai.com/v1/moderations",
                headers={"Authorization": f"Bearer {os.getenv('OPENAI_API_KEY')}"},
                json={"input": text},
            )
            result = resp.json()
            categories = result["results"][0]["categories"]
            scores = result["results"][0]["category_scores"]

            flagged_cats = [k for k, v in categories.items() if v]
            max_score = max(scores.values()) if scores else 0.0

            output = {"flagged": result["results"][0]["flagged"], "score": max_score, "categories": flagged_cats}
            await redis_client.setex(cache_key, 300, json.dumps(output))
            return output
    except Exception:
        return {"flagged": False, "score": 0.0, "categories": []}

async def detect_escalation_pattern(
    user_id: str,
    conversation_id: str,
    current_score: float
) -> bool:
    """Detect message escalation across conversation history"""
    key = f"msg_scores:{conversation_id}:{user_id}"
    await redis_client.rpush(key, str(current_score))
    await redis_client.expire(key, 3600)
    await redis_client.ltrim(key, -10, -1)  # Keep last 10

    scores = await redis_client.lrange(key, 0, -1)
    if len(scores) < 3:
        return False

    float_scores = [float(s) for s in scores]
    # Escalation: avg of last 3 > avg of first 3 by threshold
    if len(float_scores) >= 6:
        early_avg = sum(float_scores[:3]) / 3
        recent_avg = sum(float_scores[-3:]) / 3
        return recent_avg > early_avg + 0.2

    return False

# ─── Endpoints ────────────────────────────────────────────

@app.get("/health")
async def health():
    return {"status": "ok", "timestamp": time.time()}

@app.post("/moderate/text", response_model=ModerationResult)
async def moderate_text(req: ModerationRequest, background_tasks: BackgroundTasks):
    """
    Pipeline:
    1. Fast regex scan (2ms)
    2. OpenAI moderation API (80ms)
    3. Escalation pattern check
    4. Decision
    """
    categories = []
    base_score = 0.0

    # Step 1: Fast regex
    regex_flagged, regex_cats = fast_regex_scan(req.text)
    if regex_flagged:
        categories.extend(regex_cats)
        base_score = max(base_score, 0.75)

    # Step 2: OpenAI moderation
    ml_result = await get_openai_moderation(req.text)
    if ml_result["flagged"]:
        categories.extend(ml_result["categories"])
        base_score = max(base_score, ml_result["score"])
    else:
        base_score = max(base_score, ml_result["score"] * 0.5)

    # Step 3: Escalation (async check if conversation_id provided)
    escalating = False
    if req.conversation_id and base_score > 0.2:
        escalating = await detect_escalation_pattern(
            req.user_id, req.conversation_id, base_score
        )
        if escalating:
            base_score = min(1.0, base_score + 0.15)
            categories.append('escalation_pattern')

    # Step 4: Decision
    categories = list(set(categories))

    if base_score >= 0.80 or regex_flagged:
        decision = 'block'
        should_warn = False
        increment_creep = True
    elif base_score >= 0.45 or escalating:
        decision = 'flag'
        should_warn = True
        increment_creep = True
    else:
        decision = 'pass'
        should_warn = False
        increment_creep = False

    # Background: update creep score in Node backend
    if increment_creep:
        background_tasks.add_task(
            notify_backend_creep_update, req.user_id, base_score
        )

    return ModerationResult(
        toxicity_score=round(base_score, 3),
        decision=decision,
        categories=categories,
        should_warn_user=should_warn,
        increment_creep_score=increment_creep,
    )

async def notify_backend_creep_update(user_id: str, score: float):
    try:
        await redis_client.lpush("creep_updates", json.dumps({
            "user_id": user_id,
            "score": score,
            "timestamp": time.time(),
        }))
    except Exception:
        pass

@app.post("/moderate/image")
async def moderate_image(image_url: str, user_id: str):
    """Image moderation via AWS Rekognition (called async from Node)"""
    import boto3
    try:
        rekognition = boto3.client(
            'rekognition',
            region_name='ap-south-1',
            aws_access_key_id=os.getenv('AWS_ACCESS_KEY_ID'),
            aws_secret_access_key=os.getenv('AWS_SECRET_ACCESS_KEY'),
        )

        response = rekognition.detect_moderation_labels(
            Image={'S3Object': {'Bucket': os.getenv('S3_BUCKET'), 'Name': image_url}},
            MinConfidence=60,
        )

        labels = response.get('ModerationLabels', [])
        is_explicit = any(l['Name'] in [
            'Explicit Nudity', 'Nudity', 'Graphic Sexual Activity',
            'Sexual Activity', 'Exposed Genitalia'
        ] for l in labels)

        return {
            "is_safe": not is_explicit,
            "labels": [l['Name'] for l in labels],
            "confidence": max((l['Confidence'] for l in labels), default=0),
        }
    except Exception as e:
        return {"is_safe": True, "labels": [], "error": str(e)}

@app.post("/match/compatibility")
async def get_compatibility(req: CompatibilityRequest):
    """Compute compatibility score between two users"""
    cache_key = f"compat:{min(req.user_a_id, req.user_b_id)}:{max(req.user_a_id, req.user_b_id)}"
    cached = await redis_client.get(cache_key)
    if cached:
        return json.loads(cached)

    # Tag overlap (Jaccard similarity)
    set_a = set(req.user_a_tags)
    set_b = set(req.user_b_tags)
    if set_a or set_b:
        jaccard = len(set_a & set_b) / len(set_a | set_b)
    else:
        jaccard = 0.0

    # City bonus
    city_bonus = 0.1 if req.user_a_city.lower() == req.user_b_city.lower() else 0.0

    # Intent alignment
    intent_bonus = 0.0
    if req.user_a_intent and req.user_b_intent:
        if req.user_a_intent == req.user_b_intent:
            intent_bonus = 0.05
        elif {req.user_a_intent, req.user_b_intent} == {'meaningful', 'partner'}:
            intent_bonus = 0.04

    total = (jaccard * 0.55) + city_bonus + intent_bonus
    score = min(int(total * 100) + 25, 99)

    result = {"compatibility_score": score, "breakdown": {
        "tag_overlap": round(jaccard, 3),
        "city_bonus": city_bonus,
        "intent_bonus": intent_bonus,
    }}

    await redis_client.setex(cache_key, 3600, json.dumps(result))
    return result

@app.post("/chat/starters")
async def get_conversation_starters(req: ConversationStarterRequest):
    """Generate contextual conversation starters using GPT-4o"""
    cache_key = f"starters:{req.user_a_profile.get('user_id', '')}:{req.user_b_profile.get('user_id', '')}:{req.stage}"
    cached = await redis_client.get(cache_key)
    if cached:
        return json.loads(cached)

    a_name = req.user_a_profile.get('display_name', 'them')
    b_interests = req.user_b_profile.get('personality_tags', [])
    b_prompts = req.user_b_profile.get('bio_prompt_responses', [])
    shared = set(req.user_a_profile.get('personality_tags', [])) & set(b_interests)

    system_prompt = """You are a warm, thoughtful conversation coach for an Indian dating app called Mantra.
Generate 3 short, genuine conversation starters. They should:
- Feel natural in Indian English/Hinglish
- Not be cheesy or pickup-line style
- Be based on actual shared interests or profile details
- Be 1-2 sentences max
- Feel like something a confident, genuine person would actually say
Return ONLY a JSON array of 3 strings. No other text."""

    user_prompt = f"""Stage: {req.stage}/5 conversation
Their interests: {', '.join(b_interests[:5])}
Shared interests: {', '.join(list(shared)[:3])}
Their prompt response: {b_prompts[0] if b_prompts else 'Not set'}
Last messages context: {' | '.join(req.last_messages[-3:]) if req.last_messages else 'First message'}"""

    try:
        async with httpx.AsyncClient(timeout=8.0) as client:
            resp = await client.post(
                "https://api.anthropic.com/v1/messages",
                headers={
                    "x-api-key": os.getenv("ANTHROPIC_API_KEY"),
                    "anthropic-version": "2023-06-01",
                    "content-type": "application/json",
                },
                json={
                    "model": "claude-haiku-4-5-20251001",
                    "max_tokens": 300,
                    "system": system_prompt,
                    "messages": [{"role": "user", "content": user_prompt}],
                },
            )
            content = resp.json()["content"][0]["text"].strip()
            starters = json.loads(content)
    except Exception:
        starters = [
            f"Your interest in {b_interests[0] if b_interests else 'that topic'} caught my eye — what got you into it?",
            "What's something you've been thinking about a lot lately?",
            "If you could have one conversation with anyone, living or not, who would it be?",
        ]

    result = {"starters": starters[:3]}
    await redis_client.setex(cache_key, 1800, json.dumps(result))
    return result

@app.post("/safety/fake-score")
async def compute_fake_score(req: FakeProfileRequest):
    """Multi-signal fake profile detection"""
    score = 0.0
    signals = []

    # Behavioral signals
    if req.account_age_days < 1 and req.message_count > 20:
        score += 0.35
        signals.append('spam_behavior_new_account')

    if req.report_count >= 3:
        score += 0.30
        signals.append('multiple_reports')

    if req.report_count >= 5:
        score += 0.20
        signals.append('high_report_count')

    # Profile text signals
    text_lower = req.profile_text.lower()
    if any(kw in text_lower for kw in ['whatsapp me', 'instagram me', 'telegram', 'snapchat']):
        score += 0.25
        signals.append('off_platform_redirect')

    if len(req.profile_text) < 20 and len(req.photo_urls) == 0:
        score += 0.15
        signals.append('empty_profile')

    # Clamp
    score = min(score, 1.0)

    decision = 'ban' if score >= 0.80 else 'restrict' if score >= 0.55 else 'monitor' if score >= 0.30 else 'ok'

    return {
        "fake_score": round(score, 3),
        "decision": decision,
        "signals": signals,
    }
