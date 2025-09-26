import os
import numpy as np
import torch
from PIL import Image

CKPT_PATH = "binary_snn_weights.pth"
PNG_PATH = "one.png"

WW = 16 # weight bit width (signed)
SCALE = 40960 # float->fixed scale
T = 32 # timesteps (lines) in input_spikes.hex


def sat_int(arr: np.ndarray, bits: int) -> np.ndarray:
    lo, hi = -(1 << (bits - 1)), (1 << (bits - 1)) - 1
    return np.clip(np.round(arr).astype(np.int64), lo, hi)

def lane_hex(x: int, bits: int) -> str:
    return f"{(x & ((1 << bits) - 1)):0{bits // 4}X}"

def pack_row_lanes_lsb_first(lanes, ww: int) -> str:
    return "".join(lane_hex(v, ww) for v in reversed(lanes))

def write_lines(path: str, lines):
    with open(path, "w") as f:
        for s in lines:
            f.write(s.strip() + "\n")
    print(f"Wrote {path} ({len(lines)} lines)")


def load_fc_weights_from_ckpt(ckpt_path: str):
    sd = torch.load(ckpt_path, map_location="cpu")
    w1 = sd["fc1.weight"].cpu().numpy()  # (6,9)
    w2 = sd["fc2.weight"].cpu().numpy()  # (2,6)
    return w1, w2

def pack_w1_rows(w1: np.ndarray, ww: int, scale: float):
    q = sat_int(w1 * scale, ww)
    return [pack_row_lanes_lsb_first([int(q[k, i]) for k in range(6)], ww) for i in range(9)]

def pack_w2_rows(w2: np.ndarray, ww: int, scale: float):
    q = sat_int(w2 * scale, ww)
    return [pack_row_lanes_lsb_first([int(q[0, j]), int(q[1, j])], ww) for j in range(6)]


def png_to_9bit_mask_hex(path: str) -> str:
    im = Image.open(path).convert("L").resize((3, 3), Image.NEAREST)
    arr = np.array(im, dtype=np.uint8)
    bits = (arr < 128).astype(np.uint8).flatten()
    mask = 0
    for i, b in enumerate(bits[::-1]):
        mask |= (int(b) << i)
    return f"{mask:03X}"


def main():
    #Weights → w1.hex / w2.hex
    w1, w2 = load_fc_weights_from_ckpt(CKPT_PATH)
    write_lines("w1.hex", pack_w1_rows(w1, WW, SCALE))
    write_lines("w2.hex", pack_w2_rows(w2, WW, SCALE))

    #Input → input_spikes.hex
    if not os.path.isfile(PNG_PATH):
        raise FileNotFoundError(f"Input PNG not found: {PNG_PATH}")
    mask_hex = png_to_9bit_mask_hex(PNG_PATH)
    write_lines("input_spikes.hex", [mask_hex for _ in range(T)])


if __name__ == "__main__":
    main()

#note: this file was created with the help of generative AI.