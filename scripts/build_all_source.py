# Phase source builder
import os
from pathlib import Path

def write_file(rel_path: str, content: str):
    p = Path(rel_path)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(content.strip() + '
', encoding='utf-8')
    print(f'WROTE: {rel_path}')
