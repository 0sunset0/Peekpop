#!/usr/bin/env python3
"""Runs a task's phases sequentially by invoking `claude -p` per phase.

Usage: python3 scripts/run-phases.py <task-dir>   (e.g. 0-mvp-v0)

See prompts/task-create.md for the full spec this implements.
"""
import json
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TASKS_DIR = ROOT / "tasks"

COMMIT_MSG_TEMPLATE = "feat({task_name}): phase {phase} — {phase_name}"
RUNNER_COMMIT_MSG_TEMPLATE = "chore({task_name}): phase {phase} output + timestamps"

def build_preamble(project: str, task_dir: str, task_name: str, phase_num: int, phase_name: str) -> str:
    # f-string, not str.format() — the commit-message line below intentionally
    # contains braces that must NOT be treated as format placeholders.
    return f"""당신은 {project} 프로젝트의 개발자입니다. 아래 phase의 작업을 수행하세요.

중요한 규칙:
1. 작업 전에 반드시 문서를 읽고 전체 설계를 이해하세요.
2. 이전 phase에서 작성된 코드를 꼼꼼히 읽고, 기존 코드와의 일관성을 유지하세요.
3. AC 검증을 직접 수행하고, 통과/실패에 따라 /tasks/{task_dir}/index.json을 업데이트하세요.
4. 불필요한 파일이나 코드를 추가하지 마세요. phase에 명시된 것만 작업하세요.
5. 기존 테스트를 깨뜨리지 마세요.
6. AC 통과 후, index.json 업데이트까지 완료했다면, 모든 변경사항을 아래 형식으로 커밋하세요:
   feat({task_name}): phase {phase_num} — {phase_name}

아래는 이번 phase의 상세 내용입니다:
"""


def now_iso() -> str:
    return datetime.now(timezone.utc).astimezone().strftime("%Y-%m-%dT%H:%M:%S%z")


def load_json(path: Path):
    return json.loads(path.read_text())


def save_json(path: Path, data) -> None:
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")


def git(*args, check=True):
    return subprocess.run(["git", *args], cwd=ROOT, check=check, capture_output=True, text=True)


def has_uncommitted_changes() -> bool:
    result = git("status", "--porcelain")
    return bool(result.stdout.strip())


def spinner_line(current: int, total: int, elapsed: float, label: str) -> None:
    sys.stdout.write(f"\r[{current}/{total}] {label} ({elapsed:0.0f}s elapsed)   ")
    sys.stdout.flush()


