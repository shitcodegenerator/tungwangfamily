# Phase 8 資產盤點（P8.0，由 tools/audit_props_phase8.py 產生）

hidden = 圖高 − foot_inset − 碰撞高：角色貼著碰撞盒站在家具北側時，最多被圖片蓋住的像素（角色高 61）。
≤ 20 只蓋腳踝可接受；FIX 建議把碰撞高提到「圖高 − foot_inset − 16」，不加 z_bias -1。
風格（REDRAW）需人工看 docs/screenshots/phase8_baseline/contact_*.png 判定，本表只列可量測項目。

## tide_root_town（assets/maps/tide_root_town_props.json）

| texture | 尺寸 | 原點 | collision | foot_inset | z_bias | hidden | 北側可走 | event | 判定 |
|---|---|---|---|---:|---:|---:|---|---|---|
| house_window_lantern | 76×96 | (208,512) | [68, 64] | 0 | 0 | 32 | 是 |  | FIX 碰撞高 64→80（現況北側角色被蓋 32px，半身） |
| house_banner | 78×96 | (304,512) | [70, 64] | 0 | 0 | 32 | 是 |  | FIX 碰撞高 64→80（現況北側角色被蓋 32px，半身） |
| house_narrow | 56×96 | (864,512) | [50, 64] | 0 | 0 | 32 | 是 |  | FIX 碰撞高 64→80（現況北側角色被蓋 32px，半身） |
| town_refresh/shared_family_treehouse_v3 | 176×96 | (144,672) | [150, 60] | 16 | 0 | 20 | 是 |  | KEEP |
| house_tree_window | 84×96 | (720,672) | [76, 64] | 0 | 0 | 32 | 是 |  | FIX 碰撞高 64→80（現況北側角色被蓋 32px，半身） |
| house_balcony | 93×96 | (816,672) | [84, 64] | 0 | 0 | 32 | 是 |  | FIX 碰撞高 64→80（現況北側角色被蓋 32px，半身） |
| tree_heart | 176×192 | (480,448) | null | 0 | -1 |  | 否 |  | KEEP（無碰撞裝飾） |
| bulletin_board | 52×47 | (656,480) | [46, 12] | 0 | 0 | 35 | 是 |  | FIX 碰撞高 12→31（現況北側角色被蓋 35px，半身） |
| lamp_post | 44×48 ×4幀 | (368,512) | [10, 8] | 0 | 0 | 40 | 是 |  | KEEP（柱狀薄物件，自然遮擋） |
| lamp_post | 44×48 ×4幀 | (688,512) | [10, 8] | 0 | 0 | 40 | 是 |  | KEEP（柱狀薄物件，自然遮擋） |
| lamp_post | 44×48 ×4幀 | (368,608) | [10, 8] | 0 | 0 | 40 | 是 |  | KEEP（柱狀薄物件，自然遮擋） |
| lamp_post | 44×48 ×4幀 | (656,608) | [10, 8] | 0 | 0 | 40 | 是 |  | KEEP（柱狀薄物件，自然遮擋） |
| town_refresh/lantern_post_v2 | 80×81 | (176,960) | [10, 8] | 0 | 0 | 73 | 是 |  | FIX 碰撞高 8→65（現況北側角色被蓋 73px，只剩頭）；半透明像素 22.3% |
| town_refresh/lantern_post_v2 | 80×81 | (688,1056) | [10, 8] | 0 | 0 | 73 | 是 |  | FIX 碰撞高 8→65（現況北側角色被蓋 73px，只剩頭）；半透明像素 22.3% |
| town_refresh/lantern_post_v2 | 80×81 | (400,1088) | [10, 8] | 0 | 0 | 73 | 是 |  | FIX 碰撞高 8→65（現況北側角色被蓋 73px，只剩頭）；半透明像素 22.3% |
| town_refresh/lantern_post_v2 | 80×81 | (592,1056) | [10, 8] | 0 | 0 | 73 | 是 |  | FIX 碰撞高 8→65（現況北側角色被蓋 73px，只剩頭）；半透明像素 22.3% |
| signpost | 26×32 | (80,512) | [12, 8] | 0 | 0 | 24 | 是 |  | KEEP（柱狀薄物件，自然遮擋） |
| town_refresh/blank_signpost_v2 | 80×76 | (736,864) | [12, 8] | 0 | 0 | 68 | 是 |  | FIX 碰撞高 8→60（現況北側角色被蓋 68px，只剩頭）；半透明像素 15.0% |
| signpost | 26×32 | (368,96) | [12, 8] | 0 | 0 | 24 | 是 |  | KEEP（柱狀薄物件，自然遮擋） |
| fence | 64×33 | (32,544) | [64, 30] | 0 | 0 | 3 | 是 |  | KEEP |
| fence | 64×33 | (32,576) | [64, 30] | 0 | 0 | 3 | 是 |  | KEEP |
| fence | 64×33 | (928,896) | [64, 30] | 0 | 0 | 3 | 是 |  | KEEP |
| fence | 64×33 | (928,928) | [64, 30] | 0 | 0 | 3 | 是 |  | KEEP |
| canopy_gate | 106×63 | (480,64) | [106, 60] | 0 | 0 | 3 | 是 |  | KEEP |
| cloud_big | 124×54 | (240,300) | null | 0 | -1 |  | 否 |  | KEEP（無碰撞裝飾） |
| cloud_long | 128×48 | (600,300) | null | 0 | -1 |  | 否 |  | KEEP（無碰撞裝飾） |
| cloud_small | 88×37 | (110,70) | null | 0 | -1 |  | 否 |  | KEEP（無碰撞裝飾） |
| cloud_swirl | 68×64 | (880,120) | null | 0 | -1 |  | 否 |  | KEEP（無碰撞裝飾） |
| cloud_small | 88×37 | (760,340) | null | 0 | -1 |  | 否 |  | KEEP（無碰撞裝飾） |
| cloud_big | 124×54 | (440,350) | null | 0 | -1 |  | 否 |  | KEEP（無碰撞裝飾） |
| cloud_long | 128×48 | (250,130) | null | 0 | -1 |  | 否 |  | KEEP（無碰撞裝飾） |
| tree_spiral | 96×82 | (300,192) | null | 0 | -1 |  | 否 |  | KEEP（無碰撞裝飾） |
| tree_platform | 104×84 | (620,192) | null | 0 | -1 |  | 否 |  | KEEP（無碰撞裝飾） |
| harbor_berth | 128×111 | (800,876) | null | 0 | -1 |  | 否 |  | KEEP（無碰撞裝飾） |
| lily_pond | 52×41 | (140,1090) | null | 0 | -1 |  | 否 |  | KEEP（無碰撞裝飾） |
| lily_pond | 52×41 | (850,1088) | null | 0 | -1 |  | 否 |  | KEEP（無碰撞裝飾） |
| vine_branch | 42×40 | (368,448) | null | 0 | -1 |  | 否 |  | KEEP（無碰撞裝飾） |
| vine_branch | 42×40 | (608,448) | null | 0 | -1 |  | 否 |  | KEEP（無碰撞裝飾） |
| vine_branch | 42×40 | (96,400) | null | 0 | -1 |  | 否 |  | KEEP（無碰撞裝飾） |
| lily_pond | 52×41 | (544,1088) | null | 0 | -1 |  | 否 |  | KEEP（無碰撞裝飾） |
| flag_banner | 28×48 ×4幀 | (336,832) | [10, 8] | 0 | 0 | 40 | 是 |  | KEEP（柱狀薄物件，自然遮擋） |
| flag_banner | 28×48 ×4幀 | (624,832) | [10, 8] | 0 | 0 | 40 | 是 |  | KEEP（柱狀薄物件，自然遮擋） |
| flag_banner | 28×48 ×4幀 | (80,480) | [10, 8] | 0 | 0 | 40 | 否 |  | KEEP（北側為牆，走不到後面） |
| flag_banner | 28×48 ×4幀 | (880,608) | [10, 8] | 0 | 0 | 40 | 是 |  | KEEP（柱狀薄物件，自然遮擋） |
| town_refresh/breakfast_stall_v2 | 144×135 | (208,900) | [132, 119] | 0 | 0 | 16 | 否 |  | KEEP；半透明像素 10.3% |
| town_refresh/heart_fountain_v2 | 144×129 | (640,992) | [96, 96] | 0 | 0 | 33 | 是 |  | FIX 碰撞高 96→113（現況北側角色被蓋 33px，半身）；半透明像素 10.2% |
| town_refresh/root_archway_v3_base | 176×166 | (480,762) | boxes [[49, 40, -57, 0], [57, 40, 62, 0]] | 38 | 0 | 88 | 是 |  | FIX 碰撞高 40→112（現況北側角色被蓋 88px，只剩頭） |
| town_refresh/root_archway_v3_canopy | 176×166 | (480,762) | null | 38 | 1 |  | 否 |  | CHECK（無碰撞但會與角色 Y-sort） |
| town_refresh/harbor_crate_barrel_v2 | 128×102 | (672,832) | [88, 86] | 0 | 0 | 16 | 否 |  | KEEP；半透明像素 10.2% |
| town_refresh/flower_herb_bed_v2 | 144×132 | (272,1088) | [100, 96] | 0 | 0 | 36 | 是 |  | FIX 碰撞高 96→116（現況北側角色被蓋 36px，半身）；半透明像素 10.5% |

