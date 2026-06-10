#!/usr/bin/env python3
"""Build Locupom curriculum JSON from the PDF guides shipped with the API."""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from pypdf import PdfReader


ROOT = Path(__file__).resolve().parents[1]
PDF_DIR = ROOT / "pdfs"
DATA_DIR = ROOT / "data"


@dataclass(frozen=True)
class PdfConfig:
    id: str
    level: str
    title: str
    file_name: str
    topic_mode: str
    grammar_limit: int | None = None


PDFS = [
    PdfConfig(
        id="pre-a1-guide",
        level="Pre-A1",
        title="Pre-A1 Guia de Estudio Explicativa",
        file_name="pre-a1-guia-estudio-explicativa-es.pdf",
        topic_mode="numbered",
    ),
    PdfConfig(
        id="a1-guide",
        level="A1",
        title="A1 Guia de Estudio Explicativa",
        file_name="a1-guia-estudio-explicativa-es.pdf",
        topic_mode="numbered",
        grammar_limit=15,
    ),
    PdfConfig(
        id="a2-guide",
        level="A2",
        title="A2 Guia de Estudio Explicativa",
        file_name="a2-guia-estudio-explicativa-es-final.pdf",
        topic_mode="numbered",
        grammar_limit=16,
    ),
    PdfConfig(
        id="b1-grammar-v1",
        level="B1",
        title="B1 Grammar Volumen 1 Explicativa",
        file_name="b1-guia-grammar-volumen-1-explicativa-es.pdf",
        topic_mode="unit",
    ),
    PdfConfig(
        id="b2-grammar-v1",
        level="B2",
        title="B2 Grammar Volumen 1 Explicativa",
        file_name="b2-guia-grammar-volumen-1-explicativa-es.pdf",
        topic_mode="unit",
    ),
    PdfConfig(
        id="c1-grammar-v1",
        level="C1",
        title="C1 Grammar Volumen 1 Explicativa",
        file_name="c1-guia-grammar-volumen-1-explicativa-es.pdf",
        topic_mode="numbered",
        grammar_limit=15,
    ),
    PdfConfig(
        id="c2-grammar-v1",
        level="C2",
        title="C2 Grammar Volumen 1 Explicativa",
        file_name="c2-guia-grammar-volumen-1-explicativa-es.pdf",
        topic_mode="c2",
    ),
]


SECTION_HEADINGS = [
    "uso",
    "uso e idea central",
    "learning goals",
    "explicación",
    "explicacion",
    "idea central",
    "think like this",
    "forma",
    "estructura",
    "forma / estructura",
    "estructuras clave",
    "patrones principales",
    "como leer la tabla",
    "cómo leer la tabla",
    "ejemplos",
    "ejemplos explicados",
    "usos principales con ejemplos explicados",
    "analisis c2",
    "análisis c2",
    "comparacion clave",
    "comparación clave",
    "model sentences",
    "errores comunes",
    "errores comunes de hispanohablantes",
    "checklist",
    "checklist de dominio",
    "checklist de precision",
    "checklist de precisión",
    "ejercicios",
    "práctica",
    "practica",
    "practica guiada",
    "práctica guiada",
    "practica independiente",
    "práctica independiente",
    "micro practica",
    "micro práctica",
    "produccion activa",
    "producción activa",
    "respuestas",
    "respuestas explicadas",
    "answer key",
    "quick review",
    "mini test",
    "mini test del capitulo",
    "mini test del capítulo",
]


def slugify(value: str) -> str:
    value = value.lower().replace("can't", "cant")
    value = re.sub(r"[^a-z0-9]+", "_", value)
    return value.strip("_")


def normalize_spaces(value: str) -> str:
    value = value.replace("\u00a0", " ")
    value = re.sub(r"[ \t]+", " ", value)
    value = re.sub(r"\n{3,}", "\n\n", value)
    return value.strip()


