"""
tidy_notebooks.py
---------------------------------------------------------
노트북(.ipynb)을 일관된 형식으로 정리한다. 하루에 몇 개씩만 처리해서
매일 자동 커밋에 조금씩 올라가도록 만든 도구다.

    python tools/tidy_notebooks.py               # 다음 3개 정리
    python tools/tidy_notebooks.py --count 5     # 개수 지정
    python tools/tidy_notebooks.py --dry-run     # 무엇이 바뀔지 보기만
    python tools/tidy_notebooks.py --status      # 진행 현황
    python tools/tidy_notebooks.py --reset       # 진행 기록 초기화

무엇을 하는가 (출력은 절대 건드리지 않는다)
    1. nbformat 을 4.5 로 통일
    2. kernelspec 을 python3 로 통일
    3. language_info 를 하나의 형태로 통일
    4. 셀 id 가 없으면 부여 (nbformat 4.5 필수)
    5. 맨 끝에 붙은 빈 셀 제거
    6. 코드/마크다운 줄 끝의 불필요한 공백 제거
    7. 셀 안에 3줄 이상 이어진 빈 줄을 2줄로
    8. 내용이 없는(0바이트) 노트북을 열리는 빈 노트북으로 복구

무엇을 하지 않는가
    - 저장된 출력(그래프, 표, print 결과)을 지우지 않는다
    - execution_count 를 초기화하지 않는다
    - 코드나 주석의 내용을 고쳐 쓰지 않는다
"""

import argparse
import io
import json
import os
import re
import sys

try:
    import nbformat
    from nbformat.v4 import new_notebook, new_code_cell
except ImportError:
    sys.exit("nbformat 이 필요합니다:  python -m pip install nbformat")


REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STATE_FILE = os.path.join(REPO, "tools", "tidy-state.json")

KERNELSPEC = {"display_name": "Python 3", "language": "python", "name": "python3"}
LANGUAGE_INFO = {
    "codemirror_mode": {"name": "ipython", "version": 3},
    "file_extension": ".py",
    "mimetype": "text/x-python",
    "name": "python",
    "nbconvert_exporter": "python",
    "pygments_lexer": "ipython3",
    "version": "3.11.9",
}


# --- 처리 순서 -------------------------------------------------------------
# 수업을 들은 순서대로 정리한다. 앞에서부터 차근차근 쌓이는 편이 보기 좋다.
def sort_key(rel):
    """수업 순서 → 폴더 → 파일 안의 숫자 순."""
    lower = rel.lower()

    if "/" not in rel:                       # 루트 (파이썬 기초 + 개인 노트)
        group = 0 if re.match(r"^\d{6} ", rel) else 6
    elif lower.startswith("data anal"):
        group = 2 if "project file" in lower else 1
    elif lower.startswith("lab 10."):
        group = 3
    elif lower.startswith("lab 11."):
        group = 4
    else:
        group = 5

    # 파일 이름 안의 숫자를 숫자로 비교해야 LAB 2 가 LAB 10 앞에 온다
    nums = tuple(int(n) for n in re.findall(r"\d+", rel)[:4])
    return (group, os.path.dirname(rel), nums, rel)


def list_notebooks():
    found = []
    for dp, dn, fn in os.walk(REPO):
        if ".git" in dp:
            continue
        for f in fn:
            if f.endswith(".ipynb"):
                rel = os.path.relpath(os.path.join(dp, f), REPO).replace(os.sep, "/")
                found.append(rel)
    return sorted(found, key=sort_key)


def load_state():
    if os.path.exists(STATE_FILE):
        try:
            return json.load(io.open(STATE_FILE, encoding="utf-8"))
        except Exception:
            pass
    return {"done": []}


def save_state(state):
    state["done"] = sorted(set(state["done"]))
    with io.open(STATE_FILE, "w", encoding="utf-8") as f:
        json.dump(state, f, ensure_ascii=False, indent=2)
        f.write("\n")


# --- 정리 본체 -------------------------------------------------------------
def clean_source(src):
    """줄 끝 공백 제거 + 빈 줄 3개 이상은 2개로 + 끝의 빈 줄 정리."""
    lines = [ln.rstrip() for ln in src.split("\n")]

    out, blanks = [], 0
    for ln in lines:
        if ln == "":
            blanks += 1
            if blanks > 2:
                continue
        else:
            blanks = 0
        out.append(ln)

    while out and out[-1] == "":
        out.pop()
    return "\n".join(out)


