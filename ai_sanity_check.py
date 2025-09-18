import json
import os
import httpx

def main(base: str | None = None):
    if not base:
        base = os.getenv("BASE_URL", "http://127.0.0.1:8002")
    triage_body = {
        "symptom": "persistent cough and mild fever",
        "age": 34,
        "sex": "female",
        "pregnant": False,
        "chronic_conditions": ["asthma"],
        "location": "Amman, Jordan",
        "language": "Arabic",
    }
    chat_body = {
        "history": [
            {"role": "user", "content": "What can I do for a child with diarrhea?"}
        ],
        "language": "English",
    }
    with httpx.Client(timeout=60) as client:
        r1 = client.post(f"{base}/ai/triage-advice", json=triage_body)
        print("/ai/triage-advice:")
        print(r1.status_code)
        try:
            print(json.dumps(r1.json(), ensure_ascii=False, indent=2))
        except Exception:
            print(r1.text)
        print("\n---\n")
        r2 = client.post(f"{base}/ai/chat", json=chat_body)
        print("/ai/chat:")
        print(r2.status_code)
        try:
            print(json.dumps(r2.json(), ensure_ascii=False, indent=2))
        except Exception:
            print(r2.text)

if __name__ == "__main__":
    main()
