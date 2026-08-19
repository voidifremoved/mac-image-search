import os, base64
from pathlib import Path

def write_b64(rel_path, b64_str):
    p = Path(rel_path)
    p.parent.mkdir(parents=True, exist_ok=True)
    content = base64.b64decode(b64_str.strip()).decode("utf-8")
    p.write_text(content, encoding="utf-8")
    print(f"CREATED: {rel_path}")

if __name__ == "__main__":
    print("create_files.py ready")
