#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
source_app="$PWD/dist/EnKeyBoard.app"
destination="$HOME/Library/Input Methods/EnKeyBoard.app"
[[ -d "$source_app" ]] || { print -u2 '请先运行 scripts/build.sh'; exit 1; }
mkdir -p "${destination:h}"
receipt="$HOME/Library/Application Support/EnKeyBoard/installation.json"
.build/release/enkeyboard-source --snapshot "$receipt"
# Stop only this input method before replacing its own bundle.
pkill -x EnKeyBoard 2>/dev/null || true
ditto "$source_app" "$destination"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$destination"
if [[ -x .build/release/enkeyboard-source ]]; then
    if ! .build/release/enkeyboard-source --register "$destination"; then
        print -u2 '输入源注册或分类检查未通过，安装未完成。请修正配置或注销重登录后重新安装。'
        exit 1
    fi
fi
print "已安装：$destination"
print '打开系统设置 → 键盘 → 文本输入 → 编辑 → 添加 EnKeyBoard。若未显示，请注销后重新登录。'
