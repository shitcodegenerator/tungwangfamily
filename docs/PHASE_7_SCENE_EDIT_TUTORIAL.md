# 手把手：自己修改場景、地圖與像素美術（零 Godot 經驗版）

這份文件寫給**沒有用過 Godot、沒有做過遊戲**的作者。每一節都是「打開什麼 → 按什麼 → 應該看到什麼」，
照順序做就能改圖、放物件、調整建築位置，並自己驗證有沒有弄壞遊戲。
看不懂的名詞先跳到最後一節「小辭典」。做壞了也沒關係：第 1.5 節教你一行指令還原。

> 適用：Phase 7 之後的 `tungwangfamily` 專案，macOS。Windows 的差異在第 1 節註明。

---

## 0. 你需要準備什麼

| 東西 | 用途 | 怎麼取得 |
|---|---|---|
| **Godot 4.7.x** | 執行遊戲、重新匯入圖片 | macOS：`brew install --cask godot`；或到 godotengine.org 下載，把 `Godot.app` 拖進「應用程式」。本專案在終端機用 `godot` 指令，若打 `godot` 說找不到，見 1.2 |
| **終端機** | 跑驗證指令 | macOS 內建「終端機」App（Spotlight 搜尋 Terminal） |
| **Python 3 + Pillow** | 檢查圖片、跑地圖驗證 | 終端機執行 `python3 -m pip install pillow` |
| **像素繪圖軟體** | 畫圖、改圖 | 三選一：**Aseprite**（付費約 US$20，最推薦）、**LibreSprite**（免費，Aseprite 的舊版分支）、**Piskel**（免費，瀏覽器就能用 piskelapp.com） |
| **文字編輯器** | 改 `.json`、`.txt` | VS Code（免費）或內建「文字編輯」；**不要用 Word**，它會把引號改成全形 |
| **git** | 還原檔案、看改了什麼 | macOS 內建；第一次執行會要求安裝 Xcode 命令列工具，按同意即可 |

---

## 1. 第一次打開專案

### 1.1 用終端機走到專案資料夾

打開終端機，輸入（依你的實際路徑）：

```bash
cd ~/tungworld
ls
```

應該看到 `AGENTS.md  README.md  assets  docs  project.godot  scenes  scripts  tests  tools`。
之後本文件所有指令都假設你在這個資料夾裡。

### 1.2 確認 Godot 指令可用

```bash
godot --version
```

應該印出 `4.7.x.stable...`。如果說 `command not found`：

