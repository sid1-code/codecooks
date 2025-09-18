import os
from openai import OpenAI

api_key = os.getenv("OPENAI_API_KEY")
project = os.getenv("OPENAI_PROJECT_ID")
org = os.getenv("OPENAI_ORG_ID")

print("Has key:", bool(api_key))
client = OpenAI(api_key=api_key, project=project, organization=org)

try:
    # List models to verify credentials and access
    models = client.models.list()
    print("Total models:", len(models.data))
    # Try a quick responses call
    resp = client.responses.create(model=os.getenv("AI_MODEL", "gpt-4o-mini"), input="Say hello")
    # Print a snippet
    if hasattr(resp, "output_text") and resp.output_text:
        print("Response text:", resp.output_text[:120])
    else:
        print("Responses output items:", [getattr(it, 'type', None) for it in (resp.output or [])])
except Exception as e:
    print("Error:", repr(e))
