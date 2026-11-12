#!/bin/zsh
# Joga a cripta no automático (sem janela, acelerado) e resume cada partida.
# Uso: ferramentas/rodar-partidas.sh <rotulo> [n_sementes]   (padrão: 6 sementes)
# Requer o comando `godot` (4.7) no PATH. Os registros ficam em partidas/<rotulo>/.
R=${1:?informe um rótulo para a rodada}; N=${2:-6}
RAIZ=${0:A:h:h}
J=$RAIZ/jogo
O=$RAIZ/partidas/$R
mkdir -p $O
for s in $(seq 1 $N); do
  godot --headless --path $J -- --autoplay --tempo=6 --seed=$s --log=$O/seed$s.log > $O/seed$s.out 2>&1
done
for s in $(seq 1 $N); do echo "== seed $s"; grep -E "limpa|vitoria|derrota|RESULTADO" $O/seed$s.log; done
