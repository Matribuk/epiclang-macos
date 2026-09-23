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
    if [ "$(id -u)" -eq 0 ]; then
        die "Ne lance pas ce script avec sudo : il installe dans ton dossier
    personnel, et Homebrew refuse de s'installer en root.
    Relance simplement : ./install.sh"
    fi
    ok "macOS $(sw_vers -productVersion) sur $(uname -m)"
}

# Homebrew et Docker Desktop exigent un compte administrateur.
# Le reste du script n'en a pas besoin.
is_admin() {
    if dseditgroup -o checkmember -m "$(id -un)" admin 2>/dev/null | grep -q '^yes'; then
        return 0
    fi
    id -Gn 2>/dev/null | tr ' ' '\n' | grep -qx admin
}

# --- 2. Docker ----------------------------------------------------------
# Homebrew n'est sollicite que s'il faut reellement installer Docker.
# Sur une machine ou Docker Desktop est deja present, l'installation
# complete se fait sans aucun droit administrateur.
ensure_docker() {
    step "Docker"

    if docker info >/dev/null 2>&1; then
        ok "le demon Docker repond deja"
        rosetta_hint
        return
    fi

    if [ ! -d /Applications/Docker.app ] && ! command -v docker >/dev/null 2>&1; then
        install_docker
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
        || die "Docker ne repond pas. Ouvre Docker Desktop, accepte les conditions,
    puis relance ./install.sh"
    ok "le demon Docker repond"
    rosetta_hint
}

rosetta_hint() {
    [ "$(uname -m)" = "arm64" ] || return 0
    info "Conseil : Docker Desktop > Settings > General > Use Rosetta"
    info "accelere nettement la compilation sur puce Apple."
}

install_docker() {
    info "Docker n'est pas installe sur cette machine."
    if ! is_admin; then
        die "installer Docker Desktop demande un compte administrateur, et
    $(id -un) n'en est pas un.

    Fais installer Docker Desktop par un administrateur :
        https://www.docker.com/products/docker-desktop/
    ou, s'il a Homebrew :
        brew install --cask docker

    Ensuite, demarre Docker et relance ./install.sh :
    plus aucun droit administrateur ne sera necessaire."
    fi

    ensure_homebrew
    info "Installation de Docker Desktop via Homebrew (quelques minutes)..."
    brew install --cask docker
}

# --- 3. Homebrew --------------------------------------------------------
# Charge Homebrew s'il est installe mais absent du PATH, cas frequent
# quand le shell n'a jamais ete configure.
load_homebrew() {
    local brew_bin
    for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [ -x "$brew_bin" ]; then
            eval "$("$brew_bin" shellenv)"
            return
        fi
    done
}

ensure_homebrew() {
    command -v brew >/dev/null 2>&1 || load_homebrew

    if command -v brew >/dev/null 2>&1; then
        ok "Homebrew $(brew --version | head -n1 | awk '{print $2}')"
        return
    fi

    if ! is_admin; then
        die "installer Homebrew demande un compte administrateur, et
    $(id -un) n'en est pas un.
    Fais installer Homebrew par un administrateur (https://brew.sh),
    puis relance ./install.sh"
    fi

    info "Installation de Homebrew. Ton mot de passe administrateur va etre demande."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
        || die "l'installation de Homebrew a echoue. Installe-le a la main : https://brew.sh"

    load_homebrew
    command -v brew >/dev/null 2>&1 || die "Homebrew reste introuvable apres installation."
    ok "Homebrew $(brew --version | head -n1 | awk '{print $2}')"
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

# Chaque shell a son fichier ET sa syntaxe : une ligne "export PATH=..."
# ecrite dans une configuration fish ou tcsh casserait le shell au demarrage.
# RC_FILE vide = shell inconnu, on n'ecrit nulle part.
detect_shell_config() {
    SHELL_NAME="$(basename "${SHELL:-inconnu}")"
    RC_FILE=""
    PATH_LINE="export PATH=\"$INSTALL_DIR:\$PATH\""

    case "$SHELL_NAME" in
        zsh)
            RC_FILE="$HOME/.zshrc"
            ;;
        bash)
            # Un seul des deux : sur macOS .bash_profile source presque
            # toujours .bashrc, ecrire dans les deux doublerait la ligne.
            if [ -f "$HOME/.bash_profile" ]; then
                RC_FILE="$HOME/.bash_profile"
            elif [ -f "$HOME/.bashrc" ]; then
                RC_FILE="$HOME/.bashrc"
            else
                RC_FILE="$HOME/.bash_profile"
            fi
            ;;
        sh|dash|ksh|mksh)
            RC_FILE="$HOME/.profile"
            ;;
        fish)
            RC_FILE="$HOME/.config/fish/config.fish"
            PATH_LINE="fish_add_path $INSTALL_DIR"
            ;;
        tcsh)
            if [ -f "$HOME/.tcshrc" ]; then
                RC_FILE="$HOME/.tcshrc"
            elif [ -f "$HOME/.cshrc" ]; then
                RC_FILE="$HOME/.cshrc"
            else
                RC_FILE="$HOME/.tcshrc"
            fi
            PATH_LINE="setenv PATH \"$INSTALL_DIR:\$PATH\""
            ;;
        csh)
            RC_FILE="$HOME/.cshrc"
            PATH_LINE="setenv PATH \"$INSTALL_DIR:\$PATH\""
            ;;
    esac
}

