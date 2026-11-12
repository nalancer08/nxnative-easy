#!/usr/bin/env python3
"""Check generated bilingual pages, catalog coverage and deployable local links."""
from html.parser import HTMLParser
import json
from pathlib import Path
from urllib.parse import urlsplit, unquote
from build_website import PUBLIC_ASSETS

ROOT = Path(__file__).resolve().parents[1]
DIST = ROOT / 'web/dist'
PREFIX = '/nxnative-easy/'


class Page(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []
        self.ids = set()
        self.profiles = []
        self.profile_consoles = {}
        self.console_filters = set()
        self.lang = None

    def handle_starttag(self, tag, attrs):
        values = dict(attrs)
        if tag == 'html':
            self.lang = values.get('lang')
        element_id = values.get('id')
        if element_id is not None:
            if element_id in self.ids:
                raise ValueError('Duplicate element ID: ' + element_id)
            self.ids.add(element_id)
        if 'data-title-id' in values:
            self.profiles.append(values['data-title-id'])
            self.profile_consoles[values['data-title-id']] = values.get('data-console')
        if 'data-console-filter' in values:
            self.console_filters.add(values['data-console-filter'])
        for key in ['src', 'href']:
            if key in values:
                self.links.append(values[key])


def check():
    games = json.loads((ROOT / 'desktop/NxNativeEasy/game-catalog.json').read_text())['games']
    expected = {game['id'] for game in games}
    consoles = {game['id']:game['console'] for game in games}
    for lang, name in [('en', 'index.html'), ('es', 'es/index.html')]:
        page = Page()
        source = (DIST / name).read_text()
        page.feed(source)
        assert page.lang == lang
        assert len(page.profiles) == len(expected) and set(page.profiles) == expected
        assert page.profile_consoles == consoles
        assert page.console_filters == {'all', 'switch1', 'switch2'}
        assert '@@' not in source
        for link in page.links:
            if link.startswith('#'):
                assert link[1:] in page.ids, (name, link)
            elif link.startswith(PREFIX):
                path = (DIST / unquote(urlsplit(link).path[len(PREFIX):])).resolve()
                assert path.is_relative_to(DIST.resolve()), link
                assert path.exists(), (name, link)
    for path in DIST.rglob('*'):
        assert not path.is_symlink()
        assert path.name not in ('prod.keys', 'title.keys')
        assert path.suffix.lower() not in ('.ipa', '.nsp', '.xci', '.nsz', '.xcz', '.p12', '.mobileprovision')
    assert {path.name for path in (DIST / 'assets').iterdir()} == set(PUBLIC_ASSETS)
    print(f'English/Spanish routes, local links, all {len(expected)} profiles and public asset boundary verified.')


if __name__ == '__main__':
    check()
