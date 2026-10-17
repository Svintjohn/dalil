import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
for _k in ("ANTHROPIC_API_KEY", "GEMINI_API_KEY", "GOOGLE_API_KEY", "DALIL_PROVIDER"):
    os.environ.pop(_k, None)
os.environ.pop("DALIL_APP_TOKEN", None)
