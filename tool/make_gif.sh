#!/bin/sh
# Assembles build/demo_frames/*.png into doc/demo.gif (palette-optimised).
# Prerequisite: fvm spawn 3.47.7 test tool/demo/demo_test.dart
set -e
cd "$(dirname "$0")/.."
ffmpeg -y -loglevel error -framerate 12 -i build/demo_frames/f%04d.png \
  -vf "scale=360:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" \
  -loop 0 doc/demo.gif
ls -l doc/demo.gif
