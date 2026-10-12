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
		"zh": "方向键或 WASD 走动。按 1-8 或 [ ] 切换场景。房屋、树、岩石和人共用同一套体积比较。人的落点是一块椭圆，不是一个点。整块椭圆到了占地北侧，才会被挡住。彩线画的是各自的占地。",
		"en": "Arrow keys or WASD to walk. Keys 1-8 or [ ] change the scene. Houses, trees, rocks, and people share one volume compare. A person's ground contact is an oval, not a point. The tree covers them only after the whole oval is north of the trunk. Colored lines draw each footprint.",
	},
	"lab.l1": {"zh": "树的北侧", "en": "North of the tree"},
	"lab.l2": {"zh": "树的东侧", "en": "East of the tree"},
	"lab.l3": {"zh": "岩石北侧", "en": "North of the rock"},
	"lab.l4": {"zh": "房屋南侧", "en": "South of the house"},
	"lab.l5": {"zh": "两棵树", "en": "Two trees"},
	"lab.l6": {"zh": "选中房屋", "en": "Selected house"},
	"lab.l7": {"zh": "木墙北侧", "en": "North of the wall"},
	"lab.l8": {"zh": "两人交错", "en": "Two people"},
	"lab.btn_l1": {"zh": "树后", "en": "Tree"},
	"lab.btn_l2": {"zh": "树侧", "en": "Side"},
	"lab.btn_l3": {"zh": "石后", "en": "Rock"},
	"lab.btn_l4": {"zh": "屋前", "en": "House"},
	"lab.btn_l5": {"zh": "双树", "en": "Trees"},
	"lab.btn_l6": {"zh": "选中", "en": "Select"},
	"lab.btn_l7": {"zh": "墙后", "en": "Wall"},
	"lab.btn_l8": {"zh": "两人", "en": "Pair"},
	"lab.expect_l1": {"zh": "椭圆整块在树干北侧时，树挡住整个人。南侧则人在前面。", "en": "When the whole oval is north of the trunk, the tree covers the person. South of it, the person is in front."},
	"lab.expect_l2": {"zh": "椭圆在树干东侧时，树冠不该挡住整个人。只取椭圆北缘的一个点会误判成在树后。", "en": "East of the trunk, the canopy should not cover the person. A single point on the oval's north rim would wrongly count as behind the trunk."},
	"lab.expect_l3": {"zh": "岩石和树用同一条规则。", "en": "Rocks use the same rule as trees."},
	"lab.expect_l4": {"zh": "南侧整个人在前，北侧整个人在后。", "en": "The whole person is in front on the south side and behind on the north side."},
	"lab.expect_l5": {"zh": "两棵树的前后稳定，不来回跳。", "en": "The two trees keep a stable order."},
	"lab.expect_l6": {"zh": "人在前面时盖住选中框，人在后面时框和房子盖住人。", "en": "Someone in front covers the selection. Someone behind is covered by the mark and the house."},
	"lab.expect_l7": {"zh": "墙按占地挡住人，不按贴图有多宽。", "en": "The wall occludes by its footprint, not by how wide the sprite is."},
	"lab.expect_l8": {"zh": "更靠近镜头的人画在前面，顺序稳定。", "en": "The person closer to the camera draws in front, and the order stays put."},
	"lab.tag_you": {"zh": "你", "en": "You"},
	"lab.tag_near": {"zh": "近", "en": "Near"},
	"lab.tag_far": {"zh": "远", "en": "Far"},
	"stress.title": {"zh": "景深压力", "en": "Depth stress"},
	"stress.warm": {"zh": "预热中。先跑旧排序，再跑两段排序。", "en": "Warming up. The old sort runs first, then the two-phase sort."},
	"stress.phase_ref": {"zh": "正在测量旧排序。", "en": "Measuring the old sort."},
	"stress.phase_new": {"zh": "正在测量两段排序。", "en": "Measuring the two-phase sort."},
	"stress.done": {
		"zh": "%d 个走动的人。旧排序平均 %.3f ms，%.1f FPS。两段排序平均 %.3f ms，%.1f FPS。",
		"en": "%d moving people. Old sort averages %.3f ms at %.1f FPS. Two-phase sort averages %.3f ms at %.1f FPS.",
	},
	"stress.help": {
		"zh": "房屋、木墙、树和岩石的比较结果会留下。只有挪动过的人会重新比较。叠在一起的才走原来的南缘判断。",
		"en": "Houses, walls, trees, and rocks keep their pair results. Only people who moved are compared again. Overlapping boxes still use the south-rim test.",
	},
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
