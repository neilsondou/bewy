import os
import json
import hashlib
from dataclasses import dataclass, field
from typing import List, Optional, Dict
from pathlib import Path


@dataclass
class FileInfo:
    path: str
    size: int
    hash: str
    tags: List[str] = field(default_factory=list)


class FileIndexer:
    def __init__(self, root_dir: str):
        self.root = Path(root_dir)
        self.index: Dict[str, FileInfo] = {}

    def _compute_hash(self, filepath: Path) -> str:
        sha256 = hashlib.sha256()
        with open(filepath, 'rb') as f:
            for chunk in iter(lambda: f.read(8192), b''):
                sha256.update(chunk)
        return sha256.hexdigest()

    def scan(self, extensions: Optional[List[str]] = None) -> int:
        count = 0
        for entry in self.root.rglob('*'):
            if not entry.is_file():
                continue
            if extensions and entry.suffix not in extensions:
                continue
            info = FileInfo(
                path=str(entry.relative_to(self.root)),
                size=entry.stat().st_size,
                hash=self._compute_hash(entry),
            )
            self.index[info.path] = info
            count += 1
        return count

    def find_duplicates(self) -> Dict[str, List[str]]:
        hash_map: Dict[str, List[str]] = {}
        for path, info in self.index.items():
            hash_map.setdefault(info.hash, []).append(path)
        return {h: paths for h, paths in hash_map.items() if len(paths) > 1}

    def export_json(self, output: str):
        data = {k: vars(v) for k, v in self.index.items()}
        with open(output, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)


if __name__ == '__main__':
    indexer = FileIndexer('.')
    n = indexer.scan(extensions=['.py', '.txt', '.json'])
    print(f"Indexed {n} files")
    dupes = indexer.find_duplicates()
    if dupes:
        print(f"Found {len(dupes)} duplicate groups")
    indexer.export_json('file_index.json')
