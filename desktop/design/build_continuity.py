"""Rebuild the original, local-only onboarding composition (no third-party art)."""
import base64
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "NxNativeEasy/Assets/Library"


def fixed(value):
    return {"a": 0, "k": value}


def animated(start, end, finish=42):
    return {"a": 1, "k": [
        {"t": 0, "s": start, "e": end,
         "o": {"x": [0.16], "y": [1]}, "i": {"x": [0.32], "y": [1]}},
        {"t": finish, "s": end},
    ]}


def transform(position, rotation=0, scale=100):
    return {"o": fixed(100), "r": fixed(rotation), "p": fixed(position),
            "a": fixed([0, 0, 0]), "s": fixed([scale, scale, 100])}


def rounded_path(x, y, width, height, radius):
    r = radius
    k = r * 0.55228475
    return {"c": True,
            "v": [[x+r, y], [x+width-r, y], [x+width, y+r],
                  [x+width, y+height-r], [x+width-r, y+height],
                  [x+r, y+height], [x, y+height-r], [x, y+r]],
            "i": [[-k, 0], [0, 0], [0, -k], [0, 0], [k, 0], [0, 0], [0, k], [0, 0]],
            "o": [[0, 0], [k, 0], [0, 0], [0, k], [0, 0], [-k, 0], [0, 0], [0, -k]]}


def layer(index, name, kind, ks):
    return {"ddd": 0, "ind": index, "ty": kind, "nm": name, "sr": 1,
            "ks": ks, "ao": 0, "ip": 0, "op": 180, "st": 0, "bm": 0}


def build():
    # The image mask uses image coordinates. The layer transform then scales both
    # together; this avoids deforming either the artwork or its rounded corners.
    main = layer(1, "Your adventure — arrive and settle", 2,
                 transform([360, 218, 0], scale=0.48 * 100))
    main["refId"] = "original-world"
    # lottie-web normalizes relative mask tangents only on layers with hasMask.
    main["hasMask"] = True
    main["ks"]["a"] = fixed([512, 341.5, 0])
    main["ks"]["p"] = animated([360, 245, 0], [360, 218, 0])
    main["ks"]["r"] = animated([-4], [0])
    main["masksProperties"] = [{"inv": False, "mode": "a", "nm": "Soft card corners",
                               "pt": fixed(rounded_path(0, 0, 1024, 683, 43)),
                               "o": fixed(100), "x": fixed(0)}]
    cards = []
    for index, x, angle, color in [(2, 350, -8, [0.28, 0.20, 0.18, 1]),
                                  (3, 370, 7, [0.12, 0.18, 0.20, 1])]:
        card = layer(index, "A continuation, not another device diagram", 4,
                     transform([x, 224, 0], rotation=angle))
        card["ks"]["p"] = animated([360, 240, 0], [x, 224, 0], 36)
        card["ks"]["r"] = animated([0], [angle], 36)
        card["shapes"] = [
            {"ty": "rc", "nm": "Backing card", "d": 1,
             "s": fixed([494, 332]), "p": fixed([0, 0]), "r": fixed(21)},
            {"ty": "fl", "nm": "Quiet tonal depth", "c": fixed(color), "o": fixed(100), "r": 1},
        ]
        cards.append(card)
    document = {"v": "5.13.0", "fr": 30, "ip": 0, "op": 180, "w": 720, "h": 440,
                "nm": "One adventure — brief entry, then rest", "ddd": 0,
                "assets": [{"id": "original-world", "w": 1024, "h": 683, "u": "",
                            "p": "data:image/jpeg;base64," + base64.b64encode(
                                (ROOT / "adventure-world.jpg").read_bytes()).decode(), "e": 1}],
                "layers": [main, *cards],
                "markers": [{"tm": 0, "cm": "arrive", "dr": 42},
                            {"tm": 60, "cm": "reduced-motion resting pose", "dr": 120}]}
    (ROOT / "ecosystem-sync.json").write_text(json.dumps(document, separators=(",", ":")) + "\n")


if __name__ == "__main__":
    build()
