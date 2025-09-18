import os
import logging
from typing import List, Dict, Any
import httpx

try:
    from openai import OpenAI
    try:
        from openai import AzureOpenAI  # Available in openai>=1.0
    except Exception:
        AzureOpenAI = None  # type: ignore
except Exception:  # pragma: no cover - optional dependency until configured
    OpenAI = None  # type: ignore

# Gemini (Google Generative AI)
try:
    import google.generativeai as genai
except Exception:
    genai = None  # type: ignore

logger = logging.getLogger(__name__)

class AIConfigError(Exception):
    pass

class AIClient:
    def __init__(self):
        self.provider = os.getenv("AI_PROVIDER", "openai").lower()
        self.model = os.getenv("AI_MODEL", "gpt-4o-mini")
        self.api_key = os.getenv("OPENAI_API_KEY")
        self.organization = os.getenv("OPENAI_ORG_ID")
        self.project = os.getenv("OPENAI_PROJECT_ID")
        # Azure
        self.azure_endpoint = os.getenv("AZURE_OPENAI_ENDPOINT")
        self.azure_api_version = os.getenv("AZURE_OPENAI_API_VERSION", "2024-05-01-preview")
        self.azure_deployment = os.getenv("AZURE_OPENAI_DEPLOYMENT")  # required for chat
        # OpenRouter
        self.or_api_key = os.getenv("OPENROUTER_API_KEY")
        self.or_base_url = os.getenv("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1")
        self.or_site_url = os.getenv("OPENROUTER_SITE_URL", "http://localhost")
        self.or_app_name = os.getenv("OPENROUTER_APP_NAME", "BMS Health Assistant")
        # Gemini (accept both GEMINI_API_KEY and gemini_API_KEY)
        self.gemini_api_key = os.getenv("GEMINI_API_KEY") or os.getenv("gemini_API_KEY")

        if self.provider == "openai":
            if not self.api_key or OpenAI is None:
                raise AIConfigError("OpenAI not configured. Set OPENAI_API_KEY and install 'openai' package.")
            # Pass optional org/project if provided (helps with sk-proj- keys)
            kwargs = {"api_key": self.api_key}
            if self.organization:
                kwargs["organization"] = self.organization
            if self.project:
                kwargs["project"] = self.project
            self.client = OpenAI(**kwargs)
        elif self.provider == "azure":
            if AzureOpenAI is None:
                raise AIConfigError("AzureOpenAI client not available. Upgrade 'openai' package to >=1.0.")
            if not (self.azure_endpoint and self.api_key and self.azure_deployment):
                raise AIConfigError("Azure OpenAI requires AZURE_OPENAI_ENDPOINT, OPENAI_API_KEY, and AZURE_OPENAI_DEPLOYMENT.")
            # AzureOpenAI uses 'api_version' and 'azure_endpoint'; API key is the same OPENAI_API_KEY env here
            self.client = AzureOpenAI(
                api_key=self.api_key,
                api_version=self.azure_api_version,
                azure_endpoint=self.azure_endpoint,
            )
        elif self.provider == "openrouter":
            if not (self.or_api_key):
                raise AIConfigError("OpenRouter not configured. Set OPENROUTER_API_KEY.")
            # We'll use httpx client; no SDK required
            self.client = None
        elif self.provider == "gemini":
            if genai is None or not self.gemini_api_key:
                raise AIConfigError("Gemini not configured. Install 'google-generativeai' and set GEMINI_API_KEY.")
            # Configure globally; model built on demand in chat()
            genai.configure(api_key=self.gemini_api_key)
            self.client = None
        else:
            raise AIConfigError(f"Unsupported AI_PROVIDER: {self.provider}")

    def chat(self, messages: List[Dict[str, str]], temperature: float = 0.2, max_tokens: int = 600) -> str:
        """Call the model with OpenAI Chat Completions, falling back to Responses API if needed."""
        if self.provider == "openai":
            # First try Chat Completions API
            try:
                resp = self.client.chat.completions.create(
                    model=self.model,
                    messages=messages,
                    temperature=temperature,
                    max_tokens=max_tokens,
                )
                return resp.choices[0].message.content or ""
            except Exception as e_chat:  # Try Responses API as fallback
                logger.warning(f"Chat Completions failed, trying Responses API: {e_chat}")
                try:
                    # Convert messages into a single input text
                    parts = []
                    for m in messages:
                        role = m.get("role", "user")
                        content = m.get("content", "")
                        parts.append(f"{role.upper()}: {content}")
                    input_text = "\n\n".join(parts)
                    resp = self.client.responses.create(
                        model=self.model,
                        input=input_text,
                        temperature=temperature,
                        max_output_tokens=max_tokens,
                    )
                    # Responses API returns content in different shape
                    # Get the first text item
                    for item in resp.output or []:
                        if item.type == "output_text":
                            return item.text
                    # Fallback to top-level text if present
                    if hasattr(resp, "output_text") and resp.output_text:
                        return resp.output_text
                    return ""
                except Exception as e_resp:
                    logger.error(f"OpenAI responses error: {e_resp}")
                    raise
        elif self.provider == "azure":
            # Azure uses deployment name in 'model' field
            try:
                resp = self.client.chat.completions.create(
                    model=self.azure_deployment,
                    messages=messages,
                    temperature=temperature,
                    max_tokens=max_tokens,
                )
                return resp.choices[0].message.content or ""
            except Exception as e:
                logger.error(f"Azure OpenAI chat error: {e}")
                raise
        elif self.provider == "openrouter":
            # OpenRouter offers OpenAI-compatible /chat/completions
            try:
                headers = {
                    "Authorization": f"Bearer {self.or_api_key}",
                    "Content-Type": "application/json",
                    "HTTP-Referer": self.or_site_url,
                    "X-Title": self.or_app_name,
                }
                payload = {
                    "model": self.model,
                    "messages": messages,
                    "temperature": temperature,
                    "max_tokens": max_tokens,
                }
                url = f"{self.or_base_url.rstrip('/')}/chat/completions"
                with httpx.Client(timeout=60) as client:
                    r = client.post(url, headers=headers, json=payload)
                    r.raise_for_status()
                    data = r.json()
                    # Same shape as OpenAI chat completions
                    return (data.get("choices", [{}])[0]
                                .get("message", {})
                                .get("content", ""))
            except Exception as e:
                logger.error(f"OpenRouter chat error: {e}")
                raise
        elif self.provider == "gemini":
            # Convert to Gemini message format and call generate_content
            try:
                # Build model with safety system prompt
                model_name = self.model or "gemini-1.5-flash"
                model = genai.GenerativeModel(model_name, system_instruction=SAFETY_SYSTEM_PROMPT)
                # Gemini expects history with roles: 'user' or 'model'
                # Map 'assistant' -> 'model'
                contents = []
                for m in messages:
                    role = m.get("role", "user")
                    if role == "assistant":
                        role = "model"
                    elif role not in ("user", "model"):
                        role = "user"
                    contents.append({"role": role, "parts": [m.get("content", "")]})
                resp = model.generate_content(contents)
                # Response may have candidates; take first text
                if hasattr(resp, "text") and resp.text:
                    return resp.text
                # Fallback to constructing text from parts
                try:
                    return "\n".join([p.text for p in getattr(resp, "candidates", [])[0].content.parts])
                except Exception:
                    return ""
            except Exception as e:
                logger.error(f"Gemini chat error: {e}")
                raise
        raise AIConfigError("AI client not properly configured")

