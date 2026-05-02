#!/usr/bin/env bash
#
# Fast debug repackager — skips the expensive `make` and reuses prebuilt artifacts.
#
# Pre-req:  ./build.sh dylib    (produces packages/RyukGram.dylib)
# Then:     ./build-fast.sh     (or ./build-fast.sh sideload)
#
# Reuses (rebuilds only if missing):
#   - packages/RyukGram.dylib              ← from ./build.sh dylib
#   - packages/RyukGram.bundle             ← FFmpegKit bundle, cached after first build
#   - packages/zxPluginsInject.dylib       ← cached after first build
#   - packages/cache/FLEXing.dylib + libflex.dylib  ← optional, used if present
#
# Always rebuilds (cheap):
#   - localization lproj inside the bundle (so .strings edits ship)
#   - the IPA itself (cyan + Safari ext inject + ipapatch)

set -e

if [ -z "$THEOS" ]; then
    if [ -d "$HOME/theos" ]; then
        export THEOS="$HOME/theos"
    else
        echo -e '\033[1m\033[0;31mTHEOS not set and ~/theos not found.\033[0m' >&2
        exit 1
    fi
fi

OUT_IPA="packages/RyukGram-sideloaded-debug.ipa"
COMPRESSION=9     # match ./build.sh sideload — 0 makes the IPA ~580MB instead of ~310MB

