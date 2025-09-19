# Business Management System (BMS) API

A FastAPI-based backend that provides:

- Triage classification endpoint for quick self-assessment.
- CRUD APIs to manage health service providers with optional geolocation.
- AI-powered endpoints for triage advice and chat via pluggable providers (OpenAI, Azure OpenAI, OpenRouter, Gemini).

The project uses SQLite by default and can be configured to use Postgres/MySQL in production.


## Features

- Triage classification with simple, safe rules (`/triage`).
- Service directory with CRUD, text search, and nearby search (`/services`, `/services/search`, `/services/nearby`).
- AI endpoints for richer triage advice and chat (`/ai/triage-advice`, `/ai/chat`).
- CORS enabled for easy local development.
- Seed data auto-initialized on startup.


## Tech Stack

- Python, FastAPI, Uvicorn
- SQLAlchemy (SQLite by default)
- Pydantic v2
- Optional AI SDKs (OpenAI, Google Generative AI/Gemini)


## Project Structure

```
bms/
├─ main.py                 # FastAPI app and routes
├─ models.py               # SQLAlchemy models
├─ schemas.py              # Pydantic models
├─ crud.py                 # Database access helpers
├─ database.py             # Engine/session config
├─ ai.py                   # Pluggable AI client and helpers
├─ ai_sanity_check.py      # Local script to exercise AI endpoints
├─ verify_openai.py        # Sanity check for OpenAI credentials
├─ requirements.txt        # Python dependencies
├─ BMS_API.postman_collection.json
├─ BMS_AI.postman_collection.json
├─ BMS_Local.postman_environment.json
├─ test_main.py            # API tests using TestClient/pytest
└─ README.md
```


## Getting Started

### Prerequisites

- Python 3.11+
- pip

### Install

```bash
python -m venv .venv
.venv\Scripts\activate  # Windows
pip install -r requirements.txt
```

### Environment Configuration

Create a `.env` file in the project root (optional but recommended). Common variables:

- DATABASE_URL: Database connection string
  - Default: `sqlite:///./services.db`
- SQL_ECHO: Set `true` to log SQL statements (default: `false`)

AI configuration (choose one provider):

- AI_PROVIDER: `openai` | `azure` | `openrouter` | `gemini` (default: `openai`)
- AI_MODEL: Model name used by the selected provider (default: `gpt-4o-mini`)

OpenAI:

- OPENAI_API_KEY: Your OpenAI API key
- OPENAI_ORG_ID: Optional
- OPENAI_PROJECT_ID: Optional (useful for `sk-proj-...` keys)

Azure OpenAI:

- AZURE_OPENAI_ENDPOINT
- AZURE_OPENAI_API_VERSION: Default `2024-05-01-preview`
- AZURE_OPENAI_DEPLOYMENT: Your deployment name
- OPENAI_API_KEY: Azure OpenAI key (same variable name used by SDK)

OpenRouter:

- OPENROUTER_API_KEY
- OPENROUTER_BASE_URL: Default `https://openrouter.ai/api/v1`
- OPENROUTER_SITE_URL: Default `http://localhost`
- OPENROUTER_APP_NAME: Default `BMS Health Assistant`

Gemini (Google Generative AI):

- GEMINI_API_KEY (or `gemini_API_KEY`)

Optional for local scripts:

- BASE_URL: Used by `ai_sanity_check.py` (default: `http://127.0.0.1:8002`)

Example `.env`:

```env
DATABASE_URL=sqlite:///./services.db
SQL_ECHO=false
AI_PROVIDER=openai
AI_MODEL=gpt-4o-mini
OPENAI_API_KEY=sk-...
```


## Run the Server

From the project root:

```bash
uvicorn main:app --reload --port 8000
```

Open the interactive docs:

- Swagger UI: http://127.0.0.1:8000/docs
- ReDoc: http://127.0.0.1:8000/redoc

Note: The bundled Postman environment (`BMS_Local.postman_environment.json`) points to port `8002`. You can either:

- Run Uvicorn with `--port 8002`, or
- Change `baseUrl` in the Postman environment to `http://127.0.0.1:8000`.


## Database

- Default is SQLite at `./services.db`.
- On startup, `main.py` seeds example services if the table is empty and ensures `latitude`/`longitude` columns exist.
- For Postgres/MySQL, set `DATABASE_URL` accordingly (e.g., `postgresql+psycopg2://user:pass@host/db`).


## API Overview

Base URL: `http://127.0.0.1:8000` (or as configured)

- Health
  - GET `/health` → simple health check

- Triage (rule-based)
  - POST `/triage` body `{ "symptom": "..." }` → returns `{ status, recommendation }`

- Services
  - GET `/services?skip=0&limit=100` → list services
  - POST `/services` → create service
  - GET `/services/{id}` → fetch by id
  - PUT `/services/{id}` → partial update
  - DELETE `/services/{id}` → delete
  - GET `/services/search?q=text&limit=20` → search by name/location/contact
  - GET `/services/nearby?lat=..&lon=..&radius_km=10&limit=20` → nearby list by haversine distance

- AI
  - POST `/ai/triage-advice` body per `schemas.AITriageAdviceRequest` → `{ advice }`
  - POST `/ai/chat` body per `schemas.AIChatRequest` → `{ reply }`

See the Postman collections for ready-made requests.


## Postman Collections

Import these into Postman:

- `BMS_API.postman_collection.json` — endpoints for health/triage/services
- `BMS_AI.postman_collection.json` — endpoints for AI chat/triage advice
- `BMS_Local.postman_environment.json` — local environment with `baseUrl`

Adjust `baseUrl` to match your running port.


## AI Configuration and Sanity Checks

- Verify OpenAI credentials quickly:

  ```bash
  python verify_openai.py
  ```

- Exercise AI endpoints end-to-end (make sure the server is running):

  ```bash
  # BASE_URL can be set in .env or as an environment variable
  python ai_sanity_check.py
  ```

If you change providers, set `AI_PROVIDER` and relevant variables, then restart the server.


## Testing

Run the test suite with pytest:

```bash
pytest -q
```

The tests use a separate SQLite test database (`test.db`) and override the FastAPI dependency to isolate state.


## CORS

`main.py` enables CORS with `allow_origins=["*"]` for local development. Tighten this for production.


## Notes

- The server automatically creates and migrates basic columns for the `services` table on startup for SQLite.
- The default AI model is `gpt-4o-mini`; change `AI_MODEL` to suit your provider.
- For production, configure a persistent database and restrict CORS.


## License

MIT 