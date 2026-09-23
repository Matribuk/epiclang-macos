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

# Choisit UN SEUL fichier de configuration, jamais deux : sur macOS un
# .bash_profile source presque toujours .bashrc, ecrire dans les deux
# dupliquerait la ligne.
pick_rc_file() {
    case "${SHELL:-/bin/zsh}" in
        *zsh)
            printf '%s\n' "$HOME/.zshrc"
            ;;
        *bash)
            if [ -f "$HOME/.bash_profile" ]; then
                printf '%s\n' "$HOME/.bash_profile"
            elif [ -f "$HOME/.bashrc" ]; then
                printf '%s\n' "$HOME/.bashrc"
            else
                printf '%s\n' "$HOME/.bash_profile"
            fi
            ;;
        *)
            printf '%s\n' "$HOME/.profile"
            ;;
    esac
}

manual_path_hint() {
    info "Ajoute toi-meme cette ligne a ton fichier de configuration :"
    info "    $PATH_LINE"
}

install_commands() {
    step "Commandes epiclang et epibox"
    mkdir -p "$INSTALL_DIR"
    install -m 0755 "$REPO_DIR/bin/epiclang" "$INSTALL_DIR/epiclang"
    install -m 0755 "$REPO_DIR/bin/epibox"   "$INSTALL_DIR/epibox"
    ok "installees dans $INSTALL_DIR"

    PATH_MARKER="# epiclang-macos"
    PATH_LINE="export PATH=\"$INSTALL_DIR:\$PATH\""

    # Cas le plus frequent : rien a faire, aucun fichier n'est ouvert.
    case ":${PATH:-}:" in
        *":$INSTALL_DIR:"*)
            ok "$INSTALL_DIR est deja dans le PATH"
            info "aucun fichier de configuration n'a ete modifie"
            return
            ;;
    esac

    if [ "${EPICLANG_NO_RC:-0}" = "1" ]; then
        info "EPICLANG_NO_RC=1 : aucun fichier de configuration modifie."
        manual_path_hint
        NEEDS_NEW_SHELL=1
        return
    fi

    local rc
    rc="$(pick_rc_file)"

    # Ligne deja presente : on ne reecrit rien.
    if [ -f "$rc" ] && grep -Fq "$PATH_LINE" "$rc"; then
        ok "$rc contient deja la ligne, laisse intact"
        NEEDS_NEW_SHELL=1
        return
    fi

    if [ -L "$rc" ]; then
        info "$rc est un lien symbolique vers $(readlink "$rc")"
        info "(dotfiles geres : pense a reporter la ligne dans ton depot)"
    fi

    # Sauvegarde horodatee avant la moindre ecriture.
    if [ -f "$rc" ]; then
        local backup
        backup="$rc.epiclang-backup-$(date +%Y%m%d-%H%M%S)"
        cp -p "$rc" "$backup" || die "impossible de sauvegarder $rc, rien n'a ete modifie"
        info "Sauvegarde : $backup"
    fi

    # Ajout en fin de fichier seulement, precede d'une ligne vide :
    # rien de ce qui existe n'est modifie, deplace ni reordonne.
    if printf '\n%s\n%s\n' "$PATH_MARKER" "$PATH_LINE" >> "$rc" 2>/dev/null; then
        ok "deux lignes ajoutees a la fin de $rc"
        info "Pour revenir en arriere : supprime ces deux lignes, ou restaure la sauvegarde."
    else
        info "Ecriture impossible dans $rc (fichier protege ?). Rien n'a ete modifie."
        manual_path_hint
    fi
    NEEDS_NEW_SHELL=1
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
