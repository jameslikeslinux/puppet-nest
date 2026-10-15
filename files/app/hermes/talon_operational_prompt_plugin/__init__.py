"""Freeze Talon's public operational guidance into new session prompts."""

from pathlib import Path

from hermes_constants import get_hermes_home
from hermes_cli.profiles import get_active_profile_name


SECTION_ID = "talon.readable-prose"
MAX_CHARS = 2048


def register(ctx) -> None:
    # HERMES_PROFILE alone can be inherited from another process. Resolve the
    # actual profile home, and accept only its own profile-local plugin copy.
    home = get_hermes_home().resolve()
    plugin_dir = Path(__file__).resolve().parent
    if get_active_profile_name() != "talon" or plugin_dir.parent != home / "plugins":
        return

    # Read once at plugin registration, never on a tool call or prompt turn.
    # Missing/invalid assets raise: core reports a plugin load failure and
    # rolls back registrations rather than quietly installing partial guidance.
    content = (plugin_dir / "readable-prose.md").read_text(encoding="utf-8").strip()
    if not content or len(content) > MAX_CHARS:
        raise ValueError("Talon readable-prose asset is empty or exceeds its prompt budget")
    ctx.register_system_prompt_section(
        SECTION_ID, content, position="after_memory", max_chars=MAX_CHARS,
    )
