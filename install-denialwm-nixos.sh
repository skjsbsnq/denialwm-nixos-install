#!/usr/bin/env bash
# install-denialwm-nixos.sh
# 在 NixOS 上通过官方 flake 安装 Denial WM（Flutter 原生 Wayland 合成器）
#
# 用法:
#   ./install-denialwm-nixos.sh                 # 在当前目录生成 flake.nix 并 rebuild
#   ./install-denialwm-nixos.sh -d /etc/nixos   # 指定 flake 所在目录
#   ./install-denialwm-nixos.sh --host myhost   # 指定 nixosConfigurations 名称
#   ./install-denialwm-nixos.sh --dry-run       # 只生成 flake.nix,不 rebuild
#
# 注意: Denial 目前仅支持 x86_64-linux; NixOS 无官方二进制包,本脚本走官方
#       github:denialwm/denial flake 源码构建(带 cachix 缓存)。
#
# 参考: https://github.com/denialwm/denial/tree/main/packaging/nixos

set -euo pipefail

FLAKE_DIR="."
HOST="$(hostname)"
DRY_RUN=0
REBUILD=1

usage() {
    sed -n '2,15p' "$0"
    exit "${1:-0}"
}

while [ $# -gt 0 ]; do
    case "$1" in
        -d|--dir)    FLAKE_DIR="$2"; shift 2 ;;
        --host)      HOST="$2"; shift 2 ;;
        --dry-run)   DRY_RUN=1; shift ;;
        --no-rebuild) REBUILD=0; shift ;;
        -h|--help)   usage 0 ;;
        *) echo "未知参数: $1" >&2; usage 1 ;;
    esac
done

info() { printf '\033[1;34m[*]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

# ---------- 前置检查 ----------
[ "$(uname -s)" = "Linux" ] || die "仅支持 Linux"
[ "$(uname -m)" = "x86_64" ] || die "Denial 目前仅支持 x86_64-linux"
[ -f /etc/NIXOS ] || [ -f /etc/nixos/flake.nix ] || grep -qi nixos /etc/os-release 2>/dev/null \
    || warn "未检测到 NixOS 特征,仍将继续(请确认这是 NixOS 系统)"
command -v nix >/dev/null || die "未找到 nix 命令"

FLAKE_DIR="$(cd "$FLAKE_DIR" && pwd)"
FLAKE_FILE="$FLAKE_DIR/flake.nix"

# ---------- 生成/合并 flake.nix ----------
if [ -f "$FLAKE_FILE" ]; then
    warn "已存在 $FLAKE_FILE"
    info "请手动将以下内容合并进你的 flake.nix:"
    cat <<'EOF'

  nixConfig = {
    extra-substituters = [ "https://denial.cachix.org" ];
    extra-trusted-public-keys = [
      "denial.cachix.org-1:wd8YTnvPmugFrtdMJWtR1XdVknR3/g2nmBJkT+vAruo="
    ];
  };

  inputs.denial.url = "github:denialwm/denial";

  # 在 nixosConfigurations.<host>.modules 中追加:
  #   denial.nixosModules.default
  #   { programs.denial.enable = true; }
EOF
else
    info "在 $FLAKE_DIR 生成 flake.nix (host=$HOST)"
    cat > "$FLAKE_FILE" <<EOF
{
  description = "NixOS with Denial WM";

  nixConfig = {
    extra-substituters = [ "https://denial.cachix.org" ];
    extra-trusted-public-keys = [
      "denial.cachix.org-1:wd8YTnvPmugFrtdMJWtR1XdVknR3/g2nmBJkT+vAruo="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    denial.url = "github:denialwm/denial";
  };

  outputs = { nixpkgs, denial, ... }: {
    nixosConfigurations.$HOST = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # 若已有 configuration.nix,取消下一行注释:
        # ./configuration.nix
        denial.nixosModules.default
        { programs.denial.enable = true; }
      ];
    };
  };
}
EOF
    info "已写入 $FLAKE_FILE"
fi

[ "$DRY_RUN" = 1 ] && { info "dry-run 完成,未执行 rebuild"; exit 0; }
[ "$REBUILD" = 0 ] && { info "已跳过 rebuild (--no-rebuild)"; exit 0; }

# ---------- 重建 ----------
info "执行 nixos-rebuild switch (首次源码构建可能很久,cachix 命中则直接下载)"
warn "缓存未命中时官方验证曾需 >48GiB store 空间,请预留足够磁盘"
sudo nixos-rebuild switch --flake "$FLAKE_DIR#$HOST"

info "完成。注销后在显示管理器(SDDM 等)中选择 Denial 会话登录。"
info "登录前可运行: denial-session --check  自检;会话中: denialctl status"