def tidy(rel, dry_run=False):
    """노트북 하나를 정리한다. 무엇을 바꿨는지 목록으로 돌려준다."""
    path = os.path.join(REPO, rel)
    changes = []

    raw = io.open(path, encoding="utf-8", newline="").read()

    # 0바이트 / 내용 없는 파일 → 열리는 빈 노트북으로 복구
    if not raw.strip():
        nb = new_notebook(cells=[new_code_cell("")])
        changes.append("빈 파일을 열리는 노트북으로 복구")
    else:
        nb = nbformat.reads(raw, as_version=4)

    # 1) nbformat 버전
    if (nb.get("nbformat"), nb.get("nbformat_minor")) != (4, 5):
        changes.append("nbformat %s.%s → 4.5" % (nb.get("nbformat"), nb.get("nbformat_minor")))
        nb["nbformat"], nb["nbformat_minor"] = 4, 5

    md = nb.setdefault("metadata", {})

    # 2) kernelspec
    if md.get("kernelspec") != KERNELSPEC:
        changes.append("kernelspec 통일")
        md["kernelspec"] = dict(KERNELSPEC)

    # 3) language_info
    old_ver = md.get("language_info", {}).get("version")
    if md.get("language_info") != LANGUAGE_INFO:
        changes.append("language_info 통일 (%s → %s)" % (old_ver or "없음", LANGUAGE_INFO["version"]))
        md["language_info"] = dict(LANGUAGE_INFO)

    # 4) 맨 끝 빈 셀 제거
    removed = 0
    while len(nb.cells) > 1 and not "".join(nb.cells[-1].get("source", "")).strip():
        nb.cells.pop()
        removed += 1
    if removed:
        changes.append("맨 끝 빈 셀 %d개 제거" % removed)

    # 5) 셀 id + 6,7) 소스 공백 정리
    id_added, src_cleaned = 0, 0
    for i, c in enumerate(nb.cells):
        if not c.get("id"):
            c["id"] = "cell-%04d" % i
            id_added += 1

        src = c.get("source", "")
        if isinstance(src, list):
            src = "".join(src)
        new_src = clean_source(src)
        if new_src != src:
            c["source"] = new_src
            src_cleaned += 1

    if id_added:
        changes.append("셀 id %d개 부여" % id_added)
    if src_cleaned:
        changes.append("셀 %d개 공백 정리" % src_cleaned)

    if changes and not dry_run:
        with io.open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(nbformat.writes(nb))
            f.write("\n")

    return changes


def main():
    ap = argparse.ArgumentParser(description="노트북을 일관된 형식으로 조금씩 정리한다")
    ap.add_argument("--count", type=int, default=3, help="한 번에 처리할 노트북 수 (기본 3)")
    ap.add_argument("--dry-run", action="store_true", help="파일을 바꾸지 않고 보여만 준다")
    ap.add_argument("--status", action="store_true", help="진행 현황만 출력")
    ap.add_argument("--reset", action="store_true", help="진행 기록 초기화")
    args = ap.parse_args()

    if args.reset:
        save_state({"done": []})
        print("진행 기록을 초기화했습니다.")
        return

    all_nb = list_notebooks()
    state = load_state()
    done = set(state["done"])
    todo = [r for r in all_nb if r not in done]

    if args.status:
        print("전체 %d개 중 %d개 정리 완료, %d개 남음" % (len(all_nb), len(all_nb) - len(todo), len(todo)))
        for r in todo[:10]:
            print("  다음:", r)
        return

    if not todo:
        print("정리할 노트북이 없습니다. 전체 %d개 모두 완료." % len(all_nb))
        return

    batch = todo[: args.count]
    print("노트북 정리 %d개 (남은 %d개)%s" % (len(batch), len(todo), "  [미리보기]" if args.dry_run else ""))

    touched = 0
    for rel in batch:
        try:
            changes = tidy(rel, dry_run=args.dry_run)
        except Exception as e:
            print("  [실패] %s -> %s" % (rel, e))
            continue

        if changes:
            touched += 1
            print("  [정리] %s" % rel)
            for c in changes:
                print("         - %s" % c)
        else:
            print("  [유지] %s (이미 정상)" % rel)

        if not args.dry_run:
            state["done"].append(rel)

    if not args.dry_run:
        save_state(state)

    print("바뀐 파일 %d개 / 남은 노트북 %d개" % (touched, len(todo) - len(batch)))


if __name__ == "__main__":
    main()