- Homebrew 安裝的：`ls /opt/homebrew/bin/godot` 存在的話，執行 `echo 'export PATH="/opt/homebrew/bin:$PATH"' >> ~/.zshrc`，關掉終端機重開。
- 手動下載 `Godot.app` 的：執行 `sudo ln -s /Applications/Godot.app/Contents/MacOS/Godot /usr/local/bin/godot`。
- Windows：把 `Godot_v4.7-stable_win64.exe` 改名成 `godot.exe`，放到專案資料夾，指令前面加 `.\`（例如 `.\godot --version`）；下面所有 `caffeinate -dis` 都拿掉。

### 1.3 用 Godot 編輯器打開專案（看一次就好）

```bash
godot --path . --editor
```

會跳出 Godot 編輯器視窗。你**不需要在編輯器裡改任何東西**——本專案的地圖與物件都是文字檔驅動的，
編輯器只用來：按右上角「▶」（或 F5）跑遊戲，以及讓它重新匯入圖片。看完可以直接關閉。

### 1.4 直接跑遊戲

```bash
godot --path .
```

遊戲視窗打開後：

| 按鍵 | 作用 |
|---|---|
| WASD／方向鍵 | 移動 |
| E | 互動 |
| J | 任務日誌；開著時 `<`／`>` 翻頁 |
| Tab、1～4 | 切換操控角色 |
| **Esc** | 打開「測試資訊」說明面板 |
| **F1** | 顯示／隱藏碰撞框（紅色方塊＝角色走不進去的區域）——改物件位置時非常有用 |
| F5 | 日夜切換 |
| F6／F7 | 存檔／讀檔 |
| Q（說明面板開著時） | 離開遊戲 |

畫面最下方有兩行**除錯列**，例如：

```
操控：哥哥（紅鬃山犬）[1]　座標 (176, 592)　格 (5, 18)　潮根城／中層樹洞街
```

- **座標 (176, 592)**：目前操控角色**腳底**的世界座標（像素）。
- **格 (5, 18)**：腳底所在的地圖格子（第 5 欄、第 18 列，從 0 開始數）。

**這兩個數字是你之後放物件、查地圖的唯一依據。** 走到想放東西的地方，把數字抄下來。

### 1.5 做壞了怎麼還原

```bash
git status            # 列出你改過的檔案
git diff 檔案路徑      # 看你到底改了什麼
git checkout -- 檔案路徑   # 把這個檔案還原成上次提交的版本
```

例：`git checkout -- assets/maps/tide_root_town_props.json`。
還原圖片也一樣。還原後記得再跑一次第 2.1 節的「重新匯入」。

---

## 2. 每次改完都要做的三件事（先學會，後面每節都會用）

### 2.1 重新匯入圖片（改過任何 PNG 之後一定要）

```bash
godot --headless --path . --import
```

會跑幾秒、印一堆字，最後回到提示符就好。**Godot 不會自動發現你換了圖**，不跑這行遊戲裡永遠是舊圖。

### 2.2 驗證地圖與資料

```bash
python3 tools/validate_map.py
```

最後一行應該是 `地圖驗證通過`。若有 `FAIL`，訊息會告訴你哪個物件在哪一格出問題（例如放在牆裡、擋住出口）。

```bash
godot --headless --path . -s res://tests/run_tests.gd
```

最後一行應該是 `--- N 通過，0 失敗 ---`。有 `FAIL` 就往上找那一行的中文說明。

### 2.3 截圖看結果（不用自己開遊戲走過去）

```bash
caffeinate -dis godot --path . --always-on-top -- "--snapshot=tide_root_town:5,18:$PWD/check.png"
```

意思：到場景 `tide_root_town`，把隊伍放在**格 (5,18)**，等畫面穩定後存成 `check.png`，然後自動關閉。
一次可以拍多張，用 `;` 隔開：

```bash
caffeinate -dis godot --path . --always-on-top -- "--snapshot=tide_root_town:5,18:$PWD/a.png;captain_room:9,8:$PWD/b.png"
```

用「預覽」App 打開 PNG，按 ⌘+ 放大看細節。

場景 id 只有四個：`tide_root_town`（潮根城主城）、`family_home`（共享家庭屋）、`captain_room`（船長房間）、`fried_food_cave`（炸物洞窟）。

---

## 3. 地圖是由什麼組成的（看懂才改得動）

一個場景 = 四層文字/圖片檔，程式在執行時把它們拼起來：

```
assets/maps/tide_root_town.txt             ← 每個字元 = 一格 32×32：哪裡能走、哪裡是牆、水、橋
assets/maps/tide_root_town_props.json      ← 大型物件（房子、拱門、燈籠、桌子）的位置、碰撞、互動
assets/props/*.png                         ← 物件的圖片（底部中央 = 接地點）
assets/tilesets/tide_root_town_tileset.png ← 地面/牆的 tile 圖（18 欄 × 8 列，每格 32×32）
```

### 3.1 看懂 `.txt` 地圖

打開 `assets/maps/tide_root_town.txt`，每一行是一列，每個字是一格：

| 字元 | 意義 | 能走？ |
|---|---|---|
| `g` | 草地 | ✔ |
| `s` | 石板路 | ✔ |
| `d` | 泥土 | ✔ |
| `r` | 樹根路 | ✔ |
| `p` | 木板 | ✔ |
| `b` | 樹枝木地板 | ✔ |
| `m` | 苔石 | ✔ |
| `=` | 橋 | ✔ |
| `\|` | 樓梯 | ✔ |
| `w` | 沙灘 | ✔ |
| `#` | 樹皮牆 | ✘ |
| `.` | 虛空（懸崖外） | ✘ |
| `c` | 雲霧 | ✘ |
| `~` | 深水 | ✘ |
| `,` | 淺水 | ✘ |
| `T` | 樹心底座 | ✘ |

**格 (x, y) 對應第 y+1 行、第 x+1 個字**（因為從 0 開始數）。例如除錯列顯示 `格 (5, 18)`，就去看第 19 行的第 6 個字。

在終端機快速查某一行（第 19 行）：

```bash
sed -n 19p assets/maps/tide_root_town.txt
```

**世界座標 ↔ 格**：座標 = 格 × 32。格 (5,18) 的左上角是 (160, 576)，中心是 (176, 592)。

### 3.2 看懂 props JSON

打開 `assets/maps/tide_root_town_props.json`，找到 `"props": [` 之後是一個一個物件，例如：

```json
{
  "texture": "town_refresh/lantern_post_v2",
  "x": 176,
  "y": 960,
  "collision": [10, 8],
  "foot_x": 60,
  "glow": true,
  "glow_x": 36,
  "glow_y": 43
}
```

| 欄位 | 意義 | 沒寫時 |
|---|---|---|
| `texture` | 圖片檔名（不含 `.png`），對應 `assets/props/<texture>.png`；`town_refresh/xxx` 表示在子資料夾 | 必填 |
| `x`、`y` | **接地點**的世界座標（不是圖片左上角）。物件會「站」在這個點上 | 必填 |
| `collision` | 走不進去的矩形 `[寬, 高]`，以接地點為底部中央；純裝飾寫 `null` | 必填 |
| `z_bias` | 顯示層級偏移：`-1` 永遠畫在角色後面（遠景、拱門）；不寫 = 依腳底高低自動前後（Y-sort） | 0 |
| `foot_x` | 接地點距圖片**左緣**幾像素（圖片不對稱時用，例如燈柱在右邊） | 圖片寬 ÷ 2 |
| `foot_inset` | 接地線距圖片**底緣**幾像素（圖片底部畫了地面、或想把整張圖往下移） | 0 |
| `glow` + `glow_x`／`glow_y` | 夜晚光暈與其中心 | 無 |
| `interact` | 讓它可以按 E 互動，值必須存在於 `assets/dialogue/tide_root_town.json` | 無 |
| `event_id` | 世界事件目標名稱（船長房間繩圈用） | 無 |
| `note` | 給人看的備註，程式不讀 | 無 |

**接地點、foot_x、foot_inset 圖解**（`■` 是圖片，`◎` 是接地點 = 你寫的 (x, y)）：

```
預設（foot_x = 寬/2, foot_inset = 0）        foot_inset = 20：圖片往下移 20px
┌────────────┐                             ┌────────────┐
│            │                             │            │
│   圖片     │                             │   圖片     │
│            │                             │            │
└─────◎──────┘  ← 圖片底緣貼著接地線        │─────◎──────│  ← 接地線在底緣上方 20px
                                           └────────────┘     （下面 20px 是「地面」部分，
                                                                 角色站上去會畫在圖上面）
foot_x = 60（燈籠，燈柱在右邊）
┌──────╱─────┐
│     燈籠   │
│      ║     │
└──────◎─────┘  ← 接地點在距左緣 60px 的燈柱底部，不是圖片中央
```

**Y-sort 是什麼**：遊戲用「腳底 y」決定誰畫在前面——腳底越靠下（y 越大）越前面。
物件的腳底就是 `(x, y)`。所以角色走到物件下方（y 比較大）會蓋住物件，走到上方會被物件蓋住。
`z_bias: -1` 會跳出這個規則，整張永遠在角色後面。

---

## 4. 像素風格繪製入門（本專案的規格）

### 4.1 軟體設定（以 Aseprite 為例，LibreSprite 幾乎相同）

1. **新建**：File → New。寬高依用途（見 4.2）。Color Mode 選 **RGBA**，Background 選 **Transparent**。
2. **格線**：View → Grid → Grid Settings，寬高都填 **32**；View → Show Grid 打勾。畫 tile 或大型物件時格線就是地圖格。
3. **關掉平滑**：畫筆（B）工具列上方不要勾 Anti-aliasing（Aseprite 預設關）；填色桶不要勾 Antialias。
4. **縮放**：只用整數倍（100%、200%、400%...）。滑鼠滾輪縮放時左下角顯示倍率。
5. **色盤**：Window → Color Bar。先把本專案輪廓色加進去：點色盤空格 → 輸入 `#111525`。
6. **輸出**：File → Export As → 檔名 `.png`，**不要勾 Resize**（維持 100%），Aseprite 會自動存成含透明的 RGBA。
   Piskel：右側 Export → PNG → Download，Scale 保持 1×。

### 4.2 尺寸規格（照抄，不要猜）

| 用途 | 畫布尺寸 | 接地／錨點 | 備註 |
|---|---|---|---|
| 一格地面 tile | 32×32 | 無 | 四邊要能無縫相接（見 4.5） |
| 小道具（花盆、木箱、招牌） | 32×32、48×48、64×64 | 底部中央 | 底緣至少一排實心像素 |
| 大型物件（房子、拱門、攤位） | 寬 ≤ 176、高 ≤ 166 | 底部中央；有畫地面就用 `foot_inset` | 比 3 列（96px）高的建築會蓋到北邊走道，見第 7 節 |
| 主角行走表 | 192×256（4 欄 × 4 列，每格 48×64） | 每格腳底 y=61 | 列序 下／左／右／上，欄序是 4 幀走路 |
| 主角待機表 | 192×256 | 同上 | 4 幀微小呼吸，身高不變 |
| NPC／寵物表 | 240×256（5 欄 × 4 列） | 腳底 y=61 | 第 0 欄站立，第 1～4 欄行走 |
| 頭像 | 依既有頭像尺寸（看 `assets/portraits/`） | — | — |

### 4.3 畫法規則（讓新圖和舊圖看起來像同一個遊戲）

1. **輪廓**：外輪廓用深藍紫 `#111525`，1px 寬，不要用純黑。內部分界線可用比底色深兩階的顏色。
2. **光源**：固定**左上方**打光。每個物件的左上亮、右下暗；不要每張圖各自決定。
3. **色數**：一個小道具 6～12 色、大型物件 ≤ 24 色。同一種材質（木頭、石頭、葉子）盡量沿用既有圖的顏色——
   打開 `assets/props/town_refresh/harbor_crate_barrel_v2.png` 用滴管（I）吸色最快。
4. **不要漸層、不要模糊、不要半透明**：alpha 只有 0（透明）或 255（實心）。
5. **不要把陰影畫進圖裡**：角色陰影由程式加；物件下方可以畫 1～2px 的深色「接地線」，但不要畫一大片黑影。
6. **不要抗鋸齒**：斜線與圓形用階梯狀像素，不要用軟體的圓形／曲線工具開平滑。
7. **底部要「踩得住」**：物件最底下一排要有實心像素在中央附近，否則放進遊戲會像浮起來。
8. **透明背景**：不要白底、不要棋盤格圖、不要烙木地板。匯出後用 4.6 的指令檢查。

### 4.4 逐步練習：畫一個 32×32 的花盆（10 分鐘）

1. 新建 32×32、透明背景，格線 8（View → Grid → 8）。放大到 800%。
2. 用鉛筆（B），顏色 `#111525`，畫盆身輪廓：從 (8,18) 到 (23,18) 一條線是盆口上緣；左右各往下畫到 (10,30)、(21,30)；底部 (10,30)～(21,30) 連起來。座標看左下角。
3. 盆身填色：用陶土色 `#a86a3e` 填滿；左上方 3～4 個像素換成亮一階 `#c98a58`；右下沿輪廓內側一排換暗一階 `#7d4a2a`。
4. 盆口：在 y=16～18 畫一條寬一點的邊（左 7 到右 24），同樣左亮右暗。
5. 植物：從盆口往上畫 3～5 片葉子，葉綠 `#4f9a3c`、亮 `#7cc25a`、暗 `#2e6b2a`，輪廓 `#111525`。最高不超過 y=2。
6. 接地：底部 y=31 那一排、x=11～20 塗 `#111525`（1px 接地線）。
7. 檢查：縮到 100%，看整體是否還看得出是花盆；再放大檢查有沒有落單的像素、有沒有半透明點（Aseprite 用 Edit → Select All 後看色盤是否出現奇怪顏色）。
8. 匯出 `assets/props/flower_pot_test.png`（第 6 節會用到）。

### 4.5 tile（地面格）的特別要求：四邊無縫

一格草地會被上下左右重複貼，所以：

- 左邊緣那一欄像素要能接右邊緣、上接下。最簡單的檢查：Aseprite 開 View → Tiled Mode → Both，會即時顯示 3×3 平鋪；有明顯的線就是接不起來。
- 不要在四邊畫暗邊或亮邊（那是「格框」，平鋪後會變成格線）。
- 草↔石板這種交界需要**一整組**：直邊 4 個、外角 4 個、內角 4 個、中心 1 個，才能拼出任意形狀。只畫一格是不夠的。
- 本專案 tileset 是 18 欄 × 8 列（576×256），第 0 列是舊城 tile、第 6～7 列是下層廣場的新 atlas。哪一格對應哪個字元寫在 `scripts/world/tile_library.gd` 開頭的常數（例：`GRASS = (0,0)`、`STONE = (9,0)`，格式是 `(欄, 列)`）。

### 4.6 匯出後一定要做的檢查（三段指令）

第一段：檔案格式。

```bash
file assets/props/flower_pot_test.png
```

應該印出 `PNG image data, 32 x 32, 8-bit/color RGBA`。若是 `RGB`（沒有 A）代表沒有透明通道，回軟體確認 Color Mode。

第二段：透明像素與色數。把下面整段貼進終端機（包含最後的 `PY`）：

```bash
python3 - <<'PY'
from PIL import Image
im = Image.open("assets/props/flower_pot_test.png").convert("RGBA")
px = list(im.getdata())
print("尺寸", im.size, "透明", sum(p[3]==0 for p in px), "半透明", sum(0<p[3]<255 for p in px), "實心", sum(p[3]==255 for p in px))
print("四角", [im.getpixel(c) for c in [(0,0),(im.width-1,0),(0,im.height-1),(im.width-1,im.height-1)]])
print("色數", len({p[:3] for p in px if p[3]==255}))
PY
```

期望：半透明 = 0、四角的第四個數字（alpha）都是 0、色數 ≤ 24。

第三段：放在灰底上放大 6 倍看邊緣。

```bash
python3 -c "
from PIL import Image
im=Image.open('assets/props/flower_pot_test.png').convert('RGBA'); w,h=im.size
bg=Image.new('RGBA',(w,h),(120,120,120,255)); bg.alpha_composite(im)
bg.resize((w*6,h*6),Image.NEAREST).save('preview.png')"
open preview.png
```

看：邊緣有沒有白邊、有沒有漏掉的白色背景、底部是否貼齊。

---

## 5. 實作 A：換掉一張既有物件的圖（以繩圈為例）

適用：只想把某個物件畫得更好，位置與功能都不變。

1. 找檔名：在 props JSON 搜 `"texture"`，例如船長房間 `assets/maps/captain_room_props.json` 裡繩圈是 `"texture": "cap_rope_coil"` → 圖片是 `assets/props/cap_rope_coil.png`。
2. 查原圖尺寸：`file assets/props/cap_rope_coil.png` → `55 x 40`。**新圖畫一樣的尺寸**（大小不同會影響接地與事件位移）。
3. 用同檔名覆蓋：把新圖存成 `assets/props/cap_rope_coil.png`（覆蓋舊的）。**不要**改成 `cap_rope_coil_v2.png` 再去改 JSON，事件會對不到。
4. 檢查圖片（4.6 三段指令，把檔名換掉）。
5. 重新匯入：`godot --headless --path . --import`。
6. 截圖看：`caffeinate -dis godot --path . --always-on-top -- "--snapshot=captain_room:9,8:$PWD/check.png"`，打開 `check.png`，繩圈在書櫃與航海圖桌之間。
7. 跑驗證（2.2 兩行）。繩圈相關測試會自動確認它仍是 55×40、透明背景。
8. 滿意就 `git add assets/props/cap_rope_coil.png` 再 `git commit -m "art: 重畫繩圈"`；不滿意就 `git checkout -- assets/props/cap_rope_coil.png`。

> 哪些圖不能直接覆蓋：`assets/characters/`、`assets/items/`、`assets/effects/` 和舊城的 `assets/props/*.png`（沒有 `town_refresh/`、不是 `cap_` 開頭的那些）
> 是由 `tools/build_assets.py` 從 `assets/reference/` 切出來的，重跑切割器會被蓋掉。要改這些，把新圖放到 `assets/reference/incoming/`，
> 並在 `docs/ASSET_REQUEST.md` 或交給本地 AI 說明「用這張取代 X」。`assets/props/town_refresh/*_v2.png`、`cap_*.png`、洞窟 tile 是正式檔，可直接覆蓋。

---

## 6. 實作 B：在主城放一個新裝飾物（用 4.4 的花盆）

1. 在遊戲裡走到想放的位置，抄下除錯列的**座標**，例如 `座標 (448, 1088)`（下層廣場燈籠右邊的草地）。放在草地上比較不會擋路；按 F1 看紅框確認附近沒有碰撞。
2. 圖片已在 `assets/props/flower_pot_test.png`（第 4.4 節）。跑 `godot --headless --path . --import`。
3. 打開 `assets/maps/tide_root_town_props.json`，找到 `"props": [` 這個陣列的**最後一個** `}`（檔案尾端附近，長得像 `    }\n  ]\n}`）。在最後一個物件的 `}` 後面加一個逗號，再貼上：

```json
    ,
    {
      "texture": "flower_pot_test",
      "x": 448,
      "y": 1088,
      "collision": [20, 8],
      "note": "測試：作者手繪花盆"
    }
```

   注意：物件之間要有逗號，最後一個物件後面**不能**有逗號。存檔。

4. 檢查 JSON 有沒有寫壞：

   ```bash
   python3 -c "import json; json.load(open('assets/maps/tide_root_town_props.json')); print('JSON OK')"
   ```

   若出現 `Expecting ',' delimiter` 之類，就是逗號或引號的問題，訊息裡的 `line N` 告訴你第幾行。
5. `python3 tools/validate_map.py` → 應該 `地圖驗證通過`。若說物件不可站或擋住路徑，把 `y` 換到別格（每次移 32）。
6. 截圖：`caffeinate -dis godot --path . --always-on-top -- "--snapshot=tide_root_town:14,34:$PWD/check.png"`（格 = 座標 ÷ 32：448÷32=14、1088÷32=34）。
7. 實際玩一下：`godot --path .`，走到花盆四個方向：從下面靠近會被 20×8 的碰撞擋住；從上面走過去，角色會被花盆蓋住（正常，因為你在它後面）。
8. 純裝飾不想擋路 → `"collision": null`。想永遠在角色後面（例如牆上的畫）→ 加 `"z_bias": -1`。
9. 跑 `godot --headless --path . -s res://tests/run_tests.gd`。

---

## 7. 實作 C：大型建築「看起來」不對——調整畫面但不動地圖

症狀與對策（照順序試，每試一個就截圖）：

| 你看到的 | 先試 | 說明 |
|---|---|---|
| 圖片左右歪，門不在門口 | `foot_x` | 接地點應該在門的中央，量出門中央距圖片左緣幾 px |
| 圖片底部畫了地面／石板，角色站在上面卻被蓋住 | `foot_inset` = 地面的高度 | 讓接地線落在地面的上緣 |
| 建築太高，蓋住北邊整條街 | `foot_inset` 加大（整張下移） | Phase 7 的樹屋用 64；代價是門正上方那格草地會被屋頂上緣蓋到一點 |
| 角色穿過拱門、走道時被兩側根系蓋住 | `z_bias: -1` | 整張畫在角色後面；代價是站在它北邊時角色會畫在頂上 |
| 以上都不對 | 才動 `x`／`y` | 會一起移動碰撞盒；改完一定重跑 `validate_map.py` 和 F1 看紅框 |

**絕對不要**為了躲圖片去改 `.txt` 地圖的字元、改 `collision`／`collision_boxes` 數值、或把角色圖縮放——那會讓路線、存檔與測試全部壞掉。

**快速試值工具**（改 JSON → 截圖 → 自動還原 JSON，不會弄髒檔案）：

```bash
python3 tools/snapshot_props_trial.py 試1 \
  '{"town_refresh/shared_family_treehouse_v2": {"foot_inset": 48}}' \
  'tide_root_town:4,17:橋頭;tide_root_town:5,18:門上;tide_root_town:4,21:門口'
```

會在 `docs/screenshots/trials/` 產生 `試1_橋頭.png`、`試1_門上.png`、`試1_門口.png`。換數字再跑 `試2`，並排比較。
決定後再手動把數字寫進 `assets/maps/tide_root_town_props.json`。

---

## 8. 實作 D：改一格地面 tile（最小可行做法）

tileset 是切割器產生的檔案，直接改會在下次重跑 `tools/build_assets.py` 時被蓋掉；但作為**試看效果**可以這樣做：

1. 找格子：`scripts/world/tile_library.gd` 裡 `const STONE := Vector2i(9, 0)` 表示石板在第 9 欄、第 0 列。像素位置 = 欄×32、列×32 → 左上角 (288, 0)。
2. 在 Aseprite 打開 `assets/tilesets/tide_root_town_tileset.png`，格線設 32，找到 (288,0)～(319,31) 那格，畫你的新石板（遵守 4.5 無縫）。
3. 存檔（同檔名）→ `godot --headless --path . --import` → `--snapshot` 拍一張街道看。
4. 滿意的話，**把那一格另存成 32×32 的獨立 PNG** 放到 `assets/reference/incoming/`（例如 `stone_v2_32.png`），並在 `docs/ASSET_REQUEST.md` 記一行「用 incoming/stone_v2_32.png 取代 tileset (9,0)」，讓本地 AI 把它寫進切割器；否則之後會被還原。
5. 想換整組草↔石板過渡（12 格）：先畫成 4 欄 × 3 列的 128×96 小 atlas，命名清楚（`grass_stone_n`、`_ne`… 或直接畫在一張圖上附說明），放 `assets/reference/incoming/`，交給本地 AI 接進 `tile_style` 規則——這部分要改程式，不建議自己接。

---

## 9. 實作 E：Shader 特效（只讀，不建議自己寫）

Shader 是套在物件圖片上的小程式（例如舷窗水光）。你只需要知道：

- 在 props JSON 加 `"shader": "captain_room_waterlight"` 就會套用 `assets/shaders/captain_room_waterlight.gdshader`；找不到檔案只會警告，物件照常顯示。
- Shader 只能套在環境物件的圖片上，不能套角色、陰影、碰撞。
- 想要「更明顯」：打開 `.gdshader`，找 `uniform float strength = 0.08;`，改成 `0.15`，存檔即可（不用重新匯入）。
- 想要新的效果（水面、燈光脈動）：寫需求給本地 AI，附一張你想要的參考圖或影片。

---

## 10. 角色圖：改之前先讀這段

四位主角與 CC 的圖是整套的：行走表、待機表、持物／投擲表、頭像。**只換一張**會在按 E 撿東西或切換動作的瞬間變回舊造型。
如果你想重畫角色：

1. 先只畫「站立、面向下」一格 48×64，腳底在 y=61，放在 `assets/reference/incoming/`，貼在 `docs/ASSET_REQUEST.md` 請本地 AI 幫你併一張「舊 vs 新」對照圖。
2. 確認造型後再畫四方向站立 → 4 幀走路 → 待機 → 持物／投擲 → 頭像（順序寫在 `docs/ART_STYLE_LOCK.md` 3.2）。
3. 列序是 下／左／右／上；每列的臉朝向要自己看，不要信「應該一樣」。
4. 陰影不要畫進去。

---

## 11. 收工檢查清單（每次改完照跑）

```bash
godot --headless --path . --import                                  # 改過 PNG 才需要
python3 tools/validate_map.py                                        # 最後一行：地圖驗證通過
godot --headless --path . -s res://tests/run_tests.gd                # 最後一行：--- N 通過，0 失敗 ---
caffeinate -dis godot --path . --always-on-top -- --route-test --shots=$PWD/docs/screenshots   # 約 5 分鐘，會開視窗自動走一遍；結尾：結果：PASS
```

route test 會重寫 `docs/screenshots/` 裡的所有截圖；只 `git add` 你真的改到畫面的那幾張，其他用 `git checkout -- docs/screenshots/` 還原。

人工看截圖（放大 3 倍）：

- 角色停下時陰影在腳底、走路時不漂。
- 新物件底部貼地、沒有白邊、沒有方形背景。
- 沒有擋住出口、門口、樓梯（F1 看紅框）。
- 進出場景、讀檔後物件還在原位。

---

## 12. 常見錯誤對照表

| 現象 | 原因 | 解法 |
|---|---|---|
| 換了圖，遊戲裡還是舊圖 | 沒重新匯入 | `godot --headless --path . --import` |
| 物件周圍有一圈方形色塊 | 背景不是透明（白底／棋盤格／烙了地板） | 回繪圖軟體用魔術棒選背景刪除；Color Mode 要 RGBA；用 4.6 檢查四角 alpha |
| 物件邊緣有白線 | 半透明像素或軟體自動補邊 | 關抗鋸齒；Aseprite 匯出時不要 Resize；用 4.6 檢查「半透明」是否為 0 |
| 物件像浮在空中 | 圖片底部是透明或 `foot_inset` 太大 | 底部一排要有實心像素；`foot_inset` 只設成「圖裡地面的高度」 |
| 角色走到物件前面卻被蓋住 | `z_bias` 設錯或接地點太低 | 純裝飾用 `null` 碰撞且不要 `z_bias`；接地點 y 應在圖片底緣 |
| 角色可以穿過物件 | `collision` 是 `null` 或太小 | 寫 `[寬, 高]`；F1 看紅框是否覆蓋物件底部 |
| `validate_map.py` 說「不可站」「不可達」 | 物件放進牆裡或擋住唯一通道 | 換一格（x 或 y ±32），或縮小碰撞 |
| JSON 錯誤 `Expecting ',' delimiter` | 少逗號、多逗號、引號不是半形 | 用 6.4 的指令找行號；用 VS Code 不用 Word |
| 平鋪 tile 出現格線 | tile 四邊畫了亮／暗邊 | 4.5：用 Tiled Mode 檢查；邊緣顏色與中心一致 |
| 截圖是黑的或舊畫面 | 螢幕休眠／視窗被遮 | 指令前加 `caffeinate -dis`，加 `--always-on-top`，拍的時候不要切到別的視窗 |
| 單元測試 FAIL 提到尺寸 | 圖片尺寸與規格不符 | 對照 4.2 表格重存 |

---

## 13. 小辭典

| 名詞 | 白話 |
|---|---|
| Tile | 32×32 的一小格地面圖，重複貼出整張地圖 |
| Tileset／atlas | 很多 tile 排在一張大圖裡 |
| TileMap | 程式把 tile 依 `.txt` 貼出來的那一層 |
| Prop | 放在地圖上的物件（房子、燈籠、桌子），一張圖 + 可選碰撞 |
| 接地點／錨點 | 物件「站」在地上的那個點；本專案 = 圖片底部中央（可用 `foot_x`、`foot_inset` 調） |
| Y-sort | 腳底越低越前面的自動前後排序 |
| z_bias／z_index | 手動指定的層級；負數在角色後面 |
| 碰撞（collision） | 角色走不進去的隱形方塊；F1 可顯示 |
| 匯入（import） | Godot 把 PNG 轉成它內部格式的步驟；改圖後必跑 |
| headless | 不開視窗執行 Godot（跑測試、匯入用） |
| snapshot | 本專案的截圖工具：把隊伍放到指定格拍一張 |
| route test | 本專案的自動遊玩測試：自己走完全部流程並截圖 |
| RGBA | 紅綠藍 + 透明度四個通道；沒有 A 就沒有透明 |
| alpha | 透明度：0 全透明、255 全實心；中間值本專案不用 |
| Nearest | 放大時不模糊、保留像素邊緣的顯示方式（專案固定） |
