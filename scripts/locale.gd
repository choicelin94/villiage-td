extends Node

signal changed

const SAVE_PATH := "user://settings.cfg"
var code := "zh"

const TEXT := {
	"hint.idle": {
		"zh": "点空地，在右侧选择建筑。先点村民，再点建筑来派人。双指缩放，单指拖动地图。",
		"en": "Tap empty ground, then pick a building on the right. Tap a villager, then a building, to assign. Pinch to zoom, or use + and - on a computer. Drag to pan.",
	},
	"flash.wave_in": {"zh": "第 %d 波来袭", "en": "Wave %d"},
	"flash.wave_clear": {
		"zh": "第 %d 波已清除。难民到来，请在 %.0f 秒内收留或派工。",
		"en": "Wave %d cleared. Refugees are waiting. Assign them within %.0f seconds.",
	},
	"flash.assign_next": {
		"zh": "再点房屋、农场、工坊或塔来派人。",
		"en": "Now tap a house, farm, workshop, or tower.",
	},
	"flash.cant_build": {"zh": "这里不能建造", "en": "Can't build here"},
	"flash.need_tile": {"zh": "先点一块空地。", "en": "Tap an empty tile first."},
	"flash.wall_no_staff": {"zh": "木墙不用派人。", "en": "Walls do not need a villager."},
	"flash.wall_cap": {"zh": "木墙已达上限 %d。", "en": "Wall cap reached (%d)."},
	"flash.need_res": {"zh": "资源不足", "en": "Not enough wood or gold"},
	"end.win_title": {"zh": "村落守住了", "en": "Village held"},
	"end.win_body": {"zh": "十波僵尸已被击退。", "en": "All 10 waves were driven back."},
	"end.lose_title": {"zh": "村落陷落", "en": "Village lost"},
	"end.lose_body": {"zh": "村民全部被感染了。", "en": "Every villager was infected."},
	"tip.wood": {"zh": "木材", "en": "Wood"},
	"tip.gold": {"zh": "金币", "en": "Gold"},
	"tip.people": {"zh": "村民", "en": "People"},
	"tip.beds": {"zh": "床 已住/总数", "en": "Beds, housed/total"},
	"tip.walls": {"zh": "墙", "en": "Walls"},
	"tip.wave": {"zh": "波次", "en": "Wave"},
	"tip.refugees": {"zh": "难民倒计时", "en": "Refugees"},
	"tip.start": {"zh": "开始波次", "en": "Start wave"},
	"tip.leave": {"zh": "离开并重开", "en": "Leave and restart"},
	"tip.zoom_out": {"zh": "缩小", "en": "Zoom out"},
	"tip.zoom_in": {"zh": "放大", "en": "Zoom in"},
	"tip.again": {"zh": "再来一局", "en": "Play again"},
	"tip.lang": {"zh": "切换到英文", "en": "Switch to Chinese"},
	"lang.switch": {"zh": "中文", "en": "EN"},
	"panel.build": {"zh": "建造", "en": "Build"},
	"panel.sell": {"zh": "出售", "en": "Sell"},
	"panel.close": {"zh": "关闭", "en": "Close"},
	"panel.wall_info": {"zh": "木墙不用派人。", "en": "Walls do not take a villager."},
	"panel.staffed": {"zh": "有人值守。先点村民，再点这里来派人。", "en": "Staffed. Tap a villager, then tap here to assign."},
	"panel.empty": {"zh": "没有人。先点村民，再点这里来派人。", "en": "Empty. Tap a villager, then tap here to assign."},
	"panel.building": {"zh": "建筑", "en": "Building"},
	"build.wall": {"zh": "木墙", "en": "Wall"},
	"build.spear": {"zh": "矛塔", "en": "Spear"},
	"build.fire": {"zh": "火塔", "en": "Fire"},
	"build.house": {"zh": "房屋", "en": "House"},
	"build.farm": {"zh": "农场", "en": "Farm"},
	"build.workshop": {"zh": "工坊", "en": "Workshop"},
	"role.wall": {"zh": "挡路", "en": "Blocks"},
	"role.spear": {"zh": "穿刺", "en": "Pierce"},
	"role.fire": {"zh": "溅射", "en": "Splash"},
	"role.house": {"zh": "床位", "en": "Beds"},
	"role.farm": {"zh": "产木材", "en": "Grows wood"},
	"role.workshop": {"zh": "强化塔", "en": "Boosts towers"},
	"cost.wood": {"zh": "%d木", "en": "%d wood"},
	"cost.gold": {"zh": "%d金", "en": "%d gold"},
	"popup.gold": {"zh": "+%d金", "en": "+%d gold"},
	"popup.assigned": {"zh": "已派人", "en": "Assigned"},
	"popup.sold": {"zh": "出售 +%d木 +%d金", "en": "Sold +%d wood +%d gold"},
	"popup.infected": {"zh": "感染!", "en": "Infected!"},
	"reason.outside": {"zh": "超出地图", "en": "Outside the map"},
	"reason.cant": {"zh": "这里不能建造", "en": "Can't build here"},
	"reason.occupied": {"zh": "格子已占用", "en": "Tile occupied"},
	"reason.zombie": {"zh": "僵尸占着格子", "en": "A zombie is standing here"},
}

func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		var saved := str(cfg.get_value("ui", "lang", "zh"))
		if saved == "en" or saved == "zh":
			code = saved

func text(key: String) -> String:
	var row: Dictionary = TEXT.get(key, {})
	if row.has(code):
		return str(row[code])
	if row.has("zh"):
		return str(row["zh"])
	return key

func format(key: String, args: Array) -> String:
	return text(key) % args

func toggle() -> void:
	set_code("en" if code == "zh" else "zh")

func set_code(next: String) -> void:
	if next != "zh" and next != "en":
		return
	if next == code:
		return
	code = next
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("ui", "lang", code)
	cfg.save(SAVE_PATH)
	changed.emit()