def clean_page_text(text: str, level: str) -> str:
    lines = []
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line:
            lines.append("")
            continue
        if re.fullmatch(r"(page|pagina|página)\s*\d+", line, re.I):
            continue
        if re.fullmatch(r"\d+", line):
            continue
        if re.search(r"gu[ií]a (de estudio )?explicativa", line, re.I):
            continue
        if re.search(rf"^{re.escape(level)}\s+(english|grammar)", line, re.I):
            continue
        lines.append(line)
    return normalize_spaces("\n".join(lines))


def walk_outline(outline: list[Any], reader: PdfReader, depth: int = 0, parents: tuple[str, ...] = ()) -> list[dict[str, Any]]:
    entries: list[dict[str, Any]] = []
    last_parent: tuple[str, ...] = parents
    for item in outline:
        if isinstance(item, list):
            entries.extend(walk_outline(item, reader, depth + 1, last_parent))
            continue
        title = getattr(item, "title", str(item)).strip()
        try:
            page = reader.get_destination_page_number(item) + 1
        except Exception:
            continue
        entry = {
            "title": title,
            "page": page,
            "depth": depth,
            "parents": list(parents),
            "path": list(parents + (title,)),
        }
        entries.append(entry)
        last_parent = parents + (title,)
    return entries


def title_from_numbered(title: str) -> tuple[int, str] | None:
    match = re.match(r"^(\d+)\.\s+(.+)$", title.strip())
    if not match:
        return None
    name = re.sub(r"\s+@.*$", "", match.group(2)).strip()
    return int(match.group(1)), name


def title_from_unit(title: str) -> tuple[int, str] | None:
    match = re.match(r"^Unit\s+(\d+)[:.]\s+(.+)$", title.strip(), re.I)
    if not match:
        return None
    return int(match.group(1)), match.group(2).strip()


def title_from_c2(title: str) -> tuple[int, str] | None:
    match = re.match(r"^(\d+)\.\s+(.+?)(?:\s+-\s+.+)?$", title.strip())
    if not match:
        return None
    return int(match.group(1)), match.group(2).strip()


def is_review_title(title: str) -> bool:
    return bool(re.search(r"(review|mock test|revision|checklist|workshop|routine|bank|repaso|pr[áa]ctica integrada)", title, re.I))


def collect_topic_starts(config: PdfConfig, outline: list[dict[str, Any]]) -> list[dict[str, Any]]:
    starts: list[dict[str, Any]] = []
    seen: set[tuple[int, str]] = set()

    for entry in outline:
        title = entry["title"]
        parsed: tuple[int, str] | None = None
        category = "grammar"

        if config.topic_mode == "numbered":
            parsed = title_from_numbered(title)
            if not parsed:
                if config.level in {"B1", "C1"} and is_review_title(title):
                    starts.append({
                        **entry,
                        "number": 900 + len(starts),
                        "topicTitle": title,
                        "category": "use_of_english",
                    })
                continue
            if config.level == "Pre-A1":
                category = "foundation"
            elif config.grammar_limit and parsed[0] > config.grammar_limit:
                category = "skills"

        elif config.topic_mode == "unit":
            parsed = title_from_unit(title)
            if not parsed:
                if entry["depth"] == 0 and is_review_title(title):
                    starts.append({
                        **entry,
                        "number": 900 + len(starts),
                        "topicTitle": title,
                        "category": "use_of_english",
                    })
                continue

        elif config.topic_mode == "c2":
            if entry["depth"] != 0:
                continue
            parsed = title_from_c2(title)
            if parsed and " - " in title:
                continue
            if not parsed:
                if entry["depth"] == 0 and is_review_title(title):
                    starts.append({
                        **entry,
                        "number": 900 + len(starts),
                        "topicTitle": title,
                        "category": "use_of_english",
                    })
                continue
            if parsed[0] > 13:
                category = "use_of_english"

        if not parsed:
            continue

        number, topic_title = parsed
        key = (number, topic_title.lower())
        if key in seen:
            continue
        seen.add(key)
        starts.append({
            **entry,
            "number": number,
            "topicTitle": topic_title,
            "category": category,
        })

    starts.sort(key=lambda item: (item["page"], item["number"]))
    return starts


