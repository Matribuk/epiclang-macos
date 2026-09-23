# epiclang sur macOS

`epiclang` est le compilateur des projets C d'Epitech : Clang 21 plus le plug-in
de coding style **banana**. Il n'existe qu'en paquet Linux.

Ce dépôt l'installe sur macOS en une commande. Tu obtiens ensuite les commandes
`epiclang` et `epibox`, utilisables comme sur une machine Epitech.

## Installation

```sh
git clone https://github.com/<ton-org>/epiclang-macos.git
cd epiclang-macos
./install.sh
```

Le script installe ce qui manque et ignore ce qui est déjà là : Homebrew, Docker
Desktop, l'image Epitech, puis les commandes. Compter 5 à 10 minutes la première
fois. Le relancer plus tard est sans danger.

```
==> Verification du systeme
    OK macOS 26.5.2 sur arm64
==> Homebrew
    OK Homebrew 6.0.22
==> Docker
    OK le demon Docker repond deja
==> Image Epitech (Ubuntu 26.04 + epiclang + coding style banana)
    Construction : 2 a 3 minutes et environ 280 Mo la premiere fois.
    ... (sortie de docker build)
    OK image epiclang:local construite
==> Commandes epiclang et epibox
    OK installees dans /Users/toi/.local/bin
==> Verification
    OK Ubuntu clang version 21.1.8 (6ubuntu1)
    OK le plug-in de coding style repond

Termine. epiclang est pret.
```

Si le script s'arrête en demandant d'accepter les conditions de Docker Desktop :
ouvre l'application, accepte, puis relance `./install.sh`.

### Ce que le script écrit sur ta machine

Deux exécutables dans `~/.local/bin`, une image Docker, et rien d'autre — aucun
`sudo`, sauf si Homebrew ou Docker doivent être installés.

`~/.local/bin` doit être dans ton `PATH`. S'il y est déjà, **aucun fichier de
configuration n'est ouvert**. Sinon le script ajoute deux lignes à la fin d'un
**seul** fichier, celui de ton shell, dans la syntaxe de ce shell, et après en
avoir fait une copie horodatée :

| Shell | Fichier | Ligne ajoutée |
| --- | --- | --- |
| zsh | `~/.zshrc` | `export PATH="$HOME/.local/bin:$PATH"` |
| bash | `~/.bash_profile`, sinon `~/.bashrc` | `export PATH="$HOME/.local/bin:$PATH"` |
| fish | `~/.config/fish/config.fish` | `fish_add_path ~/.local/bin` |
| tcsh | `~/.tcshrc`, sinon `~/.cshrc` | `setenv PATH "$HOME/.local/bin:$PATH"` |
| csh | `~/.cshrc` | `setenv PATH "$HOME/.local/bin:$PATH"` |
| ksh, dash, sh | `~/.profile` | `export PATH="$HOME/.local/bin:$PATH"` |
| autre | aucun | le script affiche quoi ajouter, et ne touche à rien |

En bash, un seul des deux fichiers est visé : `.bash_profile` source presque
toujours `.bashrc`, écrire dans les deux doublerait la ligne.

Rien d'existant n'est modifié ni réordonné, et relancer le script n'ajoute pas
la ligne une seconde fois. Pour t'en charger toi-même :

```sh
EPICLANG_NO_RC=1 ./install.sh
```

Autre emplacement d'installation : `EPICLANG_PREFIX=/un/autre/dossier ./install.sh`.

## Utilisation

### Un fichier propre

`examples/hello.c` respecte la coding style :

```c
/*
** EPITECH PROJECT, 2026
** epiclang-macos
** File description:
** Exemple conforme a la coding style Epitech
*/

#include <stdio.h>

int print_message(char const *message)
{
    printf("%s\n", message);
    return 0;
}

int main(void)
{
    return print_message("Hello Epitech");
}
```

```sh
cd examples
epiclang -Wall -Wextra hello.c -o hello
```

Aucune sortie : rien à signaler.

