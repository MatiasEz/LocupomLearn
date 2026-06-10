# Locupom Topics API

Local API for Locupom's English-learning curriculum.

The main source of truth is now the PDF curriculum inside `pdfs/`. The build script extracts every page, outline section and unit into `data/curriculum.generated.json`, then `server.js` serves that generated data. Each topic keeps a structured app-friendly shape plus the full PDF section text under `source.fullText`.

Current PDF-backed levels:

- Pre-A1
- A1
- A2
- B1
- B2
- C1
- C2

## Run

```bash
node LocupomTopicsAPI/server.js
```

Default port: `8787`.

```bash
PORT=9090 node LocupomTopicsAPI/server.js
```

## Rebuild Data From PDFs

```bash
cd LocupomTopicsAPI
python3 scripts/build_pdf_curriculum.py
```

Generated output:

```txt
data/curriculum.generated.json
```

The generated JSON includes:

- original PDF metadata
- full text for every page
- outline entries and source sections
- topic units with summaries, lesson blocks, examples, mistakes, practice tasks and quiz data
- `source.fullText` for the full unit text

## Endpoints

```txt
GET /health
GET /levels
GET /categories
GET /sources
GET /sources/:id
GET /sources/:id/pdf
GET /topics
GET /topics?level=B1
GET /topics?level=B2&category=grammar
GET /topics?level=A1&includeAll=true
GET /topics/passive_voice
GET /topics/:id/source
GET /roadmap?level=C1
GET /search?q=reported
```

## Topic Shape

```json
{
  "id": "passive_voice",
  "title": "Passive voice",
  "level": "B1",
  "category": "grammar",
  "summary": "...",
  "pattern": "be + past participle",
  "learningObjectives": [],
  "examples": [],
  "commonMistakes": [],
  "practiceIdeas": [],
  "quiz": {},
  "source": {
    "documentId": "b2-grammar-v1",
    "pdfPath": "pdfs/b2-guia-grammar-volumen-1-explicativa-es.pdf",
    "pageStart": 4,
    "pageEnd": 8,
    "fullText": "..."
  }
}
```

## Notes

- Use this API as the source of truth for the app.
- Keep a small local fallback in iOS for offline mode.
- Add or replace PDFs in `pdfs/`, then run `python3 scripts/build_pdf_curriculum.py`.
- `server.js` still has the old curated catalog as fallback if generated data is missing.
