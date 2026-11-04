"""Original Lottie light orbits around the offline interactive adventure scene."""
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "NxNativeEasy/Assets/Library"


def fixed(value):
    return {"a": 0, "k": value}


def transform(position):
    return {"o": fixed(100), "r": fixed(0), "p": fixed(position),
            "a": fixed([0, 0, 0]), "s": fixed([100, 100, 100])}


def build():
    layers = []
    for index, (rx, ry, angle) in enumerate([(290, 175, -12), (270, 200, 17)]):
        ks = transform([360, 260, 0])
        ks["r"] = fixed(angle)
        layers.append({"ddd": 0, "ind": index+1, "ty": 4, "nm": "Quiet orbital depth",
                       "sr": 1, "ks": ks, "ao": 0, "ip": 0, "op": 240, "st": 0, "bm": 0,
                       "shapes": [{"ty": "el", "d": 1, "s": fixed([rx*2, ry*2]), "p": fixed([0, 0])},
                                  {"ty": "st", "c": fixed([1, .43, .25, 1]), "o": fixed(15),
                                   "w": fixed(.7), "lc": 2, "lj": 2}]})
    for index in range(6):
        keys = []
        rx, ry = 275+index*4, 173+index*3
        for frame in range(0, 241, 30):
            theta = frame/240*math.tau+index*math.tau/6
            point = [360+math.cos(theta)*rx, 260+math.sin(theta)*ry, 0]
            key = {"t": frame, "s": point}
            if frame < 240:
                key.update({"o": {"x": .333, "y": .333}, "i": {"x": .667, "y": .667},
                            "to": [-math.sin(theta)*rx*.26, math.cos(theta)*ry*.26, 0],
                            "ti": [math.sin(theta+math.pi/4)*rx*.26, -math.cos(theta+math.pi/4)*ry*.26, 0]})
            keys.append(key)
        ks = transform([360, 260, 0])
        ks["p"] = {"a": 1, "k": keys}
        layers.insert(0, {"ddd": 0, "ind": index+3, "ty": 4, "nm": "Travelling light",
                          "sr": 1, "ks": ks, "ao": 0, "ip": 0, "op": 240, "st": 0, "bm": 0,
                          "shapes": [{"ty": "el", "d": 1, "s": fixed([3, 3]), "p": fixed([0, 0])},
                                     {"ty": "fl", "c": fixed([1, .68, .38, 1]), "o": fixed(75), "r": 1}]})
    art = json.loads((ROOT / "ecosystem-sync.json").read_text())["assets"]
    document = {"v": "5.13.0", "fr": 30, "ip": 0, "op": 240, "w": 720, "h": 520,
                "nm": "Living continuity — orbiting light", "ddd": 0,
                "assets": art, "layers": layers,
                "markers": [{"tm": 60, "cm": "reduced-motion pose", "dr": 0}]}
    (ROOT / "continuity-world.json").write_text(json.dumps(document, separators=(",", ":"))+"\n")


if __name__ == "__main__":
    build()
