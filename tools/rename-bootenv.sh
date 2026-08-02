#!/usr/bin/env bash
#===========================================================================
# Rename the boot env file uniformly to bootEnv.txt and rebuild boot.scr
#
# The u-boot bootloader executes the compiled boot.scr (from boot.cmd). The
# env filename (uEnv.txt / armbianEnv.txt) is baked into that binary, so a
# plain file rename is NOT enough: every boot.cmd that loads the env file
# must be edited and recompiled with mkimage before the image can boot.
#
# This script transforms every bootfs directory under
#   build-armbian/{armbian-files,armbian-files-alpine,armbian-files-fedora}/
#     {platform-files,different-files}/.../bootfs
#
#   - amlogic style:  uEnv.txt -> bootEnv.txt  + rebuild boot.scr,
#                     boot-emmc.scr, s905_autoscript, emmc_autoscript
#   - rockchip/allwinner style:
#                     armbianEnv.txt -> bootEnv.txt (+ .dist fallback)
#                     + rebuild boot.scr
#
# Requires: u-boot-tools (mkimage)
# Usage:    bash tools/rename-bootenv.sh
#===========================================================================

set -e

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
trees=(armbian-files armbian-files-alpine armbian-files-fedora)

command -v mkimage >/dev/null 2>&1 || {
    echo "ERROR: mkimage not found. Install u-boot-tools first." >&2
    exit 1
}

count=0

recompile_script() {
    local cmd_file="$1"
    local out_file="$2"
    [[ -f "${cmd_file}" ]] || return 0
    mkimage -A arm -O linux -T script -C none -n 'boot script' \
        -d "${cmd_file}" "${out_file}"
    echo "    recompiled ${out_file}"
}

transform_dir() {
    local dir="$1"
    cd "${dir}" || return 0

    if [[ -f "uEnv.txt" ]]; then
        # ---------- amlogic style ----------
        echo "==> ${dir} (amlogic)"
        mv -f uEnv.txt bootEnv.txt
        echo "    uEnv.txt -> bootEnv.txt"
        for f in *.cmd *.ini; do
            [[ -f "${f}" ]] || continue
            if grep -q 'uEnv\.txt' "${f}"; then
                sed -i 's/uEnv\.txt/bootEnv.txt/g' "${f}"
                echo "    sed ${f}"
            fi
        done
        recompile_script boot.cmd boot.scr
        recompile_script boot-emmc.cmd boot-emmc.scr
        recompile_script s905_autoscript.cmd s905_autoscript
        recompile_script emmc_autoscript.cmd emmc_autoscript
    elif [[ -f "armbianEnv.txt" || -f "boot.cmd" ]]; then
        # ---------- rockchip / allwinner style ----------
        echo "==> ${dir} (rockchip/allwinner)"
        if [[ -f "armbianEnv.txt.dist" ]]; then
            mv -f armbianEnv.txt.dist bootEnv.txt.dist
            echo "    armbianEnv.txt.dist -> bootEnv.txt.dist"
        fi
        if [[ -f "armbianEnv.txt" ]]; then
            mv -f armbianEnv.txt bootEnv.txt
            echo "    armbianEnv.txt -> bootEnv.txt"
        fi
        if [[ -f "boot.cmd" ]]; then
            sed -i \
                -e 's/armbianEnv\.txt\.dist/bootEnv.txt.dist/g' \
                -e 's/armbianEnv\.txt/bootEnv.txt/g' \
                boot.cmd
            echo "    sed boot.cmd"
            recompile_script boot.cmd boot.scr
        fi
    else
        echo "==> ${dir} (skip: no env file / boot.cmd)"
        return 0
    fi

    count=$((count + 1))
}

for tree in "${trees[@]}"; do
    base="${repo_root}/build-armbian/${tree}"
    [[ -d "${base}" ]] || continue

    # platform shared bootfs
    for plat in amlogic rockchip allwinner; do
        dir="${base}/platform-files/${plat}/bootfs"
        [[ -d "${dir}" ]] && transform_dir "${dir}"
    done

    # per-board bootfs
    for dir in "${base}"/different-files/*/bootfs; do
        [[ -d "${dir}" ]] || continue
        transform_dir "${dir}"
    done
done

echo ""
echo "Done. Transformed ${count} bootfs directories."
