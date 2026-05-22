#!/bin/bash
# Syncs repo files to system paths on the DGX Spark server.
# Run after pulling changes from the repo to make them active.
#
# Symlinked files (always in sync automatically):
#   ~/litellm_config.yaml  →  litellm/config.yaml
#   ~/start_qwen36.sh      →  sglang/start.sh
#
# Copied files (require manual deploy or sudo):
#   ~/searxng/docker-compose.yml
#   ~/searxng/config/settings.yml
#   ~/searxng/mcp_server.py
#   ~/open-webui/docker-compose.yml
#   ~/open-webui/sglang-proxy/proxy.py
#   /etc/systemd/system/litellm.service        (sudo)
#   /etc/systemd/system/mcp-searxng.service    (sudo)

set -e
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false
[[ "$1" == "--dry-run" ]] && DRY_RUN=true

run() {
    if $DRY_RUN; then echo "  [dry-run] $*"; else "$@"; fi
}

echo "=== HerzigGroup AI Stack – Server Sync ==="
echo "Repo: $REPO_DIR"
$DRY_RUN && echo "(Dry-run mode — keine Änderungen)"
echo ""

# ── 1. Symlinks (idempotent) ──────────────────────────────────────────────────
echo "── Symlinks ──"

setup_symlink() {
    local target="$1" link="$2"
    if [ -L "$link" ] && [ "$(readlink "$link")" = "$target" ]; then
        echo "  ✓ $link (bereits verknüpft)"
    else
        if [ -e "$link" ] && [ ! -L "$link" ]; then
            echo "  ! $link ist eine Kopie — ersetze durch Symlink"
            run rm "$link"
        fi
        run ln -sf "$target" "$link"
        echo "  → $link"
    fi
}

setup_symlink "$REPO_DIR/litellm/config.yaml"  "$HOME/litellm_config.yaml"
setup_symlink "$REPO_DIR/sglang/start.sh"      "$HOME/start_qwen36.sh"

# ── 2. Kopierte Dateien (prüfen, ggf. deployen) ───────────────────────────────
echo ""
echo "── Kopierte Dateien ──"

STALE=false

check_copy() {
    local src="$1" dst="$2"
    if [ ! -f "$dst" ]; then
        echo "  FEHLT  $dst"
        STALE=true
    elif ! diff -q "$src" "$dst" > /dev/null 2>&1; then
        echo "  VERALTET  $dst"
        STALE=true
        if [[ "$3" == "--deploy" ]]; then
            run cp "$src" "$dst"
            echo "    → kopiert"
        fi
    else
        echo "  ✓ $dst"
    fi
}

DEPLOY_FLAG=""
[[ "$1" == "--deploy" || "$2" == "--deploy" ]] && DEPLOY_FLAG="--deploy"

check_copy "$REPO_DIR/searxng/docker-compose.yml"       "$HOME/searxng/docker-compose.yml"     $DEPLOY_FLAG
check_copy "$REPO_DIR/searxng/config/settings.yml"      "$HOME/searxng/config/settings.yml"    $DEPLOY_FLAG
check_copy "$REPO_DIR/searxng/mcp_server.py"            "$HOME/searxng/mcp_server.py"          $DEPLOY_FLAG
check_copy "$REPO_DIR/open-webui/docker-compose.yml"    "$HOME/open-webui/docker-compose.yml"  $DEPLOY_FLAG
check_copy "$REPO_DIR/open-webui/sglang-proxy/proxy.py" "$HOME/open-webui/sglang-proxy/proxy.py" $DEPLOY_FLAG

# ── 3. systemd-Dienste (nur prüfen, sudo nötig zum Deployen) ─────────────────
echo ""
echo "── systemd-Dienste (sudo erforderlich zum Deployen) ──"

check_service() {
    local src="$1" dst="$2"
    # Strip comments and blank lines before comparing (repo files have install instructions)
    if ! diff -q <(grep -v "^#" "$src" | grep -v "^$") <(grep -v "^#" "$dst" | grep -v "^$") > /dev/null 2>&1; then
        echo "  VERALTET  $dst"
        echo "    Manuell deployen: sudo cp $src $dst && sudo systemctl daemon-reload"
        STALE=true
    else
        echo "  ✓ $dst"
    fi
}

check_service "$REPO_DIR/litellm/litellm.service"         "/etc/systemd/system/litellm.service"
check_service "$REPO_DIR/searxng/mcp-searxng.service"     "/etc/systemd/system/mcp-searxng.service"

# ── Ergebnis ──────────────────────────────────────────────────────────────────
echo ""
if $STALE && [[ -z "$DEPLOY_FLAG" ]]; then
    echo "Veraltete Dateien gefunden. Zum Deployen ausführen:"
    echo "  bash sync-server.sh --deploy"
elif ! $STALE; then
    echo "Alles auf dem aktuellen Stand."
fi
echo ""
echo "Hinweis: Nach Änderungen an litellm/config.yaml → sudo systemctl restart litellm"
echo "         Nach Änderungen an sglang/start.sh     → docker stop qwen36 && docker rm qwen36 && ~/start_qwen36.sh"
