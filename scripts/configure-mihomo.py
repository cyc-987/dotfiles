#!/usr/bin/env python3
"""Render the synced template with a machine-local subscription URL (stdlib only)."""
import argparse
import datetime
import json
import os
from pathlib import Path
import shutil
import tempfile
from urllib.parse import urlsplit

TOKEN = "__MIHOMO_SUBSCRIPTION_URL__"
USERSPACE_NODE = """- name: Tailscale
  type: socks5
  server: 127.0.0.1
  port: 1055
  udp: true"""
NATIVE_NODE = """- name: Tailscale
  type: direct
  udp: true"""


def main():
    root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", choices=("userspace", "native"), default="userspace")
    parser.add_argument("--subscription-file", type=Path, default=Path.home() / ".config/mihomo/subscription.url")
    parser.add_argument("--output", type=Path, default=Path.home() / ".config/mihomo/config.yaml")
    args = parser.parse_args()
    try:
        subscription = args.subscription_file.expanduser().read_text().strip()
    except OSError as error:
        parser.error(f"Cannot read local subscription file: {error}")
    try:
        parsed = urlsplit(subscription)
    except ValueError:
        parser.error("Subscription file must contain a valid HTTP(S) URL.")
    if "\n" in subscription or "\r" in subscription or parsed.scheme not in ("http", "https") or not parsed.netloc:
        parser.error("Subscription file must contain one HTTP(S) URL.")
    template = (root / "mihomo/.config/mihomo/config.yaml.template").read_text()
    if template.count(TOKEN) != 1 or template.count(USERSPACE_NODE) != 1:
        parser.error("Template must contain one subscription placeholder and one Tailscale node.")
    rendered = template.replace(TOKEN, json.dumps(subscription, ensure_ascii=False))
    if args.profile == "native":
        rendered = rendered.replace(USERSPACE_NODE, NATIVE_NODE)
    rendered = "# Generated from dotfiles; edit config.yaml.template and render again.\n" + rendered
    output = args.output.expanduser().absolute()
    if output.is_symlink():
        parser.error("Output is a symlink; use a separate local config file to keep credentials out of the repository.")
    try:
        output.resolve().relative_to(root)
    except ValueError:
        pass
    else:
        parser.error("Output resolves inside the dotfiles repository; keep generated configuration outside it (use Stow --no-folding).")
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        if output.read_text() == rendered:
            os.chmod(output, 0o600)
            print(f"Already current: {output} ({args.profile})")
            return
        stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
        backup = output.with_name(output.name + ".bak." + stamp)
        shutil.copy2(output, backup)
        os.chmod(backup, 0o600)
        print(f"Backup: {backup}")
    descriptor, name = tempfile.mkstemp(prefix=".mihomo-config-", dir=output.parent)
    temporary = Path(name)
    try:
        with os.fdopen(descriptor, "w") as stream:
            stream.write(rendered)
        os.replace(temporary, output)
    finally:
        temporary.unlink(missing_ok=True)
    print(f"Generated: {output} ({args.profile}); service was not reloaded.")


if __name__ == "__main__":
    main()
