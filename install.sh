#!/usr/bin/env bash
#
# Installe epiclang sur macOS : Homebrew, Docker, l'image Epitech,
# puis les commandes epiclang et epibox.
# Relancer le script est sans danger : chaque etape est ignoree si deja faite.

set -euo pipefail

IMAGE_NAME="${EPICLANG_IMAGE:-epiclang:local}"
INSTALL_DIR="${EPICLANG_PREFIX:-$HOME/.local/bin}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

step() { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
ok()   { printf '    \033[32mOK\033[0m %s\n' "$*"; }
die()  { printf '\n\033[1;31mEchec :\033[0m %s\n' "$*" >&2; exit 1; }

# --- 1. macOS -----------------------------------------------------------
require_macos() {
    step "Verification du systeme"
    [ "$(uname -s)" = "Darwin" ] || die "Ce script est prevu pour macOS."
    ok "macOS $(sw_vers -productVersion) sur $(uname -m)"
}

# --- 2. Homebrew --------------------------------------------------------
ensure_homebrew() {
    step "Homebrew"
    if ! command -v brew >/dev/null 2>&1; then
        info "Installation de Homebrew (mot de passe administrateur demande)..."
        NONINTERACTIVE=1 /bin/bash -c \
            "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        [ -x "$brew_bin" ] && eval "$("$brew_bin" shellenv)" && break
    done
    command -v brew >/dev/null 2>&1 || die "Homebrew reste introuvable apres installation."
    ok "Homebrew $(brew --version | head -n1 | awk '{print $2}')"
}

# --- 3. Docker ----------------------------------------------------------
ensure_docker() {
    step "Docker"
    if docker info >/dev/null 2>&1; then
        ok "le demon Docker repond deja"
        return
    fi

    if ! command -v docker >/dev/null 2>&1 && [ ! -d /Applications/Docker.app ]; then
        info "Installation de Docker Desktop via Homebrew (quelques minutes)..."
        brew install --cask docker
    fi

    if [ -d /Applications/Docker.app ]; then
        info "Demarrage de Docker Desktop..."
        open -a Docker || true
        info "Au premier lancement, accepte les conditions dans la fenetre qui s'ouvre."
    fi

    info "Attente du demon Docker (3 minutes maximum)..."
    for _ in $(seq 1 180); do
        docker info >/dev/null 2>&1 && break
        sleep 1
    done
    docker info >/dev/null 2>&1 \
        || die "Docker ne repond pas. Ouvre Docker Desktop, accepte les conditions, puis relance ./install.sh"
    ok "le demon Docker repond"

    if [ "$(uname -m)" = "arm64" ]; then
        info "Conseil : Docker Desktop > Settings > General > Use Rosetta"
        info "accelere nettement la compilation sur puce Apple."
    fi
}

# --- 4. Image -----------------------------------------------------------
build_image() {
    step "Image Epitech (Ubuntu 26.04 + epiclang + coding style banana)"
    if docker image inspect "$IMAGE_NAME" >/dev/null 2>&1 && [ "${EPICLANG_REBUILD:-0}" != "1" ]; then
        ok "image $IMAGE_NAME deja presente (EPICLANG_REBUILD=1 pour la reconstruire)"
        return
    fi
    info "Construction : 2 a 3 minutes et environ 280 Mo la premiere fois."
    docker build --platform linux/amd64 -t "$IMAGE_NAME" "$REPO_DIR"
    ok "image $IMAGE_NAME construite"
}

# --- 5. Commandes -------------------------------------------------------
install_commands() {
    step "Commandes epiclang et epibox"
    mkdir -p "$INSTALL_DIR"
    install -m 0755 "$REPO_DIR/bin/epiclang" "$INSTALL_DIR/epiclang"
    install -m 0755 "$REPO_DIR/bin/epibox"   "$INSTALL_DIR/epibox"
    ok "installees dans $INSTALL_DIR"

    case ":$PATH:" in
        *":$INSTALL_DIR:"*)
            ok "$INSTALL_DIR est deja dans le PATH"
            ;;
        *)
            local rc
            case "${SHELL:-/bin/zsh}" in
                *zsh)  rc="$HOME/.zshrc" ;;
                *bash) rc="$HOME/.bash_profile" ;;
                *)     rc="$HOME/.profile" ;;
            esac
            if ! grep -qs "$INSTALL_DIR" "$rc"; then
                printf '\n# ajoute par epiclang-macos\nexport PATH="%s:$PATH"\n' "$INSTALL_DIR" >> "$rc"
                ok "PATH complete dans $rc"
            fi
            info "Ouvre un nouveau terminal, ou lance : export PATH=\"$INSTALL_DIR:\$PATH\""
            NEEDS_NEW_SHELL=1
            ;;
    esac
}

# --- 6. Verification ----------------------------------------------------
verify() {
    step "Verification"
    local version
    version="$("$INSTALL_DIR/epiclang" --version | head -n1)"
    case "$version" in
        *"clang version 21"*) ok "$version" ;;
        *) die "version inattendue : $version" ;;
    esac

    local out
    out="$(cd "$REPO_DIR/examples" && "$INSTALL_DIR/epiclang" -Wall -Wextra -c style_error.c -o /dev/null 2>&1 || true)"
    if printf '%s' "$out" | grep -q '\[Banana\]'; then
        ok "le plug-in de coding style repond"
    else
        die "le plug-in banana ne s'est pas declenche. Relance avec EPICLANG_REBUILD=1 ./install.sh"
    fi
}

main() {
    NEEDS_NEW_SHELL=0
    require_macos
    ensure_homebrew
    ensure_docker
    build_image
    install_commands
    verify

    printf '\n\033[1;32mTermine.\033[0m epiclang est pret.\n\n'
    if [ "$NEEDS_NEW_SHELL" = "1" ]; then
        printf '  Ouvre un nouveau terminal, puis :\n\n'
    else
        printf '  Pour essayer :\n\n'
    fi
    printf '    cd %s/examples\n' "$REPO_DIR"
    printf '    epiclang -Wall -Wextra hello.c -o hello\n'
    printf '    epibox ./hello\n\n'
}

main "$@"
