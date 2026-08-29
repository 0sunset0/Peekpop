#!/usr/bin/env python3
"""Generates tasks/{task-dir}/docs-diff.md from the git diff of docs/ between
the task's recorded baseline commit and HEAD (i.e. after phase 0 completes).

Usage: python3 scripts/gen-docs-diff.py <task-dir>

See prompts/task-create.md section 3.
"""
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TASKS_DIR = ROOT / "tasks"


def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, check=True, capture_output=True, text=True).stdout


def main() -> None:
    if len(sys.argv) != 2:
        print("usage: python3 scripts/gen-docs-diff.py <task-dir>")
        sys.exit(1)

    task_dir = sys.argv[1]
    task_index_path = TASKS_DIR / task_dir / "index.json"
    task_index = json.loads(task_index_path.read_text())

    baseline = task_index.get("baseline_commit")
    if not baseline:
        print(f"no baseline_commit recorded in {task_index_path}, skipping docs-diff.md")
        return

    diff = git("diff", baseline, "HEAD", "--", "docs/")
    short_baseline = git("rev-parse", "--short", baseline).strip()

    lines = [f"# docs-diff: {task_index['task']}", "", f"Baseline: `{short_baseline}`", ""]
    if not diff.strip():
        lines.append("(no changes under docs/ since baseline)")
    else:
        # Split the combined diff by file and emit one fenced block per file.
        current_file = None
        buffer = []

        def flush():
            if current_file and buffer:
                lines.append(f"## `{current_file}`")
                lines.append("")
                lines.append("```diff")
                lines.extend(buffer)
                lines.append("```")
                lines.append("")

        for line in diff.splitlines():
            if line.startswith("diff --git"):
                flush()
                buffer = []
                # "diff --git a/docs/x.md b/docs/x.md" -> docs/x.md
                parts = line.split(" ")
                current_file = parts[-1][2:] if parts[-1].startswith("b/") else parts[-1]
            else:
                buffer.append(line)
        flush()

    out_path = TASKS_DIR / task_dir / "docs-diff.md"
    out_path.write_text("\n".join(lines) + "\n")
    print(f"wrote {out_path}")


if __name__ == "__main__":
    main()
