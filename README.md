# ИИ-новости

Сайт, который каждый день в 08:00 (UTC+5) собирает свежие новости про ИИ из RSS-лент и публикует их на GitHub Pages.

- `scripts/feeds.txt` — список источников (добавляйте/удаляйте строки `Название | URL`)
- `scripts/build.py` — сборщик (только стандартный Python)
- `scripts/template.html` — внешний вид страницы
- `.github/workflows/ai-news.yml` — расписание (cron) и публикация

Локально: `python scripts/build.py`, затем откройте `site/index.html`.
