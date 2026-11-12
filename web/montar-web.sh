#!/bin/zsh
# Monta o projeto Godot da versão de navegador: copia jogo/ e aplica web/sobreposicao/ por cima.
# Uso: web/montar-web.sh [pasta de destino]   (padrão: web/build/projeto)
set -e
RAIZ=${0:A:h:h}
DEST=${1:-$RAIZ/web/build/projeto}
mkdir -p "$DEST"
rsync -a --delete --exclude '.godot' --exclude 'jogar.command' "$RAIZ/jogo/" "$DEST/"
rsync -a "$RAIZ/web/sobreposicao/" "$DEST/"
echo "Projeto web montado em $DEST"
