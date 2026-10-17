"""Vercel entry point. Vercel serves the ASGI app named `app` from this file."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "backend"))

from dalil.app import app  # noqa: E402,F401