def text_for_pages(pages: list[dict[str, Any]], start_page: int, end_page: int) -> str:
    chunks = [page["text"] for page in pages if start_page <= page["page"] <= end_page and page["text"]]
    return normalize_spaces("\n\n".join(chunks))


def clean_topic_text(text: str, title: str) -> str:
    lines = []
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped:
            lines.append("")
            continue
        if stripped.lower() == title.lower():
            continue
        if re.fullmatch(r"(contenido|contents|indice|índice)", stripped, re.I):
            continue
        lines.append(stripped)
    return normalize_spaces("\n".join(lines))


def split_blocks(text: str) -> list[dict[str, str]]:
    lines = [line.strip() for line in text.splitlines()]
    blocks: list[dict[str, str]] = []
    current_title = "Contenido del PDF"
    current_body: list[str] = []

    def flush() -> None:
        nonlocal current_body
        body = normalize_spaces("\n".join(current_body))
        if body:
            blocks.append({"title": current_title, "body": body})
        current_body = []

    for line in lines:
        if not line:
            current_body.append("")
            continue
        normalized = re.sub(r"^\d+\.\s+", "", line).strip().lower()
        normalized = normalized.rstrip(":")
        is_heading = (
            normalized in SECTION_HEADINGS
            or any(normalized.startswith(f"{heading}:") for heading in SECTION_HEADINGS)
        )
        if is_heading and len(line) <= 80:
            flush()
            current_title = line.rstrip(":")
        else:
            current_body.append(line)
    flush()

    if not blocks:
        blocks = chunk_text(text)
    return blocks


def chunk_text(text: str, size: int = 900) -> list[dict[str, str]]:
    paragraphs = [p.strip() for p in re.split(r"\n\s*\n", text) if p.strip()]
    blocks: list[dict[str, str]] = []
    buffer: list[str] = []
    current_len = 0
    for paragraph in paragraphs:
        if buffer and current_len + len(paragraph) > size:
            blocks.append({"title": f"Bloque {len(blocks) + 1}", "body": "\n\n".join(buffer)})
            buffer = []
            current_len = 0
        buffer.append(paragraph)
        current_len += len(paragraph)
    if buffer:
        blocks.append({"title": f"Bloque {len(blocks) + 1}", "body": "\n\n".join(buffer)})
    return blocks


def first_paragraph(text: str, max_chars: int = 420) -> str:
    paragraphs = [p.strip() for p in re.split(r"\n\s*\n", text) if p.strip()]
    if not paragraphs:
        return ""
    paragraph = re.sub(r"\s+", " ", paragraphs[0])
    if len(paragraph) <= max_chars:
        return paragraph
    return paragraph[:max_chars].rsplit(" ", 1)[0] + "..."


def extract_lines_after(text: str, heading_patterns: list[str], limit: int = 5) -> list[str]:
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    captures: list[str] = []
    active = False
    for line in lines:
        low = line.lower().rstrip(":")
        if any(re.search(pattern, low, re.I) for pattern in heading_patterns):
            active = True
            continue
        if active and any(low == h or low.startswith(h + ":") for h in SECTION_HEADINGS):
            if captures:
                break
            continue
        if active:
            if len(line) > 2:
                captures.append(line)
            if len(captures) >= limit:
                break
    return captures


def extract_examples(text: str) -> list[str]:
    examples = extract_lines_after(text, [r"^ejemplos", r"examples?"], limit=8)
    if examples:
        return examples

    candidates = []
    for line in text.splitlines():
        line = line.strip(" •-*")
        if not line or len(line) < 12 or len(line) > 140:
            continue
        has_english_signal = bool(re.search(r"\b(I|you|he|she|it|we|they|am|is|are|do|does|did|have|has|will|would|could|should|must|the|a|an)\b", line, re.I))
        if has_english_signal and re.search(r"[.!?]$", line):
            candidates.append(line)
        if len(candidates) >= 6:
            break
    return candidates[:6]


