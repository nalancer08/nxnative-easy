#!/usr/bin/env python3
"""Keep game profiles, catalog metadata and bilingual compatibility links aligned."""
import argparse
import html
import json
from pathlib import Path
import re
import subprocess
import sys
import unicodedata

ROOT=Path(__file__).resolve().parents[1]
ART='desktop/NxNativeEasy/game-artwork.json'
CATALOG='desktop/NxNativeEasy/game-catalog.json'
START='<!-- BEGIN GENERATED COMPATIBILITY LINKS -->'
END='<!-- END GENERATED COMPATIBILITY LINKS -->'
SITE='https://nalancer08.github.io/nxnative-easy/'


def normalized(name):
    return ''.join(c for c in unicodedata.normalize('NFKD',html.unescape(name)).casefold() if c.isalnum() and not unicodedata.combining(c))


CAPTIONS_ES = {
    'Switch 2, Mac only, from a dump': 'Switch 2, sólo Mac, carpeta extraída',
    'Switch 2, Mac only, from a NUP': 'Switch 2, sólo Mac, archivo NUP',
    'Switch 2, Mac only': 'Switch 2, sólo Mac',
    'Official artwork · Mac testing in game notes': 'Arte oficial · pruebas en Mac en la ficha',
    'up to 120 fps': 'hasta 120 fps',
    '60 fps with 1.0.0': '60 fps con 1.0.0',
    'Super Mario 64 and Sunshine; Galaxy is 32-bit ARM, which Apple silicon cannot run': 'Super Mario 64 y Sunshine; Galaxy usa ARM de 32 bits, que Apple silicon no puede ejecutar',
}

def gallery_rows(source):
    rows=[]
    for cell in re.findall(r'<td\b[^>]*>(.*?)</td>',source,re.S|re.I):
        image=re.search(r'<img\b[^>]*\bsrc="(docs/images/[^"<>]+)"[^>]*\balt="([^"]*)"',cell,re.I)
        if not image:continue
        caption=re.search(r'<(sub|small)>(.*?)</\1>',cell,re.S|re.I)
        detail=re.sub(r'^\s*<b>.*?</b>(?:<br\s*/?>)?', '', caption[2], count=1, flags=re.S|re.I) if caption else ''
        detail=html.unescape(re.sub('<[^>]+>','',detail))
        detail=next((english for english,spanish in CAPTIONS_ES.items() if detail==spanish),detail)
        if detail in ('See game notes','Ver ficha del juego'):detail=''
        rows.append(dict(image=html.unescape(image[1]),name=html.unescape(image[2]),
                         caption=detail))
    return rows


def read_json(root,name,default):
    path=root/name
    return json.loads(path.read_text()) if path.exists() else default


def inventory(root):
    table=(root/'dm/games/README.md').read_text()
    table_names={}
    for line in table.splitlines():
        match=re.match(r'\| \[([^\]]+)\]\(([0-9A-Fa-f]{16})/README\.md\) \| `([0-9A-Fa-f]{16})`',line)
        if match:
            if match[2].upper()!=match[3].upper():raise ValueError('Mismatched title ID in game table.')
            table_names[match[2].upper()]=match[1]
    games=[]
    for folder in sorted((root/'dm/games').iterdir()):
        if not re.fullmatch('[0-9A-Fa-f]{16}',folder.name) or not (folder/'game.tsv').is_file():continue
        title=folder.name.upper()
        profile=(folder/'game.tsv').read_text()
        parent=re.search(r'^program_of\t([0-9A-Fa-f]{16})\s*$',profile,re.M)
        if parent:
            owner=parent[1].upper();owner_file=root/'dm/games'/owner/'game.tsv'
            if owner==title or not owner_file.is_file():raise ValueError('Invalid parent application: '+title)
            linked=re.search(r'^programs\t(.*)$',owner_file.read_text(),re.M)
            if not linked or title not in [word.split('=',1)[-1].upper() for word in linked[1].split()]:
                raise ValueError('Parent application does not pack program: '+title)
            continue  # Packed inside its parent application, not a separate library game.
        if title not in table_names or not (folder/'README.md').is_file():raise ValueError('Missing game table row or note: '+title)
        name=None;versions=[]
        for line in profile.splitlines():
            if line.lstrip().startswith('#'):continue
            fields=[f.strip() for f in line.split('\t')]
            if len(fields)>1 and fields[0]=='name':name=fields[1]
            if len(fields)>2 and fields[0]=='build' and fields[2] and fields[2] not in versions:versions.append(fields[2])
        if not name:raise ValueError('Missing profile name: '+title)
        games.append(dict(id=title,name=name,table_name=table_names[title],versions=versions,notes=f'dm/games/{title}/README.md',console='switch2' if title.startswith('04') else 'switch1'))
    ids={g['id'] for g in games}
    if len(ids)!=len(games):raise ValueError('Duplicate profile title ID.')
    if ids!=set(table_names):raise ValueError('The game table and profile directories disagree.')
    if not games:raise ValueError('No game profiles found.')
    return sorted(games,key=lambda g:(normalized(g['name']),g['id']))


