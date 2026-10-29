# nxnative Easy website

Static Astro site, English at `/nxnative-easy/` and Spanish at `/nxnative-easy/es/`.
Node 24 and Python 3 are build prerequisites. Visitors need neither.

```sh
cd web
npm ci
npm run dev
```

Production: `npm run build`, then `python3 ../scripts/check_website.py`.
GitHub Actions publishes `dist/` to Pages on relevant main-branch changes.
The app download always targets the latest published portable ZIP.

## Keeping it current

- `content.json`: paired English/Spanish copy.
- `src/components/Site.astro`: shared page composition; routes use the same component.
- `style.css` and `app.js`: visual system, progressive motion and interactions.
- `assets/`: public optimized product screenshots, app icon, social preview and licensed Outfit font.
- `scripts/build_website.py`: copies only reviewed public assets, including all game artwork from the generated desktop catalog. No personal folders, games, keys, accounts or saves.
- The catalog count and cards derive from `desktop/NxNativeEasy/game-catalog.json`; no separate website game inventory to maintain.

Follow the app's lime/dark palette. The landing page adds editorial typography,
perspective hardware, pointer depth and scroll reveals. Preserve semantic links,
keyboard tabs, reduced-motion behavior, manual animation pause and mobile layout.
Content stays visible if IntersectionObserver is unavailable; no scroll hijacking,
audio autoplay, mandatory entrance loader, analytics or external font requests.

## Design research

Research informed motion/composition, not copied layouts or code:

- [Lusion](https://lusion.co/): product depth and interactive storytelling.
- [Codrops Creative Hub](https://tympanus.net/codrops/hub/): motion/video demos, 3D stacks and scroll reveals.
- [Olivier Larose](https://blog.olivierlarose.com/): animation tutorials and visual rhythm.
- [Olivier's video: My Top 5 Techniques for Web Animation](https://www.youtube.com/watch?v=9eHEOAn2FOA): discovered through search; direct video retrieval was unavailable in this session.
- [Lusion on X](https://x.com/lusionltd): direct access returned 403, so no post-specific claims.
- [Astro / GitHub Pages](https://docs.astro.build/en/guides/deploy/github/).
- [Reduced motion](https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-reduced-motion).

The Outfit font retains its SIL Open Font License in `assets/OFL-Outfit.txt`.
Game artwork and engine credits retain their existing upstream provenance.