manual_path_hint() {
    info "Ajoute toi-meme cette ligne a la configuration de ton shell :"
    info "    $PATH_LINE"
}

install_commands() {
    step "Commandes epiclang et epibox"
    mkdir -p "$INSTALL_DIR"
    install -m 0755 "$REPO_DIR/bin/epiclang" "$INSTALL_DIR/epiclang"
    install -m 0755 "$REPO_DIR/bin/epibox"   "$INSTALL_DIR/epibox"
    ok "installees dans $INSTALL_DIR"

    detect_shell_config

    # Cas le plus frequent : rien a faire, aucun fichier n'est ouvert.
    case ":${PATH:-}:" in
        *":$INSTALL_DIR:"*)
            ok "$INSTALL_DIR est deja dans le PATH"
            info "aucun fichier de configuration n'a ete modifie"
            return
            ;;
    esac

    NEEDS_NEW_SHELL=1

    if [ "${EPICLANG_NO_RC:-0}" = "1" ]; then
        info "EPICLANG_NO_RC=1 : aucun fichier de configuration modifie."
        manual_path_hint
        return
    fi

    if [ -z "$RC_FILE" ]; then
        info "Shell non reconnu ($SHELL_NAME) : aucun fichier modifie, par prudence."
        info "Ajoute $INSTALL_DIR au debut de ton PATH,"
        info "avec la syntaxe propre a $SHELL_NAME."
        return
    fi

    ok "shell detecte : $SHELL_NAME"

    # Ligne deja presente : on ne reecrit rien.
    if [ -f "$RC_FILE" ] && grep -Fq "$PATH_LINE" "$RC_FILE"; then
        ok "$RC_FILE contient deja la ligne, laisse intact"
        return
    fi

    if [ -L "$RC_FILE" ]; then
        info "$RC_FILE est un lien symbolique vers $(readlink "$RC_FILE")"
        info "(dotfiles geres : pense a reporter la ligne dans ton depot)"
    fi

    mkdir -p "$(dirname "$RC_FILE")"

    # Sauvegarde horodatee avant la moindre ecriture.
    if [ -f "$RC_FILE" ]; then
        local backup
        backup="$RC_FILE.epiclang-backup-$(date +%Y%m%d-%H%M%S)"
        cp -p "$RC_FILE" "$backup" || die "impossible de sauvegarder $RC_FILE, rien n'a ete modifie"
        info "Sauvegarde : $backup"
    fi

    # Ajout en fin de fichier seulement, precede d'une ligne vide :
    # rien de ce qui existe n'est modifie, deplace ni reordonne.
    if printf '\n# epiclang-macos\n%s\n' "$PATH_LINE" >> "$RC_FILE" 2>/dev/null; then
        ok "deux lignes ajoutees a la fin de $RC_FILE"
        info "    $PATH_LINE"
        info "Pour revenir en arriere : supprime ces deux lignes, ou restaure la sauvegarde."
    else
        info "Ecriture impossible dans $RC_FILE (fichier protege ?). Rien n'a ete modifie."
        manual_path_hint
    fi
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