Le binaire produit est un exécutable **Linux**. `epibox` le lance :

```sh
epibox ./hello
```

```
Hello Epitech
```

### Un fichier hors style

`examples/style_error.c` :

```c
#include <stdio.h>

int PrintMessage(char *msg){printf("%s\n", msg); return 0;}

int main(void)
{
    return PrintMessage("Hello Epitech");
}
```

```sh
epiclang -Wall -Wextra style_error.c -o style_error
```

```
style_error.c:1:1: warning: [Banana] [Minor] file not starting with standard Epitech header (C-G1)
    1 | #include <stdio.h>
      | ^
style_error.c:3:5: warning: [Banana] [Minor] non-snake-case function name (C-F2)
    3 | int PrintMessage(char *msg){printf("%s\n", msg); return 0;}
      |     ^
style_error.c:3:50: warning: [Banana] [Major] multiple statements on the same line (C-L1)
    3 | int PrintMessage(char *msg){printf("%s\n", msg); return 0;}
      |                                                  ^
style_error.c:3:28: warning: [Banana] [Minor] function body opening brace on same line as prototype (C-L4)
    3 | int PrintMessage(char *msg){printf("%s\n", msg); return 0;}
      |                            ^
7 warnings generated.
```

Chaque avertissement donne sa règle : `C-G1`, `C-F2`, `C-L1`, `C-L4`.

## Dans tes projets

`epiclang` remplace `clang`, avec ou sans Makefile.

```sh
epiclang -Wall -Wextra -Iinclude *.c -o prog -lm   # compilation + edition de liens
epiclang -Wall -Wextra -c main.c -o main.o         # compilation seule
epiclang main.o util.o -o prog -lm                 # edition de liens seule
```

Dans un Makefile, une seule ligne change :

```make
CC = epiclang
```

Le code de retour est fidèle : `0` si ça compile, `1` sur erreur. Les globs, les
`-I`, les `-l` et les chemins relatifs fonctionnent normalement.

## Les deux commandes

| Commande | Rôle |
| --- | --- |
| `epiclang [options] fichiers` | Compile, exactement comme `clang` |
| `epibox ./prog` | Exécute un binaire produit par `epiclang` |
| `epibox` | Ouvre un shell Linux dans le dossier courant |
| `epibox banana-check-repo .` | Vérifie les fichiers de rendu |

## Pourquoi Docker

Le plug-in banana est un binaire Linux x86-64 : il ne se charge pas dans un
Clang natif macOS. La compilation a donc lieu dans un conteneur Ubuntu 26.04,
et le dossier courant y est monté au même chemin, ce qui garde les chemins
relatifs et les messages d'erreur exacts.

Conséquence : les binaires produits sont des exécutables Linux, d'où `epibox`.
C'est aussi la plateforme sur laquelle tes projets seront corrigés.

## Dépannage

| Symptôme | Correctif |
| --- | --- |
| `epiclang: command not found` | Ouvre un nouveau terminal, ou relance `./install.sh` |
| `Docker n'est pas demarre` | Lance Docker Desktop, attends qu'il soit prêt |
| `exec format error: ./prog` | Binaire Linux : utilise `epibox ./prog` |
| `no such file or directory` sur un fichier du projet | Il est hors du dossier courant : compile depuis le dossier parent commun |
| Aucun avertissement `[Banana]` | `EPICLANG_REBUILD=1 ./install.sh` |
| Compilation lente sur puce Apple | Docker Desktop → Settings → General → Use Rosetta |

## Désinstallation

```sh
rm ~/.local/bin/epiclang ~/.local/bin/epibox
docker image rm epiclang:local
```

Si le script avait complété ton `PATH`, supprime aussi les deux lignes marquées
`# epiclang-macos` à la fin du fichier de configuration de ton shell.

## Mise à jour

La PPA Epitech est mise à jour régulièrement. Pour récupérer les dernières
versions d'`epiclang` et du plug-in :

```sh
git pull
EPICLANG_REBUILD=1 ./install.sh
```
