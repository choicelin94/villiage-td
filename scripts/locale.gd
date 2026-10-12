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
	"panel.station_count": {"zh": "驻岗 %d", "en": "Stationed %d"},
	"panel.reassign": {"zh": "点头像选中这个人，再点另一座建筑来换岗。", "en": "Tap the portrait to select them, then tap another building."},
	"panel.empty": {"zh": "没有人。先点村民，再点这里来派人。", "en": "Nobody here. Tap a villager, then tap here to assign."},
	"villager.male": {"zh": "男村民", "en": "Male villager"},
	"villager.female": {"zh": "女村民", "en": "Female villager"},
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
	"lab.open": {"zh": "景深", "en": "Depth"},
	"tip.lab": {"zh": "景深试验", "en": "Depth lab"},
	"lab.back": {"zh": "返回游戏", "en": "Back to game"},
	"lab.help": {
		"zh": "方向键或 WASD 走动。按 1–8 或 [ ] 切换场景。房屋、树和岩石都按贴图的南沿排序。人分成几条，胸口可以躲到树干后面，脚留在前面。彩线画在物件自己的深度上，站在前面的人会盖住它。",
		"en": "Arrow keys or WASD to walk. Keys 1-8 or [ ] change the scene. Houses, trees, and rocks all sort on the southern contour of their sprite. A person is split into bands, so the chest can pass behind a trunk while the feet stay in front. Colored lines use that object's depth, and someone in front covers them.",
	},
	"lab.front": {"zh": "房屋南侧", "en": "South of the house"},
	"lab.east_near": {"zh": "东角近侧", "en": "East corner, near"},
	"lab.east_far": {"zh": "东角远侧", "en": "East corner, far"},
	"lab.west_near": {"zh": "西角近侧", "en": "West corner, near"},
	"lab.west_far": {"zh": "西角远侧", "en": "West corner, far"},
	"lab.tree": {"zh": "树的北侧", "en": "North of the tree"},
	"lab.rock": {"zh": "岩石北侧", "en": "North of the rock"},
	"lab.crowd": {"zh": "多人同场", "en": "Several people"},
	"lab.btn_front": {"zh": "屋前", "en": "Front"},
	"lab.btn_east_near": {"zh": "东近", "en": "E near"},
	"lab.btn_east_far": {"zh": "东远", "en": "E far"},
	"lab.btn_west_near": {"zh": "西近", "en": "W near"},
	"lab.btn_west_far": {"zh": "西远", "en": "W far"},
	"lab.btn_tree": {"zh": "树后", "en": "Tree"},
	"lab.btn_rock": {"zh": "石后", "en": "Rock"},
	"lab.btn_crowd": {"zh": "多人", "en": "Crowd"},
	"lab.expect_front": {"zh": "脚应盖住南沿，彩线不该画在脚上。", "en": "The feet should cover the south edge. The colored line should not paint over the feet."},
	"lab.expect_near": {"zh": "脚在近侧，应盖住墙角。身子在南沿北面的部分会转到墙后。", "en": "Feet on the near side cover the corner. The part of the body north of the front edge passes behind the wall."},
	"lab.expect_far": {"zh": "人在远侧，景物应盖住人。", "en": "On the far side, the scenery should cover the person."},
	"lab.expect_crowd": {"zh": "南侧和东近侧的脚在前，东远侧的人在后。", "en": "South and east-near feet stand in front. East-far stands behind."},
	"lab.tag_you": {"zh": "你", "en": "You"},
	"lab.tag_near": {"zh": "近", "en": "Near"},
	"lab.tag_far": {"zh": "远", "en": "Far"},
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
