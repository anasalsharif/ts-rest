#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import subprocess
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "tools/bumpkin/case_manifest.tsv"
OUT_DIR = ROOT / "artifacts/live-pr-validation"
OUT_TSV = OUT_DIR / "results.tsv"
OUT_SUMMARY = OUT_DIR / "summary.json"

REC_RE = re.compile(r"Recommendation\s*:\s*[^\n]*\b(MAJOR|MINOR|PATCH|NO_BUMP)\b")


@dataclass
class CaseRow:
    case_id: str
    expected: str
    branch: str
    title: str


def run_gh(args: list[str]) -> str:
    proc = subprocess.run(["gh", *args], capture_output=True, text=True)
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or proc.stdout.strip() or "gh command failed")
    return proc.stdout


def load_manifest() -> list[CaseRow]:
    rows: list[CaseRow] = []
    lines = MANIFEST.read_text().splitlines()
    for line in lines[1:]:
        if not line.strip():
            continue
        case_id, expected, branch, title = line.split("\t", 3)
        rows.append(CaseRow(case_id=case_id, expected=expected, branch=branch, title=title))
    return rows


def find_bumpkin_outcome(pr_number: int) -> tuple[str | None, str]:
    out = run_gh([
        "pr",
        "view",
        str(pr_number),
        "--json",
        "comments",
    ])
    payload = json.loads(out)
    comments = payload.get("comments", [])
    for comment in reversed(comments):
        body = str(comment.get("body", ""))
        if "<!-- bumpkin:recommendation -->" not in body:
            continue
        match = REC_RE.search(body)
        if match:
            return match.group(1), "classified"
        if "Manual Review Required" in body or "Manual review required" in body:
            return None, "manual_review"
        return None, "unknown_bumpkin_comment"
    return None, "missing_comment"


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    rows = load_manifest()

    records: list[dict[str, str]] = []
    for row in rows:
        pr_list_out = run_gh([
            "pr",
            "list",
            "--state",
            "all",
            "--head",
            row.branch,
            "--json",
            "number,url,state,mergedAt",
        ])
        pr_items = json.loads(pr_list_out)
        if not pr_items:
            records.append(
                {
                    "case": row.case_id,
                    "expected": row.expected,
                    "actual": "",
                    "status": "missing_pr",
                    "pr": "",
                    "url": "",
                }
            )
            continue

        pr = pr_items[0]
        pr_number = int(pr["number"])
        merged_at = pr.get("mergedAt")
        if not merged_at:
            records.append(
                {
                    "case": row.case_id,
                    "expected": row.expected,
                    "actual": "",
                    "status": "not_merged",
                    "pr": str(pr_number),
                    "url": str(pr.get("url", "")),
                }
            )
            continue

        observed, outcome = find_bumpkin_outcome(pr_number)
        if outcome == "missing_comment":
            records.append(
                {
                    "case": row.case_id,
                    "expected": row.expected,
                    "actual": "",
                    "status": "missing_comment",
                    "pr": str(pr_number),
                    "url": str(pr.get("url", "")),
                }
            )
            continue

        if outcome == "manual_review":
            records.append(
                {
                    "case": row.case_id,
                    "expected": row.expected,
                    "actual": "",
                    "status": "manual_review",
                    "pr": str(pr_number),
                    "url": str(pr.get("url", "")),
                }
            )
            continue

        if outcome != "classified" or not observed:
            records.append(
                {
                    "case": row.case_id,
                    "expected": row.expected,
                    "actual": "",
                    "status": outcome,
                    "pr": str(pr_number),
                    "url": str(pr.get("url", "")),
                }
            )
            continue

        status = "pass" if observed == row.expected else "fail"
        records.append(
            {
                "case": row.case_id,
                "expected": row.expected,
                "actual": observed,
                "status": status,
                "pr": str(pr_number),
                "url": str(pr.get("url", "")),
            }
        )

    header = "case\texpected\tactual\tstatus\tpr\turl"
    lines = [header]
    for rec in records:
        lines.append(
            "\t".join(
                [
                    rec["case"],
                    rec["expected"],
                    rec["actual"],
                    rec["status"],
                    rec["pr"],
                    rec["url"],
                ]
            )
        )
    OUT_TSV.write_text("\n".join(lines) + "\n")

    total = len(records)
    passes = sum(1 for r in records if r["status"] == "pass")
    fails = sum(1 for r in records if r["status"] == "fail")
    classified = passes + fails
    summary = {
        "total_cases": total,
        "classified_cases": classified,
        "pass": passes,
        "fail": fails,
        "accuracy": (passes / classified) if classified else 0.0,
        "manual_review": sum(1 for r in records if r["status"] == "manual_review"),
        "missing_pr": sum(1 for r in records if r["status"] == "missing_pr"),
        "not_merged": sum(1 for r in records if r["status"] == "not_merged"),
        "missing_comment": sum(1 for r in records if r["status"] == "missing_comment"),
    }
    OUT_SUMMARY.write_text(json.dumps(summary, indent=2) + "\n")

    print(f"Wrote {OUT_TSV}")
    print(f"Wrote {OUT_SUMMARY}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
