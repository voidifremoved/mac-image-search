import os, sys, base64
from pathlib import Path

def write_file(rel_path, content):
    p = Path(rel_path)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(content, encoding='utf-8')
    print(f'WROTE: {rel_path}')
