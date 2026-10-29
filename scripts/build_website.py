#!/usr/bin/env python3
"""Prepare only reviewed public artwork for the Astro site; never copy user data."""
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / 'web'


def prepare():
    public = WEB / 'public'
    public.mkdir(exist_ok=True)
    assets = public / 'assets'
    assets.mkdir(exist_ok=True)
    expected = set()
    sources = list((WEB / 'assets').iterdir())
    games = json.loads((ROOT / 'desktop/NxNativeEasy/game-catalog.json').read_text())['games']
    for game in games:
        path = (ROOT / game['artwork']).resolve()
        if not path.is_relative_to((ROOT / 'docs/images').resolve()) or path.suffix.lower() not in ('.png', '.jpg', '.jpeg', '.webp'):
            raise ValueError('Only reviewed public artwork may be published.')
        sources.append(path)
    for source in sources:
        if source.is_symlink() or not source.is_file():
            raise ValueError('Only regular public asset files may be published.')
        shutil.copy2(source, assets / source.name)
        expected.add(source.name)
    for previous in assets.iterdir():
        if previous.name not in expected:
            previous.unlink()
    for name in ['app.js', 'style.css']:
        shutil.copy2(WEB / name, public / name)
    site = 'https://nalancer08.github.io/nxnative-easy/'
    (public / '.nojekyll').touch()
    (public / 'robots.txt').write_text(f'User-agent: *\nAllow: /\nSitemap: {site}sitemap.xml\n')
    (public / 'sitemap.xml').write_text('<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"><url><loc>' + site + '</loc></url><url><loc>' + site + 'es/</loc></url></urlset>')
    print(f'Prepared public artwork for {len(games)} profiles; Astro renders both languages.')


if __name__ == '__main__':
    prepare()