def safe_image(root,image):
    path=Path(image)
    if path.is_absolute() or '..' in path.parts or not image.startswith('docs/images/'):
        raise ValueError('Artwork must be an existing repository image: '+image)
    resolved=(root/path).resolve()
    if not resolved.is_relative_to(root.resolve()) or not resolved.is_relative_to((root/'docs/images').resolve()) or not resolved.is_file():
        raise ValueError('Missing or external artwork: '+image)


def render(games,spanish):
    site = SITE + ('es/' if spanish else '')
    links = [
        f'[Nintendo Switch {number} · {sum(game["console"] == console for game in games)}]({site}?console={console}#games)'
        for number, console in [(1, 'switch1'), (2, 'switch2')]
    ]
    table = 'Tabla completa de juegos probados' if spanish else 'Full tested games table'
    return '\n'.join([START, ' · '.join(links + [f'[{table}](dm/games/README.md#games)']), END])


def replace_summary(source,block):
    if source.count(START)!=1 or source.count(END)!=1:
        raise ValueError('Expected exactly one compatibility summary.')
    first=source.index(START);last=source.index(END)+len(END)
    if last<first:raise ValueError('Invalid compatibility markers.')
    return source[:first]+block+source[last:]


def outputs(root,upstream_html=''):
    games=inventory(root)
    images=read_json(root,ART,{})
    credits=read_json(root,'desktop/NxNativeEasy/game-artwork-sources.json',{})
    previous={g['id']:g for g in read_json(root,CATALOG,{'games':[]})['games']}
    sources=gallery_rows(upstream_html)
    by_name={normalized(row['name']):row for row in sources};by_image={row['image']:row for row in sources}
    for game in games:
        match=by_name.get(normalized(game['name'])) or by_name.get(normalized(game.pop('table_name')))
        game.pop('table_name',None)
        image=images.get(game['id']) or (match['image'] if match else None)
        if image:safe_image(root,image)
        game['artwork']=image
        row=match if match and match['image']==image else by_image.get(image)
        game['caption']=row['caption'] if row else previous.get(game['id'],{}).get('caption','')
        if not game['caption'] and credits.get(game['id'],{}).get('kind')=='official_promotional_artwork':
            game['caption']='Official artwork · Mac testing in game notes'
    result={ART:json.dumps({g['id']:g['artwork'] for g in sorted(games,key=lambda g:g['id']) if g['artwork']},indent=2,ensure_ascii=False)+'\n',
            CATALOG:json.dumps({'schema':1,'games':games},indent=2,ensure_ascii=False)+'\n'}
    for name in ['README.md','README-es.md']:
        result[name]=replace_summary((root/name).read_text(),render(games,name=='README-es.md'))
    return result


def sync(root,write=False,upstream_html=''):
    expected=outputs(root,upstream_html)
    changed=[name for name,text in expected.items() if not (root/name).exists() or (root/name).read_text()!=text]
    if write:
        for name in changed:(root/name).write_text(expected[name])
    elif changed:raise ValueError('Game catalog is stale: '+', '.join(changed)+'. Run scripts/sync_game_catalog.py --write with the pinned upstream ref.')
    return changed


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',type=Path,default=ROOT,help='explicit candidate checkout; generator code stays in the reviewed checkout')
    mode=parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--write',action='store_true');mode.add_argument('--check',action='store_true')
    parser.add_argument('--upstream-ref',help='pinned, already fetched commit for optional legacy artwork mappings')
    args=parser.parse_args()
    root=args.root.resolve()
    source=''
    if args.upstream_ref:
        if not re.fullmatch('[0-9a-fA-F]{7,40}',args.upstream_ref):parser.error('Use a pinned upstream commit SHA.')
        source=subprocess.check_output(['git','-C',str(root),'show',args.upstream_ref+':README.md'],text=True)
    changed=sync(root,args.write,source)
    print(f'Game catalog: {len(inventory(root))} profiles, '+('updated '+', '.join(changed) if changed else 'metadata and compatibility links current'))


if __name__=='__main__':
    try:main()
    except (ValueError,OSError,subprocess.SubprocessError) as error:
        print('Error:',error,file=sys.stderr);sys.exit(1)
