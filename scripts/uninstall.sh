#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
bundle_id='com.shinonome.inputmethod.EnKeyBoard'
installed_app="$HOME/Library/Input Methods/EnKeyBoard.app"
data_dir="$HOME/Library/Application Support/EnKeyBoard"
receipt="$data_dir/installation.json"
if [[ "${1:-}" != '--yes' ]]; then
    print '将移除 EnKeyBoard 输入源、应用、个人词库、学习记录、偏好和本应用权限。'
    print '此脚本不会改动其他输入法或全局键盘设置。'
    print '个人词库会被删除；如需保留，请先复制 ~/Library/Application Support/EnKeyBoard。'
    read -r 'answer?输入 UNINSTALL 继续：'
    [[ "$answer" == 'UNINSTALL' ]] || exit 0
fi
tool="$PWD/.build/release/enkeyboard-source"
[[ -x "$tool" ]] || tool="$installed_app/Contents/MacOS/enkeyboard-source"
[[ -x "$tool" ]] || { print -u2 '缺少输入源清理工具，请先构建项目或恢复安装包。'; exit 1; }
"$tool" --restore-and-disable "$receipt"
pkill -x EnKeyBoard 2>/dev/null || true
if [[ -d "$installed_app" ]]; then
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$installed_app"
fi
# A manually opened preview build may also have registered this project's bundle.
if [[ -d "$PWD/dist/EnKeyBoard.app" ]]; then
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$PWD/dist/EnKeyBoard.app"
fi
if ! tccutil reset All "$bundle_id"; then
    print -u2 '权限记录重置未成功；请在系统隐私设置中手动移除 EnKeyBoard 的权限条目。'
fi
defaults delete "$bundle_id" 2>/dev/null || true
# Fixed app-owned paths. Never delete shared keyboard preferences or other IM data.
rm -rf -- "$installed_app" "$data_dir" \
    "$HOME/Library/Caches/$bundle_id" \
    "$HOME/Library/Saved Application State/$bundle_id.savedState"
rm -f -- "$HOME/Library/Preferences/$bundle_id.plist"
print 'EnKeyBoard 已移除。其他输入法和全局键盘设置未改动。'
print '如果系统输入源菜单仍显示缓存条目，注销并重新登录。项目源码和 dist 构建产物仍保留。'
