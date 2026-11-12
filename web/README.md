# Cripta de Cinzas para navegador

A versão publicada em https://viktorkav.com.br/cripta-de-cinzas/ é o mesmo jogo de `jogo/`, exportado pelo Godot 4.7.2 com o preset `Web` no renderer Compatibility (WebGL 2). O Godot 4.7 não exporta para WebGPU.

Esta pasta guarda só o que muda em relação ao projeto de `jogo/`:

| Item | Conteúdo |
|---|---|
| `sobreposicao/` | os arquivos que substituem os de `jogo/`: `project.godot` (renderer e limites da web), `export_presets.cfg`, 7 scripts ajustados para o Compatibility e os `.import` das texturas |
| `montar-web.sh` | copia `jogo/` e aplica a sobreposição por cima |
| `texturas-padrao/` | os `.import` do pacote padrão, com as texturas de cor menores |
| `index.template.html` | a página que carrega o jogo e deixa escolher o pacote |
| `licencas/` | os avisos de licença que acompanham o build (Godot, Cinzel e Spectral) |

## Como exportar

1. Monte o projeto web:

   ```sh
   web/montar-web.sh
   ```

   Ele fica em `web/build/projeto`.

2. Abra esse projeto no Godot 4.7 com os modelos de exportação Web instalados e exporte o preset `Web` como `index.html` numa pasta de build. Esse é o pacote de alta resolução.

3. Para o pacote padrão, copie o projeto montado para outra pasta e substitua `assets/models/*.jpg.import` pelos arquivos correspondentes de `texturas-padrao/`. Apague os `.ctex` desses modelos em `.godot/imported/` na cópia, reimporte os assets e exporte com o mesmo preset.

4. Sirva um único `index.js` e `index.wasm`, os dois pacotes `.pck`, os ícones e `licencas/`. Gere o `index.html` a partir de `index.template.html`, preenchendo `__GAME_CONFIG__` com `wasmSize` e os perfis `standard` e `hd`. Cada perfil informa `file` (nome do pacote), `size` (bytes no disco) e `downloadMB` (estimativa do download). Use nomes novos para pacotes alterados, para que o navegador receba a versão atual.

## Notas

- A opção de iluminação fixa da página passa `-- --luz-fixa` ao Godot. Ela mantém as luzes do cenário e desativa as sombras em tempo real, as oscilações de intensidade e as luzes móveis.
- Os mapas PBR (`assets/models/pbr/<modelo>_orm.png`) entram na web com perda e limite de 1024², nos dois pacotes, e não participam da troca de `texturas-padrao/`.
- O preset inclui `noindex` no cabeçalho da página. Tire essa linha de `export_presets.cfg` se quiser que a sua versão apareça em buscadores.
