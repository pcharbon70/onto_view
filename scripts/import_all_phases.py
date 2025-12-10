#!/usr/bin/env python3
import csv
import subprocess
import shlex
import sys
from pathlib import Path

# 👉 EDIT THIS to your "<owner>/<repo>" value
REPO = "pcharbon70/onto_view"

# CSV files and their target milestones
PHASE_FILES = [
    ("phase-1-issues.csv", "Phase 1 – Ontology Ingestion & Canonical Model"),
    ("phase-2-issues.csv", "Phase 2 – LiveView Textual Documentation UI"),
    ("phase-3-issues.csv", "Phase 3 – Interactive Graph Visualization"),
    ("phase-4-issues.csv", "Phase 4 – UX, Property Docs & Accessibility"),
    ("phase-5-issues.csv", "Phase 5 – Export, CI/CD & Deployment"),
]


def main():
    if REPO == "your-user/your-repo":
        print("❌ Please edit REPO in import_all_phases.py before running.")
        sys.exit(1)

    dry_run = "--dry-run" in sys.argv

    for csv_path, milestone in PHASE_FILES:
        path = Path(csv_path)
        if not path.is_file():
            print(f"⚠️  Skipping {csv_path}: file not found.")
            continue

        print(f"\n=== Importing {csv_path} -> milestone '{milestone}' ===")

        with path.open(newline="", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            for row in reader:
                title = (row.get("title") or "").strip()
                body = row.get("body") or ""
                labels_raw = (row.get("labels") or "").strip()

                # Split labels on comma
                labels = [l.strip() for l in labels_raw.split(",") if l.strip()]

                if not title:
                    print("⚠️  Skipping row with empty title.")
                    continue

                cmd = [
                    "gh",
                    "issue",
                    "create",
                    "--repo",
                    REPO,
                    "--title",
                    title,
                    "--body",
                    body,
                    "--milestone",
                    milestone,
                ]

                for label in labels:
                    cmd.extend(["--label", label])

                print("$ " + " ".join(shlex.quote(c) for c in cmd))

                if not dry_run:
                    subprocess.run(cmd, check=True)

    print("\n✅ Done importing issues.")


if __name__ == "__main__":
    main()

