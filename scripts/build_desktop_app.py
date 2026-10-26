#!/usr/bin/env python3
"""Build a local native launcher without Apple signing or game resources."""
import argparse
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import shutil

REPO=Path(__file__).resolve().parents[1]

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True,help='app path outside the source repository')
    parser.add_argument('--open',action='store_true')
    args=parser.parse_args()
    output=args.output.expanduser().absolute()
    if output==REPO or REPO in output.parents:parser.error('Keep build outputs outside the repository.')
    if output.suffix!='.app':parser.error('Output must end with .app')
    contents=output/'Contents';macos=contents/'MacOS';macos.mkdir(parents=True,exist_ok=True)
    subprocess.run(['xcrun','swiftc','-parse-as-library','-swift-version','5',
        str(REPO/'desktop/NxNativeEasy/main.swift'),str(REPO/'desktop/NxNativeEasy/Localization.swift'),str(REPO/'desktop/NxNativeEasy/GameCatalog.swift'),'-o',str(macos/'NxNativeEasy'),
        '-framework','SwiftUI','-framework','AppKit'],check=True)
    resources=contents/'Resources';resources.mkdir(exist_ok=True)
    shutil.copy2(REPO/'desktop/NxNativeEasy/Assets/AppIcon.png',resources/'BrandIcon.png')
    with tempfile.TemporaryDirectory(prefix='nxnative-icon-') as temporary:
        iconset=Path(temporary)/'AppIcon.iconset';iconset.mkdir()
        subprocess.run(['xcrun','swift',str(REPO/'desktop/NxNativeEasy/Assets/draw_icon.swift'),str(iconset)],check=True)
        subprocess.run(['iconutil','-c','icns',str(iconset),'-o',str(resources/'AppIcon.icns')],check=True)
    info=dict(CFBundleIconFile='AppIcon', CFBundleIdentifier='com.nalancer08.nxnative.easy',CFBundleName='nxnative',
              CFBundleDisplayName='nxnative Easy',CFBundleExecutable='NxNativeEasy',
              CFBundlePackageType='APPL',CFBundleShortVersionString='1.0',CFBundleVersion='1',
              LSMinimumSystemVersion='26.0',CFBundleDevelopmentRegion='en',CFBundleLocalizations=['en','es'],NSHighResolutionCapable=True,NxNativeSource=str(REPO))
    (contents/'Info.plist').write_bytes(plistlib.dumps(info))
    # Explicit ad-hoc signing: '-' never selects an Apple certificate or team.
    subprocess.run(['codesign','--force','--sign','-','--timestamp=none',str(output)],check=True)
    if args.open:subprocess.run(['open',str(output)],check=True)
    print(output)

if __name__=='__main__':main()
