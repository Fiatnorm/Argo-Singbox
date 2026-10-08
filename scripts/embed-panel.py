"""Synchronize the standalone installer's embedded HTML with its source asset."""
import base64
from pathlib import Path

root = Path(__file__).resolve().parents[1]
script = root / "argo-singbox.sh"
text = script.read_text(encoding="utf-8")
marker = text.index("  template=\"$(base64 -d <<'HTML'\n")
start = text.index("\n", marker) + 1
end = text.index("HTML\n  )", start)
payload = base64.encodebytes((root / "assets/subscription-panel.html").read_bytes()).decode()
script.write_text(text[:start] + payload + text[end:], encoding="utf-8", newline="\n")
