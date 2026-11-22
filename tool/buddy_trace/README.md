# Buddy trace tooling

1. Create a venv and install deps: `python -m venv .venv && . .venv/bin/activate && pip install -r requirements.txt`.
2. Trace a mascot PNG: `python -I trace.py <png> <out.dart>` (potracer treats dark pixels as filled, so masks are inverted).
3. Render check: `python -I render.py <out.dart> <preview.png>` and inspect the preview before committing shape data.
4. Review renders of the animated Buddy (all moods + actions): `flutter test tool/buddy_frames/render_frames_test.dart --update-goldens` → PNGs in `tool/buddy_frames/frames/` (gitignored); contact sheet: `python -I sheet.py <sheet.png> ../buddy_frames/frames/*.png`.
