#!/bin/zsh
# Abre a Cripta de Cinzas (duplo clique no Finder). Requer o Godot 4.7 em /Applications.
cd "$(dirname "$0")"
/Applications/Godot.app/Contents/MacOS/Godot --path . "$@"