## family_home（assets/maps/family_home_props.json）

| texture | 尺寸 | 原點 | collision | foot_inset | z_bias | hidden | 北側可走 | event | 判定 |
|---|---|---|---|---:|---:|---:|---|---|---|
| int_kitchen_window | 48×48 | (118,62) | null | 0 | -1 |  | 否 |  | KEEP（無碰撞裝飾）；四角不透明 |
| int_stove | 52×102 | (66,114) | [46, 86] | 0 | 0 | 16 | 否 |  | KEEP；四角不透明 |
| int_kitchen_counter | 112×60 | (152,110) | [108, 44] | 0 | 0 | 16 | 是 |  | KEEP；四角不透明 |
| int_back_door | 52×88 | (320,96) | [48, 72] | 0 | 0 | 16 | 否 |  | KEEP；四角不透明 |
| int_yarn_cabinet | 55×90 | (430,112) | [50, 74] | 0 | 0 | 16 | 否 |  | KEEP；四角不透明 |
| int_yarn_basket | 48×38 | (470,112) | [34, 16] | 0 | 0 | 22 | 是 |  | FIX 碰撞高 16→22（現況北側角色被蓋 22px，半身）；四角不透明 |
| int_sewing_table | 80×82 | (548,176) | [76, 66] | 0 | 0 | 16 | 是 |  | KEEP；四角不透明 |
| int_fabric_shelf | 45×70 | (556,112) | [40, 24] | 0 | 0 | 46 | 是 |  | KEEP（柱狀薄物件，自然遮擋）；四角不透明 |
| int_plant | 28×40 | (500,172) | [20, 12] | 0 | 0 | 28 | 是 |  | KEEP（柱狀薄物件，自然遮擋）；四角不透明 |
| int_side_door | 38×70 | (40,212) | null | 0 | -1 |  | 否 |  | KEEP（無碰撞裝飾）；四角不透明 |
| int_side_door | 38×70 | (600,212) | null | 0 | -1 |  | 否 |  | KEEP（無碰撞裝飾）；四角不透明 |
| int_dining_table | 168×92 | (200,262) | [112, 70] | 0 | 0 | 22 | 是 |  | FIX 碰撞高 70→76（現況北側角色被蓋 22px，半身）；四角不透明 |
| int_kids_corner | 140×105 | (500,282) | [112, 58] | 0 | 0 | 47 | 是 |  | FIX 碰撞高 58→89（現況北側角色被蓋 47px，只剩頭）；四角不透明 |

