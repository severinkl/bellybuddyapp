# Buddy trace tooling

1. Create a venv and install deps: `python -m venv .venv && . .venv/bin/activate && pip install -r requirements.txt`.
2. Trace a mascot PNG: `python -I trace.py <png> <out.dart>` (potracer treats dark pixels as filled, so masks are inverted).
3. Render check: `python -I render.py <out.dart> <preview.png>` and inspect the preview before committing shape data.
