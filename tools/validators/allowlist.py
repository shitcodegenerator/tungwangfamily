"""驗證例外清單（assets/maps/validation_allowlist.json）。

每筆必須有 id、rule、scene、subject、reason、owner、expires_phase。
current_phase >= expires_phase 時例外失效：對應的 finding 重新成為錯誤，並另外報 MAP-A001 提醒清理。
"""
from __future__ import annotations

from pathlib import Path

from .common import ROOT, Finding, load_json

ALLOWLIST_PATH = ROOT / "assets" / "maps" / "validation_allowlist.json"
REQUIRED_KEYS = ("id", "rule", "scene", "subject", "reason", "owner", "expires_phase")


def phase_number(value) -> float:
    try:
        return float(str(value))
    except ValueError:
        return float("inf")


class Allowlist:
    def __init__(self, raw: dict):
        self.current_phase = phase_number(raw.get("current_phase", "0"))
        self.entries: list[dict] = list(raw.get("entries", []))
        self.problems: list[Finding] = []
        self.active: dict[tuple[str, str, str], dict] = {}
        self.used: set[str] = set()
        for entry in self.entries:
            missing = [key for key in REQUIRED_KEYS if not entry.get(key)]
            if missing:
                self.problems.append(Finding("MAP-A001", str(entry.get("scene", "?")), str(entry.get("id", "?")), f"allowlist 缺少欄位 {missing}", fix="補齊 id、rule、scene、subject、reason、owner、expires_phase"))
                continue
            if self.current_phase >= phase_number(entry["expires_phase"]):
                self.problems.append(Finding("MAP-A001", entry["scene"], entry["id"], f"allowlist 例外已到期（expires_phase {entry['expires_phase']}，目前 {self.current_phase:g}）", fix="修正資料後刪除這筆，或由作者展延並寫明理由"))
                continue
            self.active[(entry["rule"], entry["scene"], entry["subject"])] = entry

    @classmethod
    def load(cls, path: Path = ALLOWLIST_PATH) -> "Allowlist":
        if not path.exists():
            return cls({"current_phase": "0", "entries": []})
        return cls(load_json(path))

    def covers(self, finding: Finding) -> dict | None:
        entry = self.active.get(finding.key())
        if entry is not None:
            self.used.add(entry["id"])
        return entry

    def unused(self) -> list[Finding]:
        return [
            Finding("MAP-A002", entry["scene"], entry["id"], "allowlist 例外沒有對應任何違規（已可刪除）", fix="從 validation_allowlist.json 移除")
            for entry in self.active.values()
            if entry["id"] not in self.used
        ]


def suggest_entry(finding: Finding, phase: str = "9") -> dict:
    return {
        "id": f"{finding.code.lower()}-{finding.scene}-{finding.subject.split('(')[0].replace('/', '_')}",
        "rule": finding.code,
        "scene": finding.scene,
        "subject": finding.subject,
        "reason": "TODO：寫明為什麼暫時不能修",
        "owner": "local_ai",
        "expires_phase": phase,
    }
