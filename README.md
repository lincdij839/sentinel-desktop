# Sentinel Desktop

一套自己的 Wayland 桌面：Hyprland 合成器 + [43PR/dotfiles](https://github.com/43PR/dotfiles) 的 Quickshell 外壳（顶栏、设置、壁纸选择器、电源菜单、Rofi 启动器）。键盘优先。没有这份 rice 时才用自带 HUD 救急。

本仓库以 MIT 许可发布。`dot43pr/` 来自 43PR/dotfiles，保留其自己的 MIT 许可。

## 组成

| 部分 | 位置 | 说明 |
| --- | --- | --- |
| 合成器配置 | [session/hyprland.lua](./session/hyprland.lua) | 优先加载 43PR 的 `hypr/hyprland.lua`，并补上输入法与启动保护 |
| 43PR 桌面 | [dot43pr/](./dot43pr) | 顶栏、设置、壁纸选择器、主题、Rofi、Hyprlock；来自 43PR/dotfiles `3512912` |
| 外壳回退 | [shell/](./shell) | 自带 HUD，仅在 43PR 不可用时使用 |
| 仪表盘 | [dashboard/](./dashboard) | 总览 / 系统 / 网络 / 活动四页 |
| 遥测 | [scripts/telemetry.py](./scripts/telemetry.py) | 只读 `/proc`、`/sys`，不写系统、不联网 |
| 会话与安装 | [session/](./session)、[install.sh](./install.sh) | 登录界面可选会话 “Sentinel” |
| 安装镜像 | [image/](./image) | 基于 Fedora Everything netinst 的 Kickstart 与 ISO 构建脚本 |

## 快捷键

发给客户的桌面是 [43PR/dotfiles](https://github.com/43PR/dotfiles)。完整键位在 [dot43pr/hypr/keybinds.lua](./dot43pr/hypr/keybinds.lua)。

| 按键 | 作用 |
| --- | --- |
| `Super+T` / `Enter` | 终端（kitty，没有则 ptyxis） |
| `Super+D` / `S` | 应用启动器 |
| `Super+Shift+S` | 环形菜单 |
| `Super+E` / `B` | 文件管理器 / 浏览器（没有 Brave 则 Firefox） |
| `Super+Q` | 关闭窗口 |
| `Super+Space` | 浮动并居中 |
| `Super+F` | 全屏 |
| `Super+1`–`0` | 跳到工作区 1–10 |
| `Super+Shift+1`–`0` | 把窗口移到工作区 1–10 |
| `Super+H` / `J` / `L` | 焦点向左 / 下 / 右 |
| `Super+↑` | 焦点向上 |
| `Super+Shift+H/J/K/L` | 移动窗口 |
| `Super+Ctrl+H/J/K/L` | 调整窗口大小 |
| `Super+K` | 快捷键列表 |
| `Super+I` | 设置 |
| `Super+W` | 壁纸选择器 |
| `Super+Y` | 黑白主题 |
| `Super+O` | 窗口透明度 |
| `Super+Tab` | Hyprlock 锁屏 |
| `Super+`` ` | 电源菜单 |
| `Super+C` / `N` | 待办 / 通知 |
| `Super+V` | 剪贴板历史 |
| `Super+Shift+W` | 显示/隐藏顶栏 |
| `Delete` / `Shift+Delete` | 全屏截图 / 区域截图 |
| `Super+X` / `Ctrl+Space` | 切换输入法 |
| `Super+左键` / `右键` | 拖动窗口 / 缩放窗口 |

通知、电源菜单和设置都在 43PR 的 Quickshell 顶栏里。锁屏是 `hyprlock`（`Super+Tab`），提权走 `hyprpolkitagent`。合盖睡眠由安装到 `/usr` 时写入的 logind 配置处理。键盘布局跟随安装程序（`/etc/X11/xorg.conf.d/00-keyboard.conf` 或 `/etc/vconsole.conf`），也可用 `SENTINEL_KB_LAYOUT` 覆盖。自带 HUD 回退路径才用外壳自己的通知、Polkit 和 `SENTINEL_IDLE_LOCK_SEC`。

外壳控制命令：`session/sentinel-ctl <launcher|dashboard|network|files|power|lock|audio|bluetooth|display|osd|wallpaper> <toggle|lock|next>`。

登录后改动放在 `~/.config/sentinel`，注销再登录生效，不必改 `/usr`：

- `overrides.lua`：追加 Hyprland 快捷键（例如 `hl.bind(mod .. " + T", hl.dsp.exec_cmd("ptyxis"))`；`mod` 在系统配置里是 `SUPER`）
- `hyprland.lua`：若存在，整份替换系统合成器配置
- `shell/shell.qml`：若存在，用这份外壳替换系统外壳
- `monitors.conf`、`wallpaper`：缩放和壁纸，本来就在这里

发给客户的安装镜像需要**全程联网**。装好后登录选 Sentinel，应直接看到 43PR 顶栏和壁纸，`Super+T` 开终端，`Super+D` 开启动器，`Super+W` 换壁纸（把图放到 `~/Pictures/Wallpapers`）。

修主机上的代码只是开发。要把修复送到用户系统，必须走发布流水线：构建签名 RPM、用 QEMU 客户端路径验证、发布到 HTTPS 仓库。用户电脑能访问仓库并运行更新程序即可，不必逐台登录。离线设备等到重新联网并检查更新时再拿修复。

```
主机改代码
    → rpm/release.sh（构建 RPM → QEMU 验证 → 签名 → 发布）
    → HTTPS 更新仓库
    → 用户执行 sudo sentinel-update（或每日定时器）
```

`sudo sentinel-update` 只维护 Sentinel 桌面（外壳、会话、键位、更新程序）。Fedora 系统软件继续用 `sudo dnf upgrade`，两边的源互不启用、互不刷新。

本机实验室已经按这个链路接好：HTTPS 仓库在 `https://192.168.122.1:8743/`。主机上的 `sentinel-auto-publish.service` 会监视桌面源码，改完大约十几秒后自动加版本、签名并发布。客户机上的定时器每 15 分钟跑一次 `sentinel-update`。也可以立刻执行 `sudo sentinel-update`。第一次把仓库和自动发布拉起来：

```sh
rpm/setup-lab-repo.sh
sudo systemctl enable --now sentinel-repo.service sentinel-auto-publish.service
```

以后换成公网域名时，改 [rpm/update.conf](./rpm/update.conf) 再发 ISO/RPM：

```sh
SENTINEL_REPO_URL=https://updates.example.com/fedora/\$releasever/
SENTINEL_REPO_PUBLISH=/var/www/sentinel/fedora/44
```

本机发布：

```sh
sudo dnf install rpm-build createrepo_c rpm-sign gnupg2
rpm/release.sh
```

`release.sh` 会签名、用 HTTP+GPG+DNF 按 QEMU 客户的方式验仓，再拷到 `SENTINEL_REPO_PUBLISH`（默认 `publish/fedora/<版本>/`）。把 HTTPS（见 [rpm/nginx-sentinel-repo.conf](./rpm/nginx-sentinel-repo.conf)）指到这个目录。先给虚拟机试：

```sh
rpm/serve-repo.sh
# 虚拟机里：SENTINEL_REPO_URL=http://192.168.122.1:8744/ sudo sentinel-update
```

用户侧只需：

```sh
sudo sentinel-update
```

已装系统每天联网后也会由 `sentinel-update.timer` 检查。仓库不可达时不会用旧的 `/usr/src` 冒充新修复，等联网后再更新。光盘仓库仍是离线备用。要重装 43PR 桌面依赖：

```sh
sudo sentinel-update --full
```

## 在当前桌面里试运行（嵌套窗口）

需要 Hyprland、Quickshell、Python 3。不修改系统，会在当前 Wayland 会话里打开一个嵌套窗口，并使用私有 D-Bus：

```sh
sudo dnf copr enable sdegler/hyprland
sudo dnf copr enable errornointernet/quickshell
sudo dnf install hyprland quickshell python3 ptyxis grim slurp wl-clipboard fcitx5 fcitx5-chinese-addons fcitx5-gtk fcitx5-qt fcitx5-qt6 Thunar gvfs xdg-utils
./run-nested.sh
```

只看仪表盘：`./run-demo.sh`。

验证电源菜单的键盘选择与二次确认时，使用安全测试模式，避免嵌套会话误操作宿主机：

```sh
SENTINEL_POWER_DRY_RUN=1 SENTINEL_IDLE_LOCK_SEC=30 ./run-nested.sh
```

测试模式会保留锁屏操作，但把睡眠、注销、重启和关机改为面板内提示；自动锁屏测试值会钳制到至少 5 秒。

## 安装为登录会话

```sh
sudo ./install.sh                         # 装到 /usr（登录管理器默认扫描）
sudo ./install.sh --prefix /usr/local     # 本地系统目录（登录管理器需扫描）
./install.sh --prefix "$HOME/.local"      # 个人目录（登录管理器需能扫描到）
./install.sh --dry-run                    # 只打印动作
./install.sh --uninstall                  # 卸载
```

安装到 `<prefix>/share/sentinel-desktop`，并写入 `<prefix>/bin/sentinel-session` 与 `<prefix>/share/wayland-sessions/sentinel.desktop`。之后在登录界面（SDDM、GDM 等）选择 “Sentinel”。需要同时安装 `hyprland`、`quickshell`、`python3`。首次登录若还没有 `~/.config/fcitx5`，会话会写入默认配置（`Ctrl+Space` 切换拼音，不占用启动器）。

## 构建安装镜像

[image/sentinel.ks](./image/sentinel.ks) 从网络仓库安装 SDDM + Hyprland + Quickshell 等，并从安装介质复制本项目、执行 `install.sh --prefix /usr`，把 SDDM 默认会话设为 Sentinel。语言、时区、磁盘、用户由安装程序询问。

```sh
image/build-iso.sh --input Fedora-Everything-netinst-x86_64-44-1.7.iso --output sentinel-desktop.iso --with-repo
```

需要 `xorriso`、`implantisomd5`。本机若已安装 `rpm-build`、`createrepo_c`、`rpm-sign`，镜像还会带上签名仓库 `/sentinel-repo`。输入 ISO 不会被修改；输出 ISO 增加 `/sentinel.ks`、完整源码树 `/sentinel-desktop` 和可选的 `/sentinel-repo`，并让引导项带上 `inst.ks=`。安装需要联网。安装后源码复制到 `/usr/src/sentinel-desktop`，不会随安装结束删除。若光盘带仓库，Kickstart 会先导入 GPG 公钥再 `rpm -Uvh` 安装 `sentinel-desktop`。

镜像可直接作为 QEMU 的只读光驱使用，例如：

```sh
qemu-img create -f qcow2 sentinel-vm.qcow2 40G
qemu-system-x86_64 -enable-kvm -machine q35 -cpu host -m 4096 -smp 4 \
  -cdrom sentinel-desktop.iso \
  -drive if=virtio,format=qcow2,file=sentinel-vm.qcow2 \
  -nic user,model=virtio-net-pci
```

安装程序仍会询问语言、时区、用户和目标虚拟磁盘；安装阶段必须联网。完成安装后移除光盘或把虚拟磁盘放到第一启动顺序。

## 与 Fedora-Hyprland 的对应关系

桌面会话是 Sentinel 包装的 [43PR/dotfiles](https://github.com/43PR/dotfiles)（Hyprland + Quickshell），不换成 Fedora-Hyprland 的 Waybar / AGS。安装镜像的软件按 [Fedora-Hyprland](https://github.com/LinuxBeginnings/Fedora-Hyprland) 的 `00-hypr-pkgs.sh`、`fonts.sh`、`thunar.sh`、`bluetooth.sh` 取了能在 Fedora 仓库和已启用的 `sdegler/hyprland` COPR 里直接安装的部分：PipeWire、Thunar 缩略图与压缩、中英文字体、cliphist、swappy、playerctl、图像查看（Loupe）、播放器（mpv）和系统监视（btop、fastfetch）。

43PR 桌面使用 `swww`/`awww` 壁纸、`hyprlock` 锁屏和 `hyprpolkitagent`。自带 HUD 回退路径仍用外壳自己的壁纸、锁屏和 Polkit 对话框。

## 说明与限制

- `hyprland`、`quickshell` 不在 Fedora 官方仓库，来自 COPR（`sdegler/hyprland`、`errornointernet/quickshell`）；本机试运行和安装镜像都需要启用它们。镜像的 Kickstart 里这两个 COPR 仓库未做 GPG 校验。
- 产品桌面锁屏是 `hyprlock`。自带 HUD 回退才用 `shell/pam/sentinel-lock`（可用 `SENTINEL_PAM_DIR` 指向其他 PAM 目录做测试）。睡眠、重启、关机走 `systemctl`，注销才是退出 Hyprland。
- 输入法依赖本机已安装的 fcitx5；没装时顶栏不显示输入法状态，其余桌面仍可用。网络面板依赖 NetworkManager。文件面板可以复制、移动和删除，`Ctrl+G` 列出主目录和已挂载的 U 盘，`Ctrl+O` 打开 Thunar。
- 网络面板的 `Tab` 页管理已保存连接和 VPN。安装镜像包含 Firefox 和 BlueZ。首次登录的 fcitx5 配置关闭拼音的 `FirstRun`，避免弹出云拼音对话框；已有配置文件不会被覆盖。
- 配置使用 Hyprland 0.55+ 的 Lua API，避免旧 `.conf` 格式在 Hyprland 0.57 被移除后无法启动。
- 安装到 `/usr` 时会把 [43PR/dotfiles](https://github.com/43PR/dotfiles)（`3512912`）放到 `/usr/share/sentinel-desktop/dot43pr`，并链到 `~/.config/quickshell`、`~/.config/hypr`、`~/.config/43pr`、`~/.config/rofi`。壁纸目录是 `~/Pictures/Wallpapers`，并预置 [43PR 的 Wallhaven 图](https://wallhaven.cc/user/43pr)。首次登录套官方默认配色（黑底白字）；`Super+W` 换壁纸后 `theme.py` 会按壁纸生成配色。没有 `awww` 时用 `swww`。没有 Brave 时浏览器是 Firefox。这是唯一的产品桌面；没有 rice 时才用自带 HUD。
- 正式登录通过 `uwsm` 启动会话，以激活 `graphical-session.target` 与 xdg-desktop-portal；嵌套试运行仍可直接启动 Hyprland。进入登录界面前，`sentinel-relabel.service` 会把主题目录设成所有人可读并执行 `restorecon`。
- `shell/dashboard` 是指向 `../dashboard` 的符号链接，因为 Quickshell 不能导入 shell 目录之外的 QML。
- 原 dwm-titus 方案已移除。

## 测试

```sh
python3 -m unittest discover -s tests
```
