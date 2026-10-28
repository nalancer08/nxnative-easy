#!/usr/bin/env python3
"""Keep game profiles, artwork, the desktop inventory and both README galleries aligned."""
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
START='<!-- BEGIN GENERATED GAME GALLERY -->'
END='<!-- END GENERATED GAME GALLERY -->'


def normalized(name):
    return ''.join(c for c in unicodedata.normalize('NFKD',html.unescape(name)).casefold() if c.isalnum() and not unicodedata.combining(c))


def gallery_rows(source):
    rows=[]
    for cell in re.findall(r'<td\b[^>]*>(.*?)</td>',source,re.S|re.I):
        image=re.search(r'<img\b[^>]*\bsrc="(docs/images/[^"<>]+)"[^>]*\balt="([^"]*)"',cell,re.I)
        if not image:continue
        caption=re.search(r'<sub>(.*?)</sub>',cell,re.S|re.I)
        detail=re.sub(r'^\s*<b>.*?</b>(?:<br\s*/?>)?', '', caption[1], count=1, flags=re.S|re.I) if caption else ''
        detail=html.unescape(re.sub('<[^>]+>','',detail))
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
        if title not in table_names or not (folder/'README.md').is_file():raise ValueError('Missing game table row or note: '+title)
        name=None;versions=[]
        for line in (folder/'game.tsv').read_text().splitlines():
            if line.lstrip().startswith('#'):continue
            fields=[f.strip() for f in line.split('\t')]
            if len(fields)>1 and fields[0]=='name':name=fields[1]
            if len(fields)>2 and fields[0]=='build' and fields[2] and fields[2] not in versions:versions.append(fields[2])
        if not name:raise ValueError('Missing profile name: '+title)
        games.append(dict(id=title,name=name,table_name=table_names[title],versions=versions,notes=f'dm/games/{title}/README.md'))
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
    count=f"{len(games)} perfiles. Consulta la ficha de cada juego para ver versiones y dispositivos probados." if spanish else f"{len(games)} profiles. See each game's notes for tested versions and devices."
    lines=[START,count,'','<table>']
    for i,game in enumerate(games):
        if i%3==0:lines.append('<tr>')
        name=html.escape(game['name'],quote=True);image=html.escape(game['artwork'],quote=True);notes=game['notes']
        caption=html.escape(game['caption'] or ('Ver ficha del juego' if spanish else 'See game notes'))
        lines.append(f'<td align="center" valign="top" width="33%" data-title-id="{game["id"]}"><a href="{notes}"><img src="{image}" width="256" alt="{name}"></a><br><a href="{notes}">{name}</a><br><sub>{caption}</sub></td>')
        if i%3==2 or i==len(games)-1:lines.append('</tr>')
    return '\n'.join(lines+['</table>',END])


def replace_gallery(source,block):
    if START in source or END in source:
        if source.count(START)!=1 or source.count(END)!=1:raise ValueError('Expected exactly one generated gallery block.')
        first=source.index(START);last=source.index(END)+len(END)
        if last<first:raise ValueError('Invalid gallery markers.')
    else:
        first=source.index('<table>');last=source.index('</table>',first)+len('</table>')
    return source[:first]+block+source[last:]


def outputs(root,upstream_html=''):
    games=inventory(root)
    images=read_json(root,ART,{})
    previous={g['id']:g for g in read_json(root,CATALOG,{'games':[]})['games']}
    sources=[]
    for name in ['README.md','README-es.md']:sources+=gallery_rows((root/name).read_text())
    sources+=gallery_rows(upstream_html)   # pinned upstream captions override older gallery captions
    by_name={normalized(row['name']):row for row in sources};by_image={row['image']:row for row in sources}
    for game in games:
        match=by_name.get(normalized(game['name'])) or by_name.get(normalized(game.pop('table_name')))
        game.pop('table_name',None)
        image=images.get(game['id']) or (match['image'] if match else None)
        if not image:raise ValueError(f"No screenshot mapped for {game['id']} ({game['name']}); import the upstream screenshot and map its title ID before release.")
        safe_image(root,image)
        game['artwork']=image
        row=match if match and match['image']==image else by_image.get(image)
        game['caption']=row['caption'] if row else previous.get(game['id'],{}).get('caption','')
    result={ART:json.dumps({g['id']:g['artwork'] for g in sorted(games,key=lambda g:g['id'])},indent=2,ensure_ascii=False)+'\n',
            CATALOG:json.dumps({'schema':1,'games':games},indent=2,ensure_ascii=False)+'\n'}
    for name in ['README.md','README-es.md']:
        result[name]=replace_gallery((root/name).read_text(),render(games,name=='README-es.md'))
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
    mode=parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--write',action='store_true');mode.add_argument('--check',action='store_true')
    parser.add_argument('--upstream-ref',help='pinned, already fetched commit used only to discover upstream screenshot/caption mappings')
    args=parser.parse_args()
    source=''
    if args.upstream_ref:
        if not re.fullmatch('[0-9a-fA-F]{7,40}',args.upstream_ref):parser.error('Use a pinned upstream commit SHA.')
        source=subprocess.check_output(['git','-C',str(ROOT),'show',args.upstream_ref+':README.md'],text=True)
    changed=sync(ROOT,args.write,source)
    print(f'Game catalog: {len(inventory(ROOT))} profiles, '+('updated '+', '.join(changed) if changed else 'all mappings and galleries current'))


if __name__=='__main__':
    try:main()
    except (ValueError,OSError,subprocess.SubprocessError) as error:
        print('Error:',error,file=sys.stderr);sys.exit(1)
