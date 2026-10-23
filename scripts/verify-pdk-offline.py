#!/usr/bin/env python3
"""Exercise an exact PDK image against committed Nest inputs without networking."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("image")
    parser.add_argument("--repo", default=".")
    parser.add_argument("--output", required=True)
    parser.add_argument("--eyaml", default="/etc/eyaml")
    args = parser.parse_args()
    output = Path(args.output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    repo = Path(args.repo).resolve()
    name = f"pdk-offline-verify-{os.getpid()}"
    report = {"image": args.image, "network": "none", "results": []}

    def run(argv, label, expected=0, contains=None):
        result = subprocess.run(argv, capture_output=True, text=True, check=False)
        text = result.stdout + result.stderr
        (output / f"{label}.log").write_text(text)
        passed = result.returncode == expected if expected == 0 else result.returncode != 0
        if contains:
            passed = passed and contains in text
        report["results"].append({"test": label, "exit_code": result.returncode, "passed": passed})
        if not passed:
            raise RuntimeError(f"{label} failed; see {output / (label + '.log')}")
        return text

    def execute(command, label, **kwargs):
        return run(["podman", "exec", "-w", "/module", name, *command], label, **kwargs)

    try:
        report["source_sha"] = subprocess.check_output(["git", "-C", str(repo), "rev-parse", "HEAD"], text=True).strip()
        run(["podman", "create", "--name", name, "--network", "none", "-v", f"{args.eyaml}:/etc/eyaml:ro", "-e", "PUPPET_FORGE_TOKEN=offline-branch-selection", "--entrypoint", "/bin/sleep", args.image, "infinity"], "create")
        run(["podman", "start", name], "start")
        report["image_id"] = json.loads(subprocess.check_output(["podman", "inspect", name], text=True))[0]["Image"]
        archive = subprocess.run(["git", "-C", str(repo), "archive", "HEAD"], capture_output=True, check=True)
        subprocess.run(["podman", "cp", "-", f"{name}:/module"], input=archive.stdout, check=True)
        execute(["test", "!", "-e", "Gemfile.lock"], "initial-no-lock")
        for phase in ("first", "warm"):
            execute(["pdk", "validate"], f"{phase}-validate")
            if phase == "first":
                execute(["rm", "Gemfile.lock"], "unit-no-lock")
            execute(["pdk", "test", "unit", "--parallel"], f"{phase}-unit")
        execute(["ruby", "-e", "p='Gemfile'; File.write(p+'.saved',File.read(p)); File.open(p,'a'){|f|f.puts \"gem 'nest_missing_offline_dependency'\"}"], "change-requirement")
        execute(["pdk", "validate"], "changed-dependency", expected=1, contains="no online fallback was attempted")
        execute(["sh", "-c", "mv Gemfile.saved Gemfile && mv .fixtures.yml .fixtures.yml.saved && printf '\\n# changed\\n' > .fixtures.yml"], "change-fixture-input")
        execute(["pdk", "test", "unit", "--parallel"], "changed-fixtures", expected=1, contains="fixture requirements changed")
        execute(["sh", "-c", "mv .fixtures.yml.saved .fixtures.yml"], "restore-fixture-input")
        execute(["ruby", "-e", "p=Dir['/root/.pdk/cache/ruby/*/specifications/bolt-*.gemspec'].first; abort 'No Bolt specification' unless p; File.rename(p,p+'.missing')"], "remove-cached-bolt")
        execute(["pdk", "validate"], "missing-dependency", expected=1, contains="no online fallback was attempted")
        report["passed"] = True
    finally:
        report["checked_at"] = int(time.time())
        (output / "results.json").write_text(json.dumps(report, indent=2) + "\n")
        subprocess.run(["podman", "rm", "-f", "--time", "0", name], capture_output=True, check=False)
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
