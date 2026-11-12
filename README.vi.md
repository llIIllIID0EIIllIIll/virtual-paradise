# Virtual☆Paradise — Hướng dẫn nhanh (Tiếng Việt)

[English](README.md) • **Tiếng Việt**

Một theme neon cyberpunk cho **Omarchy / Hyprland**: thanh island nổi, wallpaper động, Plymouth/SDDM, cùng toàn bộ widget được phối lại theo bảng màu Miku cyan.

## Cài đặt

Yêu cầu: Arch Linux + Omarchy 4.5+, Hyprland, Quickshell.

```bash
git clone https://github.com/vuhuudo/virtual-paradise.git
cd virtual-paradise
./install.sh
```

Các chế độ:

| Lệnh | Việc làm |
|---|---|
| `./install.sh` | Cài đầy đủ, gồm Plymouth/SDDM (cần sudo) |
| `./install.sh --user-only` | Chỉ cài trong home, không cần sudo |
| `./install.sh --no-boot` | Bỏ qua Plymouth/SDDM |
| `./install.sh --sddm-only` | Chỉ cài màn hình đăng nhập |
| `./install.sh --boot-only` | Chỉ cài boot/login theme |
| `./install.sh --hook` | Chỉ áp override + layout (cho script) |
| `./install.sh diagnose` | Xuất báo cáo chẩn đoán, không ghi gì |

Installer **idempotent**: chạy lại nhiều lần vẫn hội tụ, có backup và có thể gỡ sạch.

## Tính năng chính

- **Island bar**: 3 đảo nổi, hex underlay, comet stream, rim scanner, hover pill.
- **Widgets**: clock + lịch + world clock, weather (opt-in), vitals, CPU temp/Cooler Boost, micro, mạng, audio, pin, updates, tray, indicators, Tools.
- **Hiệu ứng**: viền gradient xoay, glitch death, Matrix, hex spotlight, cursor/edge glow.
- **Wallpaper động**: 7 video, chuyển bằng `SUPER+ALT+N` / `SUPER+ALT+SHIFT+N`; bật/tắt bằng `SUPER+ALT+W`.
- **Boot/login**: Plymouth, SDDM và session splash dùng cùng artwork.
- **An toàn**: override layer ghi lại file đã sửa, backup/restore, manifest chống xoá file người dùng, `shell.json` ghi atomic, khoá flock.
- **Cập nhật**: plugin pin/verify/rollback, hook sửa bar sau update.

## Phím tắt nhanh

| Phím | Việc |
|---|---|
| `SUPER + ALT + N` | Wallpaper động tiếp theo |
| `SUPER + ALT + SHIFT + N` | Wallpaper động trước |
| `SUPER + ALT + W` | Bật/tắt wallpaper động |
| `SUPER + ALT + C` | Bật/tắt Cooler Boost |
| `SUPER + ALT + Q` | Đóng cửa sổ kiểu glitch death |
| `SUPER + backslash` | Matrix screensaver |
| `SUPER + SHIFT + K` | Cast màn hình |
| `SUPER + SHIFT + R` | Reload config |
| `SUPER + CTRL + T` | Menu theme của Omarchy |

Xem đầy đủ trong [KEYBINDINGS.md](KEYBINDINGS.md).

## Cài đặt trong shell

Mở **Tools** trên thanh bar → biểu tượng **bánh răng**. Từ đây có thể:

- **Gap effects** mặc định bật; **Hover glow** và **Reduced motion** mặc định
  tắt (chỉnh trong `shell.json` nếu cần).
- **Custom theme**: 8 role — Accent, Secondary, Tertiary, Warm, Pink, Urgent,
  Background, Text. Chọn ô role rồi bấm một màu trên bảng màu trực quan (hoặc
  nhập hex). Mỗi lần bấm áp dụng ngay: palette.json được ghi qua
  `vp-palette.sh`, bar đổi màu sau khoảng 0,3 giây, không cần Apply và không
  restart shell. Có **Undo / Redo / Reset** (`Ctrl+Z`, `Ctrl+Shift+Z`), cảnh
  báo contrast Text/BG, và điều hướng bàn phím Tab + mũi tên + Enter. File
  theme được ghi trong lúc sửa, nhưng refresh toàn shell hoãn đến khi đóng
  panel để Undo/Redo còn dùng được. Có ô **seed** và nút Analogous/Complement/
  Triad để sinh role phụ, nút **BG / Text** tạo nền/chữ dễ đọc, card preview
  xem trước trên mẫu bar/terminal, và chế độ Normal/Deutan/Protan để kiểm tra
  khả năng nhìn màu.
- **Saved themes**: đặt tên rồi **Save**, bấm tên để load, hoặc **Import** file
  JSON. Theme lưu tại `~/.local/state/virtual-paradise/themes/`; CLI tương ứng
  là `vp-theme.sh save|list|load|export|import|delete`.
- **Palette có sẵn**: Cyberpunk, Catppuccin, Tokyo Night, Gruvbox, Nord,
  Everforest, Kanagawa, Rosé Pine, Hackerman, Dracula, Mono, Neon.
- **Actions**: bật/tắt wallpaper động, âm thanh UI, diagnose, verify pins,
  repair bar, logs.
- Bật **Automatic location** cho weather (mặc định tắt vì lý do riêng tư).
- Chạy **Diagnose**, **Verify pins**, **Repair bar**, xem **Logs**.

Mọi thay đổi được ghi vào `~/.config/omarchy/shell.json` và áp dụng ngay.

## Weather

Weather không tự đoán vị trí theo IP. Lần đầu mở panel sẽ có hai lựa chọn:

- **USE MY LOCATION** — cho phép wttr.in ước lượng vị trí theo IP.
- **SET CITY** — nhập thành phố và lưu toạ độ.

## Chẩn đoán & gỡ lỗi

```bash
./install.sh diagnose
./install.sh diagnose --output ~/vp-report.txt
```

Báo cáo gồm hệ thống, git revision, XDG paths, trạng thái theme/plugin, pin drift, boot time và lỗi shell gần đây. Không cần sudo, không thay đổi cấu hình.

## Gỡ cài đặt

```bash
./uninstall.sh
```

Uninstaller sẽ khôi phục backup, gỡ Plymouth/SDDM theme, unit systemd và giữ `shell.json` nếu không có bản gốc đáng tin cậy.

## Kiểm thử

```bash
./tests/run.sh            # toàn bộ
./tests/run.sh tc1 tc30   # một số nhóm
```

Bộ test chạy trong sandbox, không chạm máy thật.

## Lộ trình

Xem [ROADMAP.md](ROADMAP.md) để biết Phase 1 đã giao gì, các lỗi đã dò và sửa,
giới hạn hiện tại và kế hoạch Phase 2 (undo/contrast/keyboard, theme di động,
live sâu hơn, artwork và tiêu chí release).

## Giấy phép

MIT — xem [LICENSE](LICENSE).
