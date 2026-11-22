# Native live texture renderer

Base: clean tracked `77288f134d9b3823e342d4193dba8c7648b01644`, exported to this independent directory. Original workspace is not a dependency. No CI/remote/build/install operation was invoked for this implementation.

## Implementation

- `Sources/MowangDaFeiYuPetTextureView.{h,m}`: transparent UIView/CoreGraphics renderer, driven by existing controller CADisplayLink (30 Hz). Loads raw tex/feat PNGs once per skin, draws individual parts every frame. No thumbnail, GIF, prerecorded composite, network or second timer in the renderer.
- `Sources/MowangDaFeiYuPetController.m`: embeds noninteractive renderer inside existing UIImageView; same physical bounds, hit region, pan/tap/hold, physics, squash, scope and lifecycle. Skin refresh runs from existing preferences notification/visibility path. Live branch returns before GIF decode. Generation guard rejects outstanding old GIF results. Destroy releases renderer; chat pauses original display link. Failed asset loading logs an explicit error and uses original animation mode.
- `MowangDaFeiYuPetPrefs/Resources/MowangDaFeiYuPetRoot.plist`: original fallback plus eight texture choices, key `skin`, default `original`, existing real plist writer and Darwin notification. No device preference was changed by validation.
- `apelin/build.sh`: only explicit source list updated; not executed. Theos Makefile already discovers Sources/*.m.
- `layout/Library/Application Support/MowangDaFeiYuPet/LiveTextures`: original model/figure metadata, tex/feat and seven actual scheme override directories (DeepSeek intentionally resolves base tex/feat). 443 raw PNG files, about 15 MB; no thumbs included.

## Model interpretation

Parts `box` = x,y,width,height. Model `view` = xMin,yMin,xMax,yMax (280x280). Facial rectangles = original-art x1,y1,x2,y2; use x=128+(x-X0)*S, y=256+(y-FEET)*S, width=(x2-x1)*S, height=(y2-y1)*S. Original body's DS=.6 is already reflected in PNG pixel dimensions, not an extra drawing scale.

All 26 body assets and 27 facial assets are required/validated before accepting a skin. Standing pose intentionally omits alternate skirtSit assets at drawing time. Draw sorted global z, insert facial features at z8.7, apply multiply to skirt_shadow. Parent geometry receives body/waist/neck transforms without grouping z layers (avoids hair/face/arm z inversion). Model pivots drive body, head, arms, legs, fins, tail and ahoge motion. Normal eyes use ball/iris/highlight/lash rectangles with quadratic lidFit/rimFit clipping, one shared blink pivot and actual sleep textures at full closure. Highlights respect scheme metadata.

## Explicit limits

This is a genuine procedural multi-part affine renderer, NOT a full port of upstream deformer's grid/warp mesh. Hair/tail motion currently uses native pivoted affine transforms rather than per-vertex bending; headBack/headMid/headFeat/headFront share the neck transform rather than differential perspective deformation. Only standing maid outfit is supported. Original grid values are preserved in model but not evaluated as a mesh. Original GIF catalog is not reproduced: supported click/sleep/drag/flying/movement names map to native expressions/transforms, other actions retain idle breathing/blinking and return after 2.4 seconds. Settings states this; choose original for full old animation behavior. Full original menu titles remain, so their detailed visual contents are not implemented in live mode.

The view retains the old wide UIImageView region and aspect-fits the square model inside it; it deliberately does not resize the physics/hit region. Device visual alignment, actual Settings write/instant visible refresh, runtime CPU/memory, 30fps, interaction, lock/unlock and long-duration SpringBoard stability have NOT been tested. Syntax checks are not linking, packaging or runtime evidence.

## Checks performed

- `python3 tests/check_live_textures.py`: passed eight schemes, 424 asset mappings (26 body + 27 face per scheme), dimensions/coordinates, source fallback, unique palette texture hashes, z order, nine preferences, notification identity, branch exclusion and blink range.
- `python3 tests/check_source.py`: existing source contracts passed.
- `python3 tests/check_bootstrap.py`: existing RootHide/rootless preprocessing checks passed; its header-as-main-file pragma warnings are preexisting test invocation noise.
- Apple iPhoneOS16.5 SDK strict `clang -fsyntax-only -fobjc-arc -Wall -Wextra -Werror -Wno-unused-parameter` checks passed for renderer, integrated controller and config; Preferences header declarations used for settings controller syntax only. No linking/build was done.

Reproduce syntax-only checks from project root (adjust SDK path):

```sh
clang -target arm64e-apple-ios16.0 -isysroot /tmp/sdk/iPhoneOS16.5.sdk \
  -fobjc-arc -fsyntax-only -Wall -Wextra -Werror -Wno-unused-parameter \
  -DAPELIN_BOOTSTRAP_ROOTHIDE=1 -IHeaders -ISources \
  Sources/MowangDaFeiYuPetTextureView.m Sources/MowangDaFeiYuPetController.m \
  Sources/MowangDaFeiYuPetConfig.m
python3 tests/check_live_textures.py
```
