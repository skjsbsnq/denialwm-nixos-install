# Denial WM NixOS 一键安装脚本

在 NixOS 上通过[官方 flake](https://github.com/denialwm/denial/tree/main/packaging/nixos)安装 [Denial](https://denialwm.org) —— 一个 Flutter 原生的 Wayland 合成器。

## 用法

```bash
chmod +x install-denialwm-nixos.sh

./install-denialwm-nixos.sh                  # 在当前目录生成 flake.nix 并 rebuild
./install-denialwm-nixos.sh -d /etc/nixos    # 指定 flake 目录
./install-denialwm-nixos.sh --host myhost    # 指定 nixosConfigurations 名称
./install-denialwm-nixos.sh --dry-run        # 只生成 flake.nix,不 rebuild
./install-denialwm-nixos.sh --no-rebuild     # 生成后跳过 rebuild
```

## 脚本做了什么

1. 检查 Linux / x86_64 / nix 命令(Denial 目前仅支持 `x86_64-linux`)
2. 在目标目录生成 `flake.nix`,包含:
   - `denial.cachix.org` 二进制缓存(命中时免编译 Flutter 引擎)
   - `denial.url = "github:denialwm/denial"` input
   - `denial.nixosModules.default` + `programs.denial.enable = true`
   - 若已有 `flake.nix`,则打印需要手动合并的片段
3. `sudo nixos-rebuild switch --flake <dir>#<host>`

## 安装后

- 注销,在显示管理器(SDDM 等)中选择 **Denial** 会话
- 登录前自检:`denial-session --check`
- 会话内验证:`denialctl status` / `denialctl outputs`

## 注意

- NixOS **没有官方二进制包**,该模块从源码构建;缓存未命中时需要 **>48 GiB** store 空间
- 硬件要求:原子 KMS、GBM/EGL、OpenGL ES 3.0+(旧 GPU/简单虚拟机显示设备可能不支持)
- 可选配置见官方 README:`programs.denial.polkitAgent`、`programs.denial.ddc` 等