copy_localization_into_bundle() {
    local DEST="$1"
    local SRC="src/Localization/Resources"
    [ -d "$SRC" ] || return 0
    mkdir -p "$DEST"
    for lproj in "$SRC"/*.lproj; do
        [ -d "$lproj" ] || continue
        rm -rf "$DEST/$(basename "$lproj")"
        cp -R "$lproj" "$DEST/"
    done
}

copy_bundle_assets() {
    local DEST="$1"
    local SRC="src/BundleAssets"
    [ -d "$SRC" ] || return 0
    mkdir -p "$DEST"
    find "$SRC" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.pdf' \) \
        -exec cp {} "$DEST/" \;
}

# Build packages/RyukGram.bundle from scratch (FFmpegKit + localization + assets).
# Only called when bundle is missing or --rebuild-bundle is passed.
build_full_bundle() {
    local BUNDLE_PATH="packages/RyukGram.bundle"
    rm -rf "$BUNDLE_PATH"
    mkdir -p "$BUNDLE_PATH"
    copy_localization_into_bundle "$BUNDLE_PATH"
    copy_bundle_assets "$BUNDLE_PATH"

    if [ -d "modules/ffmpegkit/ffmpegkit.framework" ]; then
        echo -e '\033[1m\033[32mBuilding RyukGram.bundle (FFmpegKit)\033[0m'
        for fw in modules/ffmpegkit/*.framework; do
            cp -R "$fw" "$BUNDLE_PATH/"
        done
        local LIBS="libavutil libavcodec libavformat libavfilter libavdevice libswresample libswscale"
        for lib in $LIBS; do
            mv "$BUNDLE_PATH/${lib}.framework" "$BUNDLE_PATH/${lib}_sci.framework"
            install_name_tool -id "@rpath/${lib}_sci.framework/${lib}" \
                "$BUNDLE_PATH/${lib}_sci.framework/${lib}"
        done
        for target in "$BUNDLE_PATH/ffmpegkit.framework/ffmpegkit" \
                      "$BUNDLE_PATH"/libav*_sci.framework/libav* \
                      "$BUNDLE_PATH"/libsw*_sci.framework/libsw*; do
            [ -f "$target" ] || continue
            for lib in $LIBS; do
                install_name_tool -change \
                    "@rpath/${lib}.framework/${lib}" \
                    "@rpath/${lib}_sci.framework/${lib}" \
                    "$target" 2>/dev/null || true
            done
        done
        install_name_tool -add_rpath @loader_path/.. \
            "$BUNDLE_PATH/ffmpegkit.framework/ffmpegkit" 2>/dev/null || true
    fi
}

build_zxpi_if_missing() {
    if [ -f "packages/zxPluginsInject.dylib" ]; then
        return
    fi
    echo -e '\033[1m\033[32mBuilding zxPluginsInject.dylib (one-time)\033[0m'
    local MOD_DIR="modules/zxPluginsInject"
    local DYLIB_OUT="$MOD_DIR/.theos/obj/zxPluginsInject.dylib"
    ( cd "$MOD_DIR" && make FINALPACKAGE=1 >/dev/null )
    [ -f "$DYLIB_OUT" ] || { echo -e '\033[1m\033[0;31mzxPluginsInject build failed\033[0m' >&2; exit 1; }
    mkdir -p packages
    cp "$DYLIB_OUT" packages/zxPluginsInject.dylib
    install_name_tool -id "@rpath/zxPluginsInject.dylib" \
        packages/zxPluginsInject.dylib 2>/dev/null || true
}

# ---- arg parse ----
REBUILD_BUNDLE=0
for arg in "$@"; do
    case "$arg" in
        --rebuild-bundle) REBUILD_BUNDLE=1 ;;
        sideload|"") ;;  # default
        *) echo "unknown arg: $arg" >&2; exit 1 ;;
    esac
done

# ---- pre-req checks ----
if [ ! -f "packages/RyukGram.dylib" ]; then
    echo -e '\033[1m\033[0;31mpackages/RyukGram.dylib missing.\033[0m'
    echo -e '\033[0;33mRun ./build.sh dylib first.\033[0m'
    exit 1
fi

if ! command -v cyan &> /dev/null; then
    echo -e '\033[1m\033[0;31mcyan not found.\033[0m install: pip install --force-reinstall https://github.com/asdfzxcvbn/pyzule-rw/archive/main.zip'
    exit 1
fi
if ! command -v ipapatch &> /dev/null; then
    echo -e '\033[1m\033[0;31mipapatch not found.\033[0m get it: https://github.com/asdfzxcvbn/ipapatch/releases/latest'
    exit 1
fi

# ---- find IG IPA ----
mkdir -p packages
ipaFile="$(find ./packages/ -maxdepth 1 -type f \( -iname '*com.burbn.instagram*.ipa' -o -iname 'Instagram*.ipa' -o -iname '[0-9]*.ipa' \) ! -iname 'RyukGram*.ipa' -exec basename {} \; 2>/dev/null | head -1)"
if [ -z "${ipaFile}" ]; then
    cwdIpa="$(find . -maxdepth 1 -type f \( -iname '*com.burbn.instagram*.ipa' -o -iname 'Instagram*.ipa' -o -iname '[0-9]*.ipa' \) 2>/dev/null | head -1)"
    if [ -n "$cwdIpa" ]; then
        mv "$cwdIpa" packages/
        ipaFile="$(basename "$cwdIpa")"
    fi
fi
if [ -z "${ipaFile}" ]; then
    echo -e '\033[1m\033[0;31mDecrypted Instagram IPA not found in ./ or ./packages/.\033[0m'
    exit 1
fi

# ---- bundle ----
if [ "$REBUILD_BUNDLE" == "1" ] || [ ! -d "packages/RyukGram.bundle" ]; then
    build_full_bundle
else
    # Fast path: refresh only localization (cheap, picks up .strings edits)
    copy_localization_into_bundle "packages/RyukGram.bundle"
    copy_bundle_assets "packages/RyukGram.bundle"
fi

# ---- zxPluginsInject ----
build_zxpi_if_missing

# ---- FLEX libs (optional) ----
FLEXPATH=""
if [ -f "packages/cache/FLEXing.dylib" ] && [ -f "packages/cache/libflex.dylib" ]; then
    FLEXPATH="packages/cache/FLEXing.dylib packages/cache/libflex.dylib"
fi

BUNDLE_ARG=""
[ -d "packages/RyukGram.bundle" ] && BUNDLE_ARG="packages/RyukGram.bundle"

# ---- cyan inject ----
echo -e '\033[1m\033[32mPackaging IPA (cyan)\033[0m'
rm -f "$OUT_IPA"
cyan -i "packages/${ipaFile}" -o "$OUT_IPA" -f packages/RyukGram.dylib $FLEXPATH $BUNDLE_ARG -c $COMPRESSION -m 15.0 -du

# ---- Safari extension ----
APPEX_SRC="extensions/OpenInstagramSafariExtension.appex"
if [ -d "$APPEX_SRC" ]; then
    echo -e '\033[1m\033[32mEmbedding Safari extension\033[0m'
    INJECT_TMP=$(mktemp -d)
    unzip -q "$OUT_IPA" -d "$INJECT_TMP"
    APP_DIR="$(find "$INJECT_TMP/Payload" -maxdepth 1 -type d -name '*.app' | head -1)"
    if [ -n "$APP_DIR" ]; then
        mkdir -p "$APP_DIR/PlugIns"
        rm -rf "$APP_DIR/PlugIns/OpenInstagramSafariExtension.appex"
        cp -R "$APPEX_SRC" "$APP_DIR/PlugIns/"
        ( cd "$INJECT_TMP" && zip -qr -${COMPRESSION} ../repacked.ipa Payload )
        mv "$INJECT_TMP/../repacked.ipa" "$OUT_IPA"
    fi
    rm -rf "$INJECT_TMP"
fi

# ---- ipapatch (zxPluginsInject LC) ----
echo -e '\033[1m\033[32mRunning ipapatch\033[0m'
ipapatch --input "$OUT_IPA" --inplace --noconfirm --dylib packages/zxPluginsInject.dylib

echo -e "\033[1m\033[32mDone!\033[0m\n\nIPA at: $(pwd)/$OUT_IPA"