def extract_pattern(text: str, fallback: str) -> str:
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    for line in lines:
        low = line.lower()
        if any(key in low for key in ["formula", "pattern", "estructura", "forma", "patron", "patrón"]):
            if 8 <= len(line) <= 160:
                return line
        if any(symbol in line for symbol in [" + ", " -> ", "=>"]) and 8 <= len(line) <= 160:
            return line
    return fallback


def extract_common_mistakes(text: str) -> list[str]:
    mistakes = extract_lines_after(text, [r"errores comunes", r"common mistakes"], limit=6)
    return mistakes[:6] if mistakes else []


def extract_practice_ideas(text: str) -> list[str]:
    ideas = extract_lines_after(text, [r"ejercicios", r"pr[áa]ctica", r"micro pr[áa]ctica", r"producci[óo]n activa"], limit=6)
    return ideas[:6] if ideas else []


def make_practice_tasks(title: str, text: str, pattern: str) -> list[dict[str, Any]]:
    ideas = extract_practice_ideas(text)
    tasks = []
    for index, idea in enumerate(ideas[:3], start=1):
        tasks.append({
            "id": f"pdf_practice_{index}",
            "kind": "production" if index == 3 else "multiple_choice",
            "title": f"Práctica PDF {index}",
            "instruction": "Trabaja con esta consigna tomada de la guía.",
            "prompt": idea,
            "options": [] if index == 3 else [
                "Resolver mirando forma, significado y contexto.",
                "Traducir palabra por palabra sin revisar.",
                "Memorizar solo el título del tema."
            ],
            "answer": "" if index == 3 else "Resolver mirando forma, significado y contexto.",
            "explanation": "Esta práctica viene de la unidad PDF y se usa para convertir la explicación en producción."
        })

    if not tasks:
        tasks.append({
            "id": "pattern_control",
            "kind": "sentence_builder",
            "title": "Control del patrón",
            "instruction": "Usa el patrón de la unidad para producir una frase propia.",
            "prompt": pattern,
            "options": [pattern, "random words", "translation only"],
            "answer": pattern,
            "explanation": f"El objetivo es usar {title} con control, no solo reconocer el nombre del tema."
        })
    return tasks


def category_label(category: str) -> str:
    return {
        "foundation": "Foundation",
        "grammar": "Grammar",
        "skills": "Skills",
        "use_of_english": "Use of English",
    }.get(category, category.replace("_", " ").title())


def make_topic(config: PdfConfig, start: dict[str, Any], end_page: int, pages: list[dict[str, Any]], source_index: int) -> dict[str, Any]:
    title = start["topicTitle"]
    start_page = start["page"]
    full_text = clean_topic_text(text_for_pages(pages, start_page, end_page), title)
    if not full_text:
        full_text = title
    blocks = split_blocks(full_text)
    examples = extract_examples(full_text)
    mistakes = extract_common_mistakes(full_text)
    practice_ideas = extract_practice_ideas(full_text)
    pattern = extract_pattern(full_text, f"notice -> understand -> produce: {title}")
    summary = first_paragraph(full_text) or f"{title} from {config.title}."
    topic_id = f"{slugify(config.level)}_{slugify(title)}"
    category = start["category"]

    return {
        "id": topic_id,
        "title": title,
        "level": config.level,
        "levelOrder": ["Pre-A1", "A1", "A2", "B1", "B2", "C1", "C2"].index(config.level),
        "category": category,
        "categoryLabel": category_label(category),
        "order": source_index + 1,
        "sourceBasis": [
            "User-provided PDF study guide",
            config.title,
            "Full section text, examples, exercises and answer material preserved in source.fullText",
        ],
        "summary": summary,
        "pattern": pattern,
        "lessonBlocks": blocks,
        "learningObjectives": [
            f"Entender para qué sirve {title}.",
            "Identificar forma, significado y ejemplos dentro de la unidad PDF.",
            "Completar una práctica y producir una frase propia con feedback.",
        ],
        "examples": examples or [f"Open the PDF section for examples of {title}."],
        "commonMistakes": mistakes or ["Revisar la sección de errores comunes de la unidad antes de producir."],
        "practiceIdeas": practice_ideas or [
            "Lee la explicación completa.",
            "Copia tres ejemplos y cambia una palabra.",
            "Haz los ejercicios de la unidad y revisa las respuestas.",
        ],
        "practiceTasks": make_practice_tasks(title, full_text, pattern),
        "externalResources": {
            "sourcePdf": {
                "provider": "Locupom PDF",
                "documentId": config.id,
                "path": f"/pdfs/{config.file_name}",
                "pages": [start_page, end_page],
            },
            "authenticExamples": {
                "provider": "Tatoeba",
                "query": title,
                "description": "Real English sentences with Spanish translations when available.",
            },
            "wordBank": {
                "provider": "Datamuse",
                "query": title,
                "description": "Related words and collocations for vocabulary expansion.",
            },
            "writingCheck": {
                "provider": "LanguageTool",
                "description": "Grammar and style feedback for the production task.",
            },
        },
        "quiz": {
            "question": f"¿Cómo conviene estudiar {title}?",
            "options": [
                "Leer uso, forma, ejemplos, práctica y respuestas de la unidad.",
                "Memorizar solo el título del tema.",
                "Saltar la producción propia.",
            ],
            "answer": "Leer uso, forma, ejemplos, práctica y respuestas de la unidad.",
            "explanation": "La guía está organizada para entender primero y practicar después con autocorrección.",
        },
        "source": {
            "documentId": config.id,
            "documentTitle": config.title,
            "pdfPath": f"pdfs/{config.file_name}",
            "pageStart": start_page,
            "pageEnd": end_page,
            "outlinePath": start.get("path", []),
            "fullText": full_text,
        },
    }