SAFETY_SYSTEM_PROMPT = (
    "You are a compassionate, multilingual health assistant helping refugees and displaced people. "
    "Provide general information and self-care guidance only. Do not provide medical diagnosis. "
    "Always include an appropriate safety disclaimer and encourage seeking professional care when needed. "
    "If severe/emergency symptoms are present, clearly advise urgent care or local emergency services. "
    "Be sensitive to trauma and cultural contexts. Keep language simple and supportive."
)

TRIAGE_TEMPLATE = (
    "User symptom description: {symptom}\n"
    "Demographics: age={age}, sex={sex}, pregnant={pregnant}, chronic_conditions={chronic}\n"
    "Location (optional): {location}\n"
    "Task: 1) Classify severity as one of: EMERGENCY, URGENT, SELF-CARE.\n"
    "2) Provide brief guidance and next steps tailored to the user.\n"
    "3) If emergency, explicitly state to seek immediate care / call local emergency number.\n"
    "4) Respond in the target language: {language}."
)

CHAT_TEMPLATE = (
    "Context: You are a supportive health information assistant for refugees.\n"
    "Respond in: {language}.\n"
    "Conversation:"
)


aidefault_language = os.getenv("AI_DEFAULT_LANGUAGE", "English")

def build_ai_client() -> AIClient:
    return AIClient()


def get_triage_advice_payload(symptom: str, age: int | None, sex: str | None, pregnant: bool | None, chronic_conditions: List[str] | None, location: str | None, language: str | None) -> List[Dict[str, str]]:
    language = language or aidefault_language
    chronic = ", ".join(chronic_conditions or []) or "none"
    prompt = TRIAGE_TEMPLATE.format(
        symptom=symptom,
        age=age if age is not None else "unknown",
        sex=sex if sex else "unknown",
        pregnant=pregnant if pregnant is not None else "unknown",
        chronic=chronic,
        location=location or "unknown",
        language=language,
    )
    messages = [
        {"role": "system", "content": SAFETY_SYSTEM_PROMPT},
        {"role": "user", "content": prompt},
    ]
    return messages


def get_chat_payload(history: List[Dict[str, str]], language: str | None) -> List[Dict[str, str]]:
    language = language or aidefault_language
    messages: List[Dict[str, str]] = [
        {"role": "system", "content": SAFETY_SYSTEM_PROMPT},
        {"role": "system", "content": CHAT_TEMPLATE.format(language=language)},
    ]
    # Accept only 'user' or 'assistant' roles from history
    for m in history:
        role = m.get("role", "user")
        if role not in ("user", "assistant"):
            role = "user"
        content = m.get("content", "")
        messages.append({"role": role, "content": content})
    return messages


def safe_call(messages: List[Dict[str, str]]) -> str:
    try:
        client = build_ai_client()
        return client.chat(messages)
    except AIConfigError as e:
        logger.warning(f"AI not configured: {e}")
        return (
            "AI is not configured on this server. Please set OPENAI_API_KEY and AI_PROVIDER in the environment. "
            "In the meantime, use the rule-based /triage endpoint for basic guidance."
        )
    except Exception as e:  # pragma: no cover
        logger.error(f"AI call failed: {e}")
        return "Sorry, I couldn't process that request right now. Please try again later."
