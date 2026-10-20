"""Fixed entrypoint for the trusted evidence image; not application code."""
import os
import sys

# Python runs with -I: no PYTHONPATH, user site, working-directory imports or
# caller-selected module. This one root-owned image directory is authoritative.
sys.path.insert(0, "/opt/joyride-evidence/source")


def main():
    # Do not inherit caller-selected executables, proxies, CA overrides, plugin
    # settings or credentials in environment variables. Only the independently
    # mounted read-only credential paths are recognized by this image.
    os.environ.clear()
    os.environ.update({
        "PATH": "/opt/joyride-evidence/venv/bin:/usr/sbin:/usr/bin:/sbin:/bin",
        "HOME": "/scratch", "TMPDIR": "/scratch", "LANG": "C.UTF-8",
        "GLAB_CONFIG_DIR": "/credentials/gitlab", "KUBECONFIG": "/credentials/kubeconfig",
        "PYTHONDONTWRITEBYTECODE": "1",
    })
    if len(sys.argv) < 2 or sys.argv[1] not in ("collect", "key"):
        raise ValueError("unsupported_evidence_operation")
    operation = sys.argv.pop(1)
    if operation == "collect":
        from installed_test_producer import main as run
    else:
        from evidence_key import main as run
    run()


if __name__ == "__main__":
    try:
        main()
    except Exception:
        print("Evidence operation failed; no acceptance claimed", file=sys.stderr)
        sys.exit(1)
