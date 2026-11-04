#!/usr/bin/env python3
"""Author the original launcher scene with the generated portal and vector orbits."""
import base64
import json
from pathlib import Path
from typing import Any

ASSETS = Path(__file__).resolve().parents[2] / 'desktop/NxNativeEasy/Assets/Library'


def fixed(value):
    return {'a': 0, 'k': value}


def cycle(values):
    return {'a': 1, 'k': [dict(t=t, s=value, i={'x': [0.65], 'y': [1]},
                               o={'x': [0.35], 'y': [0]}) for t, value in values]}


def transform(position, anchor=None, scale=None):
    return dict(o=fixed(100), r=fixed(0), p=position,
                a=fixed(anchor or [0, 0, 0]), s=scale or fixed([100, 100, 100]))


def main():
    image = base64.b64encode((ASSETS / 'portal-3d.png').read_bytes()).decode('ascii')
    scene: dict[str, Any] = dict(v='5.13.0', fr=30, ip=0, op=240, w=600, h=400,
                 nm='Easy — launch portal', ddd=0,
                 assets=[dict(id='portal', w=1536, h=1024, u='', e=1,
                              p='data:image/png;base64,' + image)],
                 layers=[], markers=[dict(tm=60, cm='resting pose', dr=0)])
    scene['layers'].append(dict(ddd=0, ind=1, ty=2, nm='Original 3D portal', refId='portal',
                                sr=1, ip=0, op=240, st=0, bm=0,
                                ks=transform(cycle([(0, [300, 202, 0]), (120, [300, 186, 0]),
                                                    (240, [300, 202, 0])]),
                                             anchor=[768, 512, 0], scale=fixed([39, 39, 100]))))
    for index, (x, y, delay) in enumerate([(95, 155, 0), (510, 135, 30), (490, 315, 60)]):
        scene['layers'].append(dict(ddd=0, ind=index + 2, ty=4, nm='Orbit light ' + str(index),
                                    sr=1, ip=0, op=240, st=0, bm=0,
                                    ks=transform(cycle([(0, [x, y, 0]), (120, [x, y - 12, 0]),
                                                        (240, [x, y, 0])])),
                                    shapes=[dict(ty='el', d=1, s=fixed([5, 5]), p=fixed([0, 0])),
                                            dict(ty='fl', c=fixed([1, 0.57, 0.32, 1]),
                                                 o=cycle([(0, [35]), (60 + delay, [90]),
                                                          (180, [55]), (240, [35])]))]))
    (ASSETS / 'launcher-open.json').write_text(json.dumps(scene, separators=(',', ':')) + '\n')
    template = (ASSETS / 'save-transfer.html').read_text().replace('#090B11', '#111319')
    (ASSETS / 'launcher-open.html').write_text(template)


if __name__ == '__main__':
    main()
