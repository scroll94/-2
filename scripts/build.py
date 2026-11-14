#!/usr/bin/env python3
"""Собирает новости про ИИ из RSS/Atom-лент и генерирует site/index.html.

Только стандартная библиотека Python — ничего устанавливать не нужно.
"""
import html
import re
import sys
import urllib.request
import xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from email.utils import parsedate_to_datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FEEDS_FILE = ROOT / "scripts" / "feeds.txt"
OUT_DIR = ROOT / "site"
DAYS_BACK = 3          # сколько дней новостей показывать
MAX_PER_SOURCE = 15    # максимум новостей с одного источника
LOCAL_TZ = timezone(timedelta(hours=5))  # часовой пояс для отображения (UTC+5)

ATOM = "{http://www.w3.org/2005/Atom}"
MEDIA = "{http://search.yahoo.com/mrss/}"
CONTENT = "{http://purl.org/rss/1.0/modules/content/}"
IMG_RE = re.compile(r'<img[^>]+src=["\']([^"\']+)["\']', re.I)


def find_image(it, *html_texts):
    """Ищет картинку: media:content / media:thumbnail / enclosure / первый <img> в тексте."""
    for tag in (f"{MEDIA}thumbnail", f"{MEDIA}content"):
        for el in it.iter(tag):
            url = el.get("url", "")
            if url.startswith("http") and el.get("medium", "image") == "image":
                return url
    for el in it.findall("enclosure") + it.findall(f"{ATOM}link"):
        if (el.get("type") or "").startswith("image/"):
            url = el.get("url") or el.get("href") or ""
            if url.startswith("http"):
                return url
    for text in html_texts:
        m = IMG_RE.search(html.unescape(text or ""))
        if m and m.group(1).startswith("http"):
            return m.group(1)
    return ""


def load_feeds():
    feeds = []
    for line in FEEDS_FILE.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "|" not in line:
            continue
        name, url = (p.strip() for p in line.split("|", 1))
        feeds.append((name, url))
    return feeds


def parse_date(text):
    if not text:
        return None
    text = text.strip()
    try:
        d = parsedate_to_datetime(text)
    except (TypeError, ValueError):
        try:
            d = datetime.fromisoformat(text.replace("Z", "+00:00"))
        except ValueError:
            return None
    if d.tzinfo is None:
        d = d.replace(tzinfo=timezone.utc)
    return d


def clean(text, limit=260):
    text = re.sub(r"<[^>]+>", " ", text or "")
    text = html.unescape(re.sub(r"\s+", " ", text)).strip()
    return text if len(text) <= limit else text[:limit].rsplit(" ", 1)[0] + "…"


def fetch(name, url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (AI news digest bot)"})
    try:
        with urllib.request.urlopen(req, timeout=25) as r:
            root = ET.fromstring(r.read())
    except Exception as e:  # noqa: BLE001
        print(f"  ✗ {name}: {e}", file=sys.stderr)
        return []

    items = []
    for it in root.iter("item"):  # RSS
        items.append({
            "title": clean(it.findtext("title"), 300),
            "link": (it.findtext("link") or "").strip(),
            "date": parse_date(it.findtext("pubDate") or it.findtext("{http://purl.org/dc/elements/1.1/}date")),
            "summary": clean(it.findtext("description")),
            "image": find_image(it, it.findtext(f"{CONTENT}encoded"), it.findtext("description")),
        })
    for it in root.iter(f"{ATOM}entry"):  # Atom
        link = ""
        for l in it.findall(f"{ATOM}link"):
            if l.get("rel", "alternate") == "alternate":
                link = l.get("href", "")
                break
        items.append({
            "title": clean(it.findtext(f"{ATOM}title"), 300),
            "link": link,
            "date": parse_date(it.findtext(f"{ATOM}published") or it.findtext(f"{ATOM}updated")),
            "summary": clean(it.findtext(f"{ATOM}summary") or it.findtext(f"{ATOM}content")),
            "image": find_image(it, it.findtext(f"{ATOM}content"), it.findtext(f"{ATOM}summary")),
        })

    items = [i for i in items if i["title"] and i["link"].startswith("http")]
    for i in items:
        i["source"] = name
    print(f"  ✓ {name}: {len(items)}", file=sys.stderr)
    return items[:MAX_PER_SOURCE * 2]


def render(news, sources_ok, now):
    def card(n):
        d = n["date"].astimezone(LOCAL_TZ).strftime("%d.%m %H:%M") if n["date"] else ""
        summary = f'<p>{html.escape(n["summary"])}</p>' if n["summary"] else ""
        hue = sum(map(ord, n["source"])) * 47 % 360
        ph = f'<span class="ph" style="--h:{hue}">{html.escape(n["source"])}</span>'
        img = (f'<img src="{html.escape(n["image"])}" alt="" loading="lazy" referrerpolicy="no-referrer" '
               f'onerror="this.replaceWith(this.nextElementSibling.content.cloneNode(true))">'
               f'<template>{ph}</template>') if n["image"] else ph
        return (
            f'<article data-src="{html.escape(n["source"])}">'
            f'<a class="thumb" href="{html.escape(n["link"])}" target="_blank" rel="noopener" tabindex="-1">{img}</a>'
            f'<div class="body"><div class="meta"><span class="src">{html.escape(n["source"])}</span><time>{d}</time></div>'
            f'<h2><a href="{html.escape(n["link"])}" target="_blank" rel="noopener">{html.escape(n["title"])}</a></h2>'
            f"{summary}</div></article>"
        )

    chips = "".join(
        f'<button class="chip" data-src="{html.escape(s)}">{html.escape(s)}</button>' for s in sources_ok
    )
    cards = "\n".join(card(n) for n in news) or "<p>Новостей пока нет.</p>"
    updated = now.astimezone(LOCAL_TZ).strftime("%d.%m.%Y %H:%M")
    template = (ROOT / "scripts" / "template.html").read_text(encoding="utf-8")
    return (template.replace("{{UPDATED}}", updated)
                    .replace("{{COUNT}}", str(len(news)))
                    .replace("{{CHIPS}}", chips)
                    .replace("{{CARDS}}", cards))


def main():
    now = datetime.now(timezone.utc)
    cutoff = now - timedelta(days=DAYS_BACK)
    feeds = load_feeds()
    print(f"Загружаю {len(feeds)} лент…", file=sys.stderr)
    with ThreadPoolExecutor(max_workers=8) as ex:
        results = list(ex.map(lambda f: fetch(*f), feeds))

    news, seen, sources_ok = [], set(), []
    for (name, _), items in zip(feeds, results):
        fresh = [i for i in items if i["date"] is None or i["date"] >= cutoff]
        fresh.sort(key=lambda i: i["date"] or now, reverse=True)
        fresh = fresh[:MAX_PER_SOURCE]
        if fresh:
            sources_ok.append(name)
        for i in fresh:
            key = i["link"].split("?")[0].rstrip("/")
            if key not in seen:
                seen.add(key)
                news.append(i)

    news.sort(key=lambda i: i["date"] or cutoff, reverse=True)
    OUT_DIR.mkdir(exist_ok=True)
    (OUT_DIR / "index.html").write_text(render(news, sources_ok, now), encoding="utf-8")
    print(f"Готово: {len(news)} новостей → {OUT_DIR / 'index.html'}", file=sys.stderr)
    if not news:
        sys.exit("Не удалось получить ни одной новости")


if __name__ == "__main__":
    main()
