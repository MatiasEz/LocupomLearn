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

## Public Deploy

Current public API:

```txt
https://locupom-topics-api.vercel.app
```

Deploy to Vercel Hobby:

```bash
cd LocupomTopicsAPI
vercel --prod
```

Vercel local project metadata lives in `.vercel/` and is intentionally ignored.

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
GET /readings?level=B1
GET /readings?level=B2&topic=technology
GET /readings?level=B1&learnerId=device-123
GET /exercises?level=B1&learnerId=device-123
GET /exercises?level=B1&skill=translation
GET /exercises?level=B1&skill=writing
GET /exercises?level=B1&skill=listening
GET /exercises?level=B1&skill=grammar
GET /exercises?level=B1&skill=sentence_builder
GET /vocabulary?level=B1
GET /progress?learnerId=device-123
POST /progress/completed
DELETE /progress/completed?learnerId=device-123&kind=reading&itemId=b1-music-standard-long-32
GET /roadmap?level=C1
GET /search?q=reported
```

## Levelled Readings

`GET /readings` returns one English reading passage calibrated to a CEFR level.
It uses the Locupom free CEFR library, so it does not require a paid API key,
external provider, billing account, or per-call payment.
The endpoint serves the latest long morning-brief reading when available, then
falls back to the Locupom free CEFR library. Every returned reading is formatted
as at least 30 paragraphs.

Response shape:

```json
{
  "provider": "locupom-free",
  "providerConfigured": true,
  "cost": "free",
  "reading": {
    "id": "b1-music-standard",
    "title": "Music: Learning through real interests",
    "level": "B1",
    "cefrLevel": "B1",
    "topic": "music",
    "estimatedMinutes": 5,
    "source": "Locupom free CEFR library",
    "variant": "2-4",
    "wordCount": 900,
    "paragraphCount": 32,
    "summary": "A B1 reading text about music.",
    "content": "...",
    "questions": [
      {
        "id": "main-idea",
        "prompt": "...",
        "options": ["...", "...", "..."],
        "answer": "...",
        "explanation": "..."
      }
    ]
  }
}
```

## Morning Brief Automation

The daily content script now refreshes the API-backed practice catalog used by
the iOS app:

```bash
cd LocupomTopicsAPI
npm run build:brief
```

It writes `data/morning-brief-content.json` with readings, speaking prompts,
skill-specific exercises and vocabulary. The app requests exercises by `level`
and `skill`, then falls back to local iOS decks only when the API is unavailable
or empty.

Practice exercise skills:

- `translation`
- `writing`
- `listening`
- `grammar`
- `sentence_builder`

Vocabulary items are also levelled and available through `GET /vocabulary`.

## Completion Progress

Use `learnerId` to keep completed content out of the app feed. The API stores
completed items as `kind:itemId`, so the same flow works for `reading`,
`exercise`, `speaking`, `vocabulary`, and `topic`.

Mark an item as completed:

```bash
curl -X POST https://locupom-topics-api.vercel.app/progress/completed \
  -H "Content-Type: application/json" \
  -d '{
    "learnerId": "device-123",
    "kind": "reading",
    "itemId": "b1-music-standard-long-32",
    "level": "B1",
    "title": "Music: The Notice on the Gate"
  }'
```

List completed items:

```txt
GET /progress?learnerId=device-123
```

Fetch content without completed items:

```txt
GET /readings?level=B1&learnerId=device-123
GET /exercises?level=B1&learnerId=device-123
GET /speaking?level=B1&learnerId=device-123
GET /topics?level=B1&learnerId=device-123
GET /morning-brief?learnerId=device-123
```

You can also keep progress locally in the app and pass IDs statelessly:

```txt
GET /exercises?level=B1&completed=exercise:weekday-2026-06-12-1906-ar-b1-exercise-gate
```

Undo a completion:

```txt
DELETE /progress/completed?learnerId=device-123&kind=reading&itemId=b1-music-standard-long-32
```

Progress is file-backed. Set `LOCUPOM_PROGRESS_FILE` for a durable JSON path in
local or self-hosted runs. Without it, the API writes to the system temp
directory, which can reset on serverless hosts; for permanent multi-device
sync, swap this storage layer for KV or a database.

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
