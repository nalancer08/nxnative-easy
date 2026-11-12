#!/usr/bin/env python3
"""Prepare only reviewed public artwork for the Astro site; never copy user data."""
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / 'web'
PUBLIC_ASSETS = ('icon.png', 'signal-ridge.webp', 'social.jpg', 'outfit.ttf', 'OFL-Outfit.txt')


def prepare():
    public = WEB / 'public'
    public.mkdir(exist_ok=True)
    assets = public / 'assets'
    assets.mkdir(exist_ok=True)
    for name in PUBLIC_ASSETS:
        source = WEB / 'assets' / name
        if source.is_symlink() or not source.is_file():
            raise ValueError('Only regular public asset files may be published.')
        shutil.copy2(source, assets / name)
    for previous in assets.iterdir():
        if previous.name not in PUBLIC_ASSETS:
            previous.unlink()
    for name in ['app.js', 'style.css']:
        shutil.copy2(WEB / name, public / name)
    site = 'https://nalancer08.github.io/nxnative-easy/'
    (public / '.nojekyll').touch()
    (public / 'robots.txt').write_text(f'User-agent: *\nAllow: /\nSitemap: {site}sitemap.xml\n')
    (public / 'sitemap.xml').write_text('<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"><url><loc>' + site + '</loc></url><url><loc>' + site + 'es/</loc></url></urlset>')
    print('Prepared original product artwork; Astro renders both languages.')


if __name__ == '__main__':
    prepare()
