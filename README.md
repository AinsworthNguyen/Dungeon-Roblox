# Dungeon Roblox - RNG Dungeon Crawler

Một dự án game Roblox thể loại **RNG + Dungeon Crawler** được phát triển bằng ngôn ngữ **Luau** theo kiến trúc ModuleService / ModuleController, quản lý và đồng bộ bằng **Rojo**.

---

## 🎮 Tính năng chính

- **Hệ thống RNG Roll & Rarity**:
  - Tỉ lệ quay đồ đa cấp độ (Common, Uncommon, Rare, Epic, Legendary, Mythic, Celestial, Divine, Secret).
  - Tích hợp hệ thống chỉ số may mắn (Luck multiplier), roll animation và hiệu ứng âm thanh.
- **Dungeon & Chiến đấu**:
  - Quản lý Dungeon theo từng đợt quái (Waves), Boss spawn và giới hạn thời gian.
  - Cơ chế chiến đấu, tính sát thương, kỹ năng (Skills / SkillBar), hiệu ứng trạng thái.
- **Hệ thống Nhân vật & Tiến trình**:
  - Quản lý túi đồ (Inventory), trang bị vũ khí, giáp, phụ kiện.
  - Hệ thống Tái sinh (Rebirth), Nhiệm vụ (Quests), Cửa hàng (Shop), Tự động bán (Auto Sell).
  - Phòng chờ tiệc (Party Room / Lobby).
- **Giao diện người dùng (UI)**:
  - Thiết kế UI hiện đại, hoạt ảnh mượt mà dựa trên Roact/Pure Luau components.

---

## 📁 Cấu trúc dự án

```text
DungeonRoblox/
├── default.project.json   # Cấu hình Rojo project
├── sourcemap.json         # Luau sourcemap hỗ trợ LSP
├── tests/                 # Unit tests & gameplay logic tests
└── src/
    ├── shared/            # Module dùng chung (ReplicatedStorage)
    │   ├── Constants.luau
    │   ├── Types.luau
    │   ├── Remotes.luau
    │   ├── ItemConfig.luau
    │   ├── RarityConfig.luau
    │   ├── DungeonConfig.luau
    │   ├── TraitConfig.luau
    │   └── SoundManager.luau
    ├── server/            # Logic phía Server (ServerScriptService)
    │   ├── init.server.luau
    │   └── Services/      # Combat, Data, Dungeon, Lobby, Quest, Rebirth, Roll, Shop...
    └── client/            # Logic phía Client (StarterPlayerScripts)
        ├── init.client.luau
        ├── Controllers/   # CombatController, PlayerController, UIController...
        └── UI/            # Các View, Modal và Theme UI
```

---

## 🛠️ Hướng dẫn cài đặt & phát triển

### 1. Yêu cầu công cụ
- [Rojo](https://rojo.space/) (v7 trở lên)
- [Visual Studio Code](https://code.visualstudio.com/) hoặc Antigravity IDE
- Extension [Luau LSP](https://marketplace.visualstudio.com/items?itemName=JohnnyMorganz.luau-lsp)

### 2. Đồng bộ với Roblox Studio
Khởi động Rojo server trong thư mục dự án:
```bash
rojo serve
```
Mở Roblox Studio, cài plugin Rojo và bấm **Connect** để đồng bộ code từ ổ đĩa vào Studio.

### 3. Tạo file game `.rbxl`
Để build trực tiếp ra file place Roblox:
```bash
rojo build -o game.rbxl
```
