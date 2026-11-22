#!/bin/bash
set -euo pipefail
# One-time in-project identity rename. Intentionally does not change historical
# attribution, licences, provenance, documentation archives, or projectID.
test -f control && test -f apelin/build.sh && test -d Sources && test -d AxsDaFeiYuPetPrefs
for path in Sources Headers Hooks AxsDaFeiYuPetPrefs layout tests scripts apelin .github; do
  while IFS= read -r -d '' filename; do
    case "$filename" in
      */MowangDaFeiYuPetMigration.h|*/rename_identity.sh) continue ;;
    esac
    case "$filename" in
      *.m|*.h|*.c|*.plist|*.mk|*.sh|*.py|*.json|*.xm|*.yml|*.yaml)
        sed -i \
          -e 's/AxsDaFeiYuPet/MowangDaFeiYuPet/g' \
          -e 's/axs_dafeiyupet/mowang_dafeiyupet/g' \
          -e 's/com\.axs\.dafeiyupet/com.mowang.dafeiyupet/g' \
          "${filename:?}" ;;
    esac
  done < <(find "$path" -type f -print0)
done
for filename in control tweak.json AxsDaFeiYuPetBuild.mk Makefile AxsDaFeiYuPet.plist build.sh; do
  sed -i -e 's/AxsDaFeiYuPet/MowangDaFeiYuPet/g' -e 's/axs_dafeiyupet/mowang_dafeiyupet/g' -e 's/com\.axs\.dafeiyupet/com.mowang.dafeiyupet/g' "${filename:?}"
done
# Rename descendants before their parent; check collisions before each move.
while IFS= read -r -d '' filename; do
  parent="$(dirname "$filename")"; base="$(basename "$filename")"
  target="${base//AxsDaFeiYuPet/MowangDaFeiYuPet}"
  target="${target//com.axs.dafeiyupet/com.mowang.dafeiyupet}"
  if [[ "$base" != "$target" ]]; then
    test ! -e "$parent/$target"
    mv -- "${filename:?}" "$parent/$target"
  fi
done < <(find Sources Headers Hooks AxsDaFeiYuPetPrefs layout tests scripts apelin -depth \( -name '*AxsDaFeiYuPet*' -o -name '*com.axs.dafeiyupet*' \) -print0)
# Explicit paths avoid ambiguity with find's precedence and include named top-level entries.
for filename in AxsDaFeiYuPet.plist AxsDaFeiYuPetBuild.mk AxsDaFeiYuPetPrefs; do
  if [[ -e "$filename" ]]; then
    target="${filename//AxsDaFeiYuPet/MowangDaFeiYuPet}"
    test ! -e "$target"
    mv -- "${filename:?}" "$target"
  fi
done
