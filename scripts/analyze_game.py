#!/usr/bin/env python3
"""Export an original prepared NSO as ELF and optionally analyze it with pinned, isolated REA."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from datetime import datetime

ROOT=Path(__file__).resolve().parents[1]
REA_VERSION='6.8.0'
NODE_VERSION='24.22.1'


def prepared_module(game):
    candidates=[]
    for path in game.glob('*_build/extract/v*/ExeFS/main'):
        if not re.fullmatch('[0-9A-Fa-f]{16}_build',path.parents[3].name):continue
        if not re.fullmatch('v[0-9]+',path.parents[1].name):continue
        if not path.resolve().is_relative_to(game) or path.is_symlink():continue
        candidates.append((int(path.parents[1].name[1:]),path))
    titles={path.parents[3].name for _,path in candidates}
    if len(titles)!=1:raise ValueError('Prepare exactly one game in this folder first. Analysis uses its extracted original main NSO, never an NSP, key or save.')
    return max(candidates,key=lambda entry:entry[0])[1]


def npm_command(workspace,environment):
    npm=shutil.which('npm')
    if not npm:
        candidates=[Path('/opt/homebrew/bin/npm'),Path('/usr/local/bin/npm')]
        candidates+=sorted((Path.home()/'.nvm/versions/node').glob('*/bin/npm'),reverse=True)
        npm=next((str(path) for path in candidates if path.is_file()),None)
    if not npm:raise ValueError('Install Node.js/npm to enable optional REA analysis. Game preparation does not require REA.')
    environment['PATH']=str(Path(npm).parent)+os.pathsep+environment.get('PATH','')
    # Download exact packages to this game's cache, without changing global Node or agent registrations.
    return [npm,'exec','--cache',str(workspace.parent/'rea-cache'),'--yes',
            '--package=node@'+NODE_VERSION,'--package=rea-agents@'+REA_VERSION,'--','rea']


def analyze(game,output,run=False,provider=None):
    game=game.expanduser().resolve(strict=True);output=output.expanduser().resolve()
    if game==ROOT or ROOT in game.parents or not game.is_dir():raise ValueError('Choose your game folder outside the checkout.')
    if not output.is_relative_to(game/'nxnative-tools/analysis'):raise ValueError('Analysis output must be under this game\'s nxnative-tools/analysis folder.')
    source=prepared_module(game)
    with source.open('rb') as stream:header=stream.read(0x60)
    if header[:4]!=b'NSO0' or len(header)<0x60:raise ValueError('Original extracted module is not a valid NSO.')
    python=game/'nxnative-tools/venv/bin/python'
    if not python.is_file():raise ValueError('Prepare this game with the app first; its analysis converter needs the game-local Python environment.')
    output.mkdir(parents=True,exist_ok=False,mode=0o700)
    before=hashlib.sha256(source.read_bytes()).hexdigest()
    metadata=dict(schema=1,title_id=source.parents[3].name[:-6],package=source.parents[1].name,
                  main_build_id=header[0x40:0x60].hex(),source_sha256=before,
                  rea_repository='https://github.com/morluto/rea',rea_version=REA_VERSION,node_version=NODE_VERSION,
                  status='exporting',automatically_ports_game=False)
    record=output/'analysis.json'
    def save():record.write_text(json.dumps(metadata,indent=2)+'\n')
    save()
    try:
        print('Exporting original main NSO to an AArch64 ELF for static analysis.',flush=True)
        subprocess.run([str(python),str(ROOT/'dm/tools/nso2elf.py'),str(source),str(output/'main.elf')],check=True)
        if hashlib.sha256(source.read_bytes()).hexdigest()!=before:raise ValueError('Source changed during export; stop the active preparation and try again.')
        (output/'README.txt').write_text('REA analysis workspace\n\nOriginal game NSO exported to main.elf; no game, keys or saves uploaded.\n'
            'REA is an optional analysis adapter, not a game porting engine or an AI agent.\n'
            'Native pseudocode requires a compatible local Ghidra, Hopper or IDA provider.\n'
            'Use a separate agent to investigate evidence; proposed patches still require build-ID gates and tests.\n'
            'Do not commit ELF, evidence or game files to GitHub.\n\n'
            'Official REA: https://github.com/morluto/rea\n'
            'CLI: https://github.com/morluto/rea/blob/main/docs/cli.md\n')
        metadata['status']='exported';save()
        if run:
            env=dict(os.environ);command=npm_command(output,env)
            if provider not in (None,'ghidra','hopper','ida'):raise ValueError('Choose ghidra, hopper or ida.')
            print('Starting optional REA '+REA_VERSION+' with isolated Node '+NODE_VERSION+'. Native analysis needs an existing compatible provider.',flush=True)
            command+=['analyze',str(output/'main.elf'),'--json']
            if provider:command+=['--provider',provider]
            # Retain potentially large native Evidence on disk, never as one giant UI message.
            with (output/'rea.json').open('wb') as evidence,(output/'rea-stderr.log').open('w') as diagnostics:
                with subprocess.Popen(command,cwd=output,env=env,stdout=evidence,stderr=subprocess.PIPE,text=True,errors='replace') as child:
                    assert child.stderr is not None
                    for line in child.stderr:diagnostics.write(line);diagnostics.flush();print(line,end='',flush=True)
                    code=child.wait()
            if code:raise ValueError('REA could not complete analysis. Review rea.json and rea-stderr.log for provider configuration. The ELF and original files were preserved.')
            metadata['status']='analyzed';save()
        print('Analysis workspace: '+str(output),flush=True)
        return output
    except BaseException as error:
        metadata['status']='failed';metadata['error']=str(error);save();raise


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('game_dir',type=Path)
    parser.add_argument('--output',type=Path)
    parser.add_argument('--run',action='store_true',help='download exact isolated REA/Node packages and run local native analysis')
    parser.add_argument('--provider',choices=['ghidra','hopper','ida'])
    args=parser.parse_args();output=args.output or args.game_dir/'nxnative-tools/analysis'/datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    analyze(args.game_dir,output,args.run,args.provider)

if __name__=='__main__':
    try:main()
    except (ValueError,OSError,subprocess.SubprocessError) as error:print('Error: '+str(error),file=sys.stderr);sys.exit(1)