def build_document(config: PdfConfig) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    pdf_path = PDF_DIR / config.file_name
    if not pdf_path.exists():
        raise FileNotFoundError(pdf_path)

    reader = PdfReader(str(pdf_path))
    pages = []
    for index, page in enumerate(reader.pages, start=1):
        text = clean_page_text(page.extract_text() or "", config.level)
        pages.append({"page": index, "text": text})

    outline = walk_outline(reader.outline, reader)
    starts = collect_topic_starts(config, outline)

    source_sections = []
    sorted_outline = sorted(outline, key=lambda item: (item["page"], item["depth"], item["title"]))
    for index, entry in enumerate(sorted_outline):
        next_page = sorted_outline[index + 1]["page"] if index + 1 < len(sorted_outline) else len(pages) + 1
        end_page = max(entry["page"], next_page - 1)
        source_sections.append({
            "title": entry["title"],
            "pageStart": entry["page"],
            "pageEnd": end_page,
            "depth": entry["depth"],
            "path": entry["path"],
            "text": text_for_pages(pages, entry["page"], end_page),
        })

    topics = []
    for index, start in enumerate(starts):
        next_start_page = starts[index + 1]["page"] if index + 1 < len(starts) else len(pages) + 1
        end_page = max(start["page"], next_start_page - 1)
        topics.append(make_topic(config, start, end_page, pages, index))

    document = {
        "id": config.id,
        "level": config.level,
        "title": config.title,
        "fileName": config.file_name,
        "pdfPath": f"pdfs/{config.file_name}",
        "pageCount": len(pages),
        "topicCount": len(topics),
        "pages": pages,
        "outline": outline,
        "sections": source_sections,
        "fullText": normalize_spaces("\n\n".join(page["text"] for page in pages if page["text"])),
    }
    return document, topics


def main() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    sources = []
    topics = []
    for config in PDFS:
        document, document_topics = build_document(config)
        sources.append(document)
        topics.extend(document_topics)

    payload = {
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "sourceCount": len(sources),
        "topicCount": len(topics),
        "sources": sources,
        "topics": topics,
    }

    output = DATA_DIR / "curriculum.generated.json"
    output.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Wrote {output.relative_to(ROOT)}")
    print(f"Sources: {len(sources)}")
    print(f"Topics: {len(topics)}")
    for source in sources:
        print(f"- {source['level']}: {source['topicCount']} topics, {source['pageCount']} pages")


if __name__ == "__main__":
    main()