## captain_room（assets/maps/captain_room_props.json）

| texture | 尺寸 | 原點 | collision | foot_inset | z_bias | hidden | 北側可走 | event | 判定 |
|---|---|---|---|---:|---:|---:|---|---|---|
| cap_wall_map_v3 | 102×78 | (150,70) | null | 0 | -1 |  | 否 |  | KEEP（無碰撞裝飾） |
| cap_hanging_lantern_v3 | 45×78 | (300,78) | null | 0 | -1 |  | 否 |  | KEEP（無碰撞裝飾） |
| cap_painting_v3 | 48×40 | (352,76) | null | 0 | -1 |  | 否 |  | KEEP（無碰撞裝飾） |
| cap_porthole_v3 | 72×78 | (432,80) | null | 0 | -1 |  | 否 | captain_room_waterlight | KEEP（無碰撞裝飾） |
| cap_coat_rack_v3 | 65×115 | (522,128) | [40, 99] | 0 | 0 | 16 | 否 |  | KEEP |
| cap_rod_rack_v3 | 108×165 | (566,196) | [72, 149] | 0 | 0 | 16 | 否 |  | KEEP |
| cap_bookshelf_v3 | 80×128 | (100,160) | [66, 112] | 0 | 0 | 16 | 否 |  | KEEP |
| cap_chart_desk_v3 | 178×120 | (300,208) | [150, 104] | 0 | 0 | 16 | 是 |  | KEEP |
| cap_chest_bench_v3 | 52×70 | (452,148) | [44, 54] | 0 | 0 | 16 | 是 |  | KEEP |
| cap_barrel_v3 | 40×48 | (84,240) | [30, 16] | 0 | 0 | 32 | 是 |  | KEEP（柱狀薄物件，自然遮擋） |
| cap_rope_coil_v3 | 55×40 | (176,176) | null | 0 | 0 |  | 否 | captain_mystery_item | KEEP（無碰撞裝飾） |
| cap_rug_v3 | 215×128 | (330,302) | null | 0 | -1 |  | 否 |  | KEEP（無碰撞裝飾） |
| cap_side_table_v3 | 140×128 | (124,322) | [110, 112] | 0 | 0 | 16 | 是 |  | KEEP |
| cap_chest_stack_v3 | 102×98 | (548,312) | [80, 56] | 0 | 0 | 42 | 是 |  | FIX 碰撞高 56→82（現況北側角色被蓋 42px，半身） |
| cap_fish_crate_v3 | 102×98 | (470,336) | [80, 80] | 0 | 0 | 18 | 是 |  | KEEP |

