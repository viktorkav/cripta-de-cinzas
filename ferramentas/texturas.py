# Gera texturas pixel-art (grão voxel) de piso e parede com normal map. Uso: python3 texturas.py <saida>
import sys, os, numpy as np
from PIL import Image
Image.Image.pipe = lambda self, f: f(self)

out = sys.argv[1]
os.makedirs(out, exist_ok=True)
rng = np.random.default_rng(7)


def voronoi(w, h, n, rng, wrap=True):
    pts = rng.random((n, 2)) * [w, h]
    yy, xx = np.mgrid[0:h, 0:w]
    best = np.full((h, w), 1e9); second = np.full((h, w), 1e9); idx = np.zeros((h, w), int)
    offs = [(dx, dy) for dx in (-w, 0, w) for dy in (-h, 0, h)] if wrap else [(0, 0)]
    for i, (px, py) in enumerate(pts):
        for dx, dy in offs:
            d = np.sqrt((xx - px - dx) ** 2 + (yy - py - dy) ** 2)
            m = d < best
            second = np.where(m, best, np.minimum(second, d))
            idx = np.where(m, i, idx)
            best = np.where(m, d, best)
    return idx, second - best


def normal_from_height(hm, strength=2.0):
    gx = np.roll(hm, -1, 1) - np.roll(hm, 1, 1)
    gy = np.roll(hm, -1, 0) - np.roll(hm, 1, 0)
    nx = -gx * strength; ny = gy * strength; nz = np.ones_like(hm)
    l = np.sqrt(nx ** 2 + ny ** 2 + nz ** 2)
    n = np.stack([nx / l, ny / l, nz / l], -1)
    return ((n * 0.5 + 0.5) * 255).astype(np.uint8)


def up(img, k, mode=Image.NEAREST):
    return img.resize((img.width * k, img.height * k), mode)


# ---------- PISO: atlas 2x2 de lajes, cada célula 32x32 px = 1 m ----------
S = 32
atlas_c = np.zeros((S * 2, S * 2, 3)); atlas_h = np.zeros((S * 2, S * 2)); atlas_r = np.zeros((S * 2, S * 2))
base_cols = np.array([[52, 50, 54], [60, 56, 55], [46, 47, 52], [58, 54, 50], [50, 52, 56], [64, 60, 58]]) / 255.0
for cell in range(4):
    cx, cy = cell % 2, cell // 2
    n = [4, 5, 3, 6][cell]
    idx, edge = voronoi(S, S, n, rng, wrap=False)
    col = np.zeros((S, S, 3)); hgt = np.zeros((S, S)); rough = np.zeros((S, S))
    for i in range(n):
        m = idx == i
        c = base_cols[rng.integers(len(base_cols))] * rng.uniform(0.85, 1.15)
        col[m] = c
        hgt[m] = rng.uniform(0.75, 1.0)
    noise = rng.normal(0, 0.035, (S, S, 1))
    col = col + noise
    mortar = edge < 0.75
    col[mortar] = np.array([22, 20, 22]) / 255.0
    hgt[mortar] = 0.15
    # borda do ladrilho (junta) e bisel
    border = np.zeros((S, S), bool); border[0, :] = border[-1, :] = border[:, 0] = border[:, -1] = True
    col[border] = np.array([18, 16, 18]) / 255.0; hgt[border] = 0.05
    bev = (edge >= 0.75) & (edge < 1.7) & ~border
    col[bev] *= 1.12
    # rachaduras
    for _ in range(rng.integers(1, 3)):
        x, y = rng.integers(3, S - 3, 2)
        for _ in range(rng.integers(4, 9)):
            if 0 < x < S - 1 and 0 < y < S - 1:
                col[y, x] *= 0.55; hgt[y, x] = 0.3
            x += rng.integers(-1, 2); y += rng.integers(0, 2)
    # musgo e sujeira nos cantos
    moss = (rng.random((S, S)) < 0.04) & (edge < 3.5)
    col[moss] = col[moss] * 0.5 + np.array([38, 52, 34]) / 255.0 * 0.5
    rough[:] = 0.85; rough[mortar] = 0.95; rough[bev] = 0.7
    atlas_c[cy * S:(cy + 1) * S, cx * S:(cx + 1) * S] = col
    atlas_h[cy * S:(cy + 1) * S, cx * S:(cx + 1) * S] = hgt
    atlas_r[cy * S:(cy + 1) * S, cx * S:(cx + 1) * S] = rough

K = 8  # 64 px -> 512 px, pixels nítidos
Image.fromarray((np.clip(atlas_c, 0, 1) * 255).astype(np.uint8)).pipe(lambda i: up(i, K)).save(f"{out}/piso_albedo.png")
Image.fromarray(normal_from_height(np.kron(atlas_h, np.ones((K, K))), 6.0)).save(f"{out}/piso_normal.png")
Image.fromarray((atlas_r * 255).astype(np.uint8)).pipe(lambda i: up(i, K)).save(f"{out}/piso_rough.png")

# ---------- PAREDE: tijolos grandes, 32 px largura x 96 px altura = 1 x 3 m ----------
W, H = 32, 96
col = np.zeros((H, W, 3)); hgt = np.zeros((H, W))
row_h = 8
for r in range(H // row_h):
    y0 = r * row_h
    offset = (r % 2) * 8
    x = -offset
    while x < W:
        bw = int(rng.integers(10, 18))
        c = np.array([44, 42, 46]) / 255.0 * rng.uniform(0.8, 1.2) + rng.uniform(-0.02, 0.02, 3)
        for yy in range(y0, y0 + row_h):
            for xx in range(x, x + bw):
                if 0 <= xx < W:
                    col[yy, xx] = c
                    hgt[yy, xx] = 1.0
        # junta vertical
        for yy in range(y0, y0 + row_h):
            if 0 <= x < W:
                col[yy, x] = np.array([16, 15, 17]) / 255.0; hgt[yy, x] = 0.1
        x += bw
    col[y0, :] = np.array([16, 15, 17]) / 255.0; hgt[y0, :] = 0.1
col += rng.normal(0, 0.03, (H, W, 1))
# bisel de cima de cada tijolo mais claro
for r in range(H // row_h):
    y = r * row_h + 1
    m = hgt[y] > 0.5
    col[y, m] *= 1.18
# musgo e umidade na base
for yy in range(H - 22, H):
    t = (yy - (H - 22)) / 22
    m = rng.random(W) < 0.25 * t
    col[yy, m] = col[yy, m] * 0.5 + np.array([34, 48, 32]) / 255.0 * 0.5
    col[yy] *= 1 - 0.35 * t
# fuligem no topo
for yy in range(0, 18):
    col[yy] *= 0.6 + 0.4 * yy / 18
Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8)).pipe(lambda i: up(i, K)).save(f"{out}/parede_albedo.png")
Image.fromarray(normal_from_height(np.kron(hgt, np.ones((K, K))), 5.0)).save(f"{out}/parede_normal.png")

# ---------- ruído de chama (para shaders de fogo) ----------
N = 256
base = rng.random((N // 8, N // 8))
img = np.array(Image.fromarray((base * 255).astype(np.uint8)).resize((N, N), Image.BICUBIC)) / 255.0
fine = rng.random((N // 2, N // 2))
img2 = np.array(Image.fromarray((fine * 255).astype(np.uint8)).resize((N, N), Image.BICUBIC)) / 255.0
noise = np.clip(img * 0.65 + img2 * 0.35, 0, 1)
Image.fromarray((noise * 255).astype(np.uint8)).save(f"{out}/ruido.png")
print("ok")