def run_phase(task_dir: str, task_index_path: Path, task_index: dict, phase_entry: dict) -> str:
    phase_num = phase_entry["phase"]
    phase_name = phase_entry["name"]
    phase_file = TASKS_DIR / task_dir / f"phase{phase_num}.md"
    phase_content = phase_file.read_text()

    preamble = build_preamble(
        project=task_index.get("project", "Peekpop"),
        task_dir=task_dir,
        task_name=task_index["task"],
        phase_num=phase_num,
        phase_name=phase_name,
    )
    prompt = preamble + "\n" + phase_content

    phase_entry["status"] = "running"
    phase_entry["started_at"] = now_iso()
    save_json(task_index_path, task_index)

    start = time.time()
    proc = subprocess.run(
        ["claude", "-p", "--dangerously-skip-permissions", "--output-format", "json", prompt],
        cwd=ROOT, capture_output=True, text=True,
    )
    elapsed = time.time() - start

    output_path = TASKS_DIR / task_dir / f"phase{phase_num}-output.json"
    save_json(output_path, {
        "phase": phase_num,
        "returncode": proc.returncode,
        "elapsed_seconds": elapsed,
        "stdout": proc.stdout,
        "stderr": proc.stderr,
    })

    # Re-read index.json — the phase's own session is expected to have updated it.
    task_index = load_json(task_index_path)
    updated_entry = next(p for p in task_index["phases"] if p["phase"] == phase_num)
    status = updated_entry.get("status")

    if status == "completed":
        pass
    elif status == "error":
        print(f"\nphase {phase_num} ({phase_name}) reported error: {updated_entry.get('error_message', '(no message)')}")
    else:
        updated_entry["status"] = "error"
        updated_entry["failed_at"] = now_iso()
        updated_entry["error_message"] = "phase session ended without updating status"
        save_json(task_index_path, task_index)
        status = "error"
        print(f"\nphase {phase_num} ({phase_name}) did not update its own status — marked error")

    # Claude fallback commit, only if there are changes the phase session didn't commit itself.
    if has_uncommitted_changes():
        git("add", "-A")
        msg = COMMIT_MSG_TEMPLATE.format(task_name=task_index["task"], phase=phase_num, phase_name=phase_name)
        git("commit", "-m", msg)

    # Runner housekeeping commit: phase-output.json + timestamp updates.
    git("add", str(output_path.relative_to(ROOT)), str(task_index_path.relative_to(ROOT)))
    if has_uncommitted_changes():
        msg = RUNNER_COMMIT_MSG_TEMPLATE.format(task_name=task_index["task"], phase=phase_num)
        git("commit", "-m", msg)

    if phase_num == 0 and status == "completed":
        gen_docs_diff = ROOT / "scripts" / "gen-docs-diff.py"
        if gen_docs_diff.exists():
            subprocess.run([sys.executable, str(gen_docs_diff), task_dir], cwd=ROOT, check=False)
            diff_path = TASKS_DIR / task_dir / "docs-diff.md"
            if diff_path.exists() and has_uncommitted_changes():
                git("add", str(diff_path.relative_to(ROOT)))
                git("commit", "-m", f"chore({task_index['task']}): add docs-diff.md")

    return status


def ensure_branch(task_name: str) -> None:
    branch = f"feat-{task_name}"
    existing = git("branch", "--list", branch).stdout.strip()
    current = git("rev-parse", "--abbrev-ref", "HEAD").stdout.strip()
    if current == branch:
        return
    if existing:
        git("checkout", branch)
    else:
        git("checkout", "-b", branch)


def main() -> None:
    if len(sys.argv) != 2:
        print("usage: python3 scripts/run-phases.py <task-dir>")
        sys.exit(1)

    task_dir = sys.argv[1]
    task_index_path = TASKS_DIR / task_dir / "index.json"
    if not task_index_path.exists():
        print(f"no such task: {task_index_path}")
        sys.exit(1)

    task_index = load_json(task_index_path)
    ensure_branch(task_index["task"])

    top_index_path = TASKS_DIR / "index.json"

    while True:
        task_index = load_json(task_index_path)
        pending = [p for p in task_index["phases"] if p["status"] == "pending"]
        if not pending:
            break
        phase_entry = pending[0]
        total = task_index["totalPhases"]
        current = phase_entry["phase"] + 1
        spinner_line(current, total, 0, f"starting phase {phase_entry['phase']} — {phase_entry['name']}")
        print()
        status = run_phase(task_dir, task_index_path, task_index, phase_entry)
        if status != "completed":
            print(f"stopping: phase {phase_entry['phase']} did not complete")
            if top_index_path.exists():
                top_index = load_json(top_index_path)
                for t in top_index["tasks"]:
                    if t["dir"] == task_dir:
                        t["status"] = "error"
                        t["failed_at"] = now_iso()
                save_json(top_index_path, top_index)
            sys.exit(1)

    print(f"\nall phases complete for {task_dir}")
    if top_index_path.exists():
        top_index = load_json(top_index_path)
        for t in top_index["tasks"]:
            if t["dir"] == task_dir:
                t["status"] = "completed"
                t["completed_at"] = now_iso()
        save_json(top_index_path, top_index)
        if has_uncommitted_changes():
            git("add", str(top_index_path.relative_to(ROOT)))
            git("commit", "-m", f"chore: mark task {task_dir} completed")


if __name__ == "__main__":
    main()
