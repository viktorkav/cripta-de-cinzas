# Empacota os mapas PBR da Tripo (nó PBR do Canvas, 4096²) num mapa só por modelo,
# no padrão glTF/ORM: R = oclusão (fixa em 1), G = roughness, B = metallic.
# Uso: python3 empacotar_pbr.py <dir_mapas> <dir_saida> [lado=2048] [--normal]
import sys, glob, os
import numpy as np
from PIL import Image
Image.MAX_IMAGE_PIXELS = None
src, out = sys.argv[1], sys.argv[2]
lado = int(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3].isdigit() else 2048
com_normal = "--normal" in sys.argv
NOMES = {"heroi": "heroi", "esqueleto": "esqueleto", "cultista": "cultista", "bruto": "bruto",
         "diabrete": "diabrete", "chefe": "chefe", "pilar": "pilar", "tocha": "tocha", "barril": "barril",
         "porta": "porta", "bau": "bau_novo", "braseiro": "braseiro", "ossos": "ossos", "estandarte": "estandarte"}
os.makedirs(out, exist_ok=True)
for tripo, jogo in NOMES.items():
    m = glob.glob(os.path.join(src, tripo + "__*_metallic.png"))[0]
    r = glob.glob(os.path.join(src, tripo + "__*_roughness.png"))[0]
    gm = Image.open(m).convert("L").resize((lado, lado), Image.LANCZOS)
    gr = Image.open(r).convert("L").resize((lado, lado), Image.LANCZOS)
    ao = Image.new("L", (lado, lado), 255)
    Image.merge("RGB", (ao, gr, gm)).save(os.path.join(out, jogo + "_orm.png"), optimize=True)
    if com_normal:
        n = glob.glob(os.path.join(src, tripo + "__tripo_normal_*.png"))[0]
        Image.open(n).convert("RGB").resize((lado, lado), Image.LANCZOS).save(os.path.join(out, jogo + "_normal.png"), optimize=True)
    print(jogo, "ok", os.path.basename(m), os.path.basename(r))
