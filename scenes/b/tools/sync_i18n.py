"""Rebuild generated locale catalog after editing strings_ui.csv."""
from pathlib import Path
import csv, json
folder = Path(__file__).resolve().parents[1] / "i18n"
with (folder / "strings_ui.csv").open(encoding="utf-8", newline="") as stream:
    rows = list(csv.DictReader(stream))
keys = [row["keys"] for row in rows]
if len(keys) != len(set(keys)):
    raise ValueError("Duplicate translation keys")
tables = {locale: {row["keys"]: row[locale] for row in rows} for locale in ["es", "en"]}
(folder / "catalog.gd").write_text("extends RefCounted\nconst TABLES = " + json.dumps(tables, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print("ES/EN catalog rebuilt")
