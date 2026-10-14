extends Node

signal changed

const SAVE_PATH := "user://settings.cfg"
var code := "zh"

const TEXT := {
	"hint.idle": {
		"zh": "点空地，在右侧建造。击杀只掉金币。木坊要派村民才产木材。房屋、矛兵营、枪兵营和工坊提供对应空缺，清波后有机会补人。塔不用派人。",
		"en": "Tap empty ground, then build on the right. Kills pay gold only. The lumber mill makes wood only while villagers are stationed. Houses, barracks, and the workshop open vacancies filled after a wave. Towers need no crew.",
	},
	"flash.wave_in": {"zh": "第 %d 波来袭", "en": "Wave %d"},
	"flash.wave_clear": {
		"zh": "第 %d 波已清除。难民到来，请在 %.0f 秒内收留或派工。",
		"en": "Wave %d cleared. Refugees are waiting. Assign them within %.0f seconds.",
	},
	"flash.wave_settle": {"zh": "第 %d 波已清除。%s", "en": "Wave %d cleared. %s"},
	"flash.settle_none": {"zh": "这一波没有新人入驻。", "en": "Nobody settled this wave."},
	"flash.settle_full": {"zh": "空缺已满，没有新人。", "en": "No open vacancies."},
	"flash.mill_full": {"zh": "木坊已满（%d 人）。", "en": "The lumber mill is full (%d)."},
	"flash.mill_villager": {"zh": "木坊只收村民。", "en": "Only villagers can work the lumber mill."},
	"flash.fighter_stay": {"zh": "战斗单位留在场上。", "en": "Fighters stay on the field."},
	"flash.assign_next": {
		"zh": "再点房屋、农场、工坊或塔，把这个人收进去。",
		"en": "Now tap a house, farm, workshop, or tower to shelter them.",
	},
	"flash.cant_build": {"zh": "这里不能建造", "en": "Can't build here"},
	"flash.need_tile": {"zh": "先点一块空地。", "en": "Tap an empty tile first."},
	"flash.wall_no_staff": {"zh": "木墙不能收人。", "en": "Walls cannot shelter a villager."},
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
	"tip.help": {"zh": "玩法指南和工作台", "en": "Guide and workbench"},
	"tip.codex": {"zh": "打开玩法指南", "en": "Open the guide"},
	"tip.bench": {"zh": "打开工作台", "en": "Open the workbench"},
	"lang.switch": {"zh": "中文", "en": "EN"},
	"menu.codex": {"zh": "玩法指南", "en": "Guide"},
	"menu.bench": {"zh": "工作台", "en": "Workbench"},
	"bench.title": {"zh": "工作台", "en": "Workbench"},
	"bench.save": {"zh": "保存", "en": "Save"},
	"bench.reset": {"zh": "默认", "en": "Defaults"},
	"bench.saved": {"zh": "已保存，返回后下一局生效。", "en": "Saved. It applies when you return."},
	"bench.tab.diff": {"zh": "难度", "en": "Difficulty"},
	"bench.tab.people": {"zh": "人口", "en": "People"},
	"bench.tab.map": {"zh": "地图", "en": "Map"},
	"bench.tab.stats": {"zh": "数值", "en": "Stats"},
	"bench.tab.waves": {"zh": "波次", "en": "Waves"},
	"bench.diff_help": {"zh": "难度倍率作用在出怪数量、生命、移速和击杀金币上。", "en": "Difficulty scales spawn counts, health, speed, and kill gold."},
	"bench.people_help": {"zh": "房屋床位是村民空缺，矛兵营是矛兵空缺，枪兵营是枪兵空缺，工坊是工兵空缺。清波后，某类还有空缺时，以概率 P 入驻 1 到 min(每波上限, 空缺)。不是把村民转成兵。", "en": "House beds are villager vacancies. Barracks and the workshop open their own unit vacancies. After a wave, a type with room settles 1 to min(cap, room) with probability P."},
	"bench.map_help": {"zh": "下面这张图和对局是同一张地图：草地、道路、树、岩石、建筑和人都用对局里的画。中心空地：点一下，选出要新增的友方，预览就是这张画，点选或拖到空格。最外一圈（四个边角除外）：点击处是出怪长方形的正中，长 3 宽 1，上、下边横放，左、右边竖放，红色半透明罩盖在对应格子上。拖动红罩可挪，右键移除。上面的画也可以直接拖到地图。点保存后写入配置，下一局加载。", "en": "The picture below is the match map: the same grass, road, trees, rocks, buildings, and people. Click empty ground in the center, pick a friendly picture, and drop it there or drag it. On the outer ring, except the four corners, the click is the middle of a 3×1 enemy gate. Top and bottom lie along the edge; left and right stand upright. A red translucent mask covers those cells. Drag a mask to move it, right-click to remove it. Pictures above can also be dragged onto the map. Save writes the config for the next match."},
	"bench.palette.units": {"zh": "友方单位", "en": "Friendly units"},
	"bench.palette.builds": {"zh": "建筑", "en": "Buildings"},
	"bench.palette.props": {"zh": "景物（拖到地图）", "en": "Props (drag onto the map)"},
	"bench.prop.tree": {"zh": "树", "en": "Tree"},
	"bench.prop.rock": {"zh": "岩石", "en": "Rock"},
	"bench.spawn.tag": {"zh": "出怪", "en": "Spawn"},
	"bench.pick_title": {"zh": "在 (%d, %d) 新增友方", "en": "Add a friendly at (%d, %d)"},
	"bench.pick_help": {"zh": "点这张画就放在这一格，也可以拖到别的空格。", "en": "Click a picture to place it here, or drag it to another empty cell."},
	"bench.pick_close": {"zh": "关闭", "en": "Close"},
	"bench.map.corner": {"zh": "四个边角不设出怪点。", "en": "The four corners are not spawn gates."},
	"bench.map.spawn_set": {"zh": "出怪点已放在 (%d, %d)，这一格是正中，沿边共 3 格。", "en": "Spawn gate placed at (%d, %d). That cell is the middle of the 3."},
	"bench.map.spawn_have": {"zh": "这一格已经是出怪点的正中。", "en": "This cell is already the middle of a spawn gate."},
	"bench.map.removed": {"zh": "已移除。", "en": "Removed."},
	"bench.map.need_spawn": {"zh": "至少保留一个出怪点。", "en": "Keep at least one spawn gate."},
	"bench.map.occupied": {"zh": "这一格已经有友方或景物。", "en": "This cell already holds a unit, building, or prop."},
	"bench.map.rock": {"zh": "这是地图上的岩石，不能占用。", "en": "That rock is part of the map."},
	"bench.map.outside": {"zh": "放到地图内侧的空格上。出怪点只能在最外一圈，边角除外。", "en": "Place it on an empty interior cell. Spawn gates sit on the outer ring, not the corners."},
	"bench.map.moved": {"zh": "已放到 (%d, %d)。", "en": "Placed at (%d, %d)."},
	"bench.map.cell": {"zh": "格子 (%d, %d)", "en": "Cell (%d, %d)"},
	"bench.mode.spawn": {"zh": "刷怪点", "en": "Spawns"},
	"bench.mode.build": {"zh": "初始建筑", "en": "Opening buildings"},
	"bench.mode.unit": {"zh": "初始单位", "en": "Opening units"},
	"diff.easy": {"zh": "简单", "en": "Easy"},
	"diff.normal": {"zh": "普通", "en": "Normal"},
	"diff.hard": {"zh": "困难", "en": "Hard"},
	"panel.build": {"zh": "建造", "en": "Build"},
	"panel.sell": {"zh": "出售", "en": "Sell"},
	"panel.close": {"zh": "关闭", "en": "Close"},
	"panel.wall_info": {"zh": "木墙挡路，不能收人。", "en": "Walls block the path and do not shelter anyone."},
	"panel.station_count": {"zh": "驻岗 %d", "en": "Stationed %d"},
	"panel.crew_count": {"zh": "驻守 %d/%d", "en": "Crew %d/%d"},
	"panel.lumber_rate": {"zh": "每 %.0f 秒，每名村民 +%d 木。没人则不产。", "en": "Every %.0f s, each villager makes +%d wood. Empty makes none."},
	"panel.mill_empty": {"zh": "木坊空着不产木材。先点村民再点这里，最多 %d 人。", "en": "An empty mill makes no wood. Tap a villager, then tap here. Cap %d."},
	"panel.vacancy": {"zh": "空缺：%s × %d", "en": "Vacancies: %s × %d"},
	"panel.dismiss": {"zh": "遣散", "en": "Dismiss"},
	"panel.reassign": {"zh": "点头像选中这个人，再点另一座建筑来换岗。", "en": "Tap the portrait to select them, then tap another building."},
	"panel.empty": {"zh": "没有人躲在这里。建筑自己会工作。先点村民，再点这里可以把人收进来。", "en": "Nobody is sheltering here. This building works on its own. Tap a villager, then tap here to shelter them."},
	"villager.male": {"zh": "男村民", "en": "Male villager"},
	"villager.female": {"zh": "女村民", "en": "Female villager"},
	"unit.villager": {"zh": "村民", "en": "Villager"},
	"unit.spearman": {"zh": "矛兵", "en": "Spearman"},
	"unit.engineer": {"zh": "工兵", "en": "Engineer"},
	"unit.gunner": {"zh": "枪兵", "en": "Gunner"},
	"enemy.spear_normal": {"zh": "持矛僵尸", "en": "Spear zombie"},
	"enemy.spear_fast": {"zh": "迅捷僵尸", "en": "Fast zombie"},
	"enemy.spear_infected": {"zh": "被感染的村民", "en": "Infected villager"},
	"enemy.shooter_elite": {"zh": "持枪壮汉", "en": "Gun brute"},
	"enemy.shooter_boss": {"zh": "持枪首领", "en": "Gun boss"},
	"panel.building": {"zh": "建筑", "en": "Building"},
	"build.wall": {"zh": "木墙", "en": "Wall"},
	"build.spear": {"zh": "矛塔", "en": "Spear"},
	"build.fire": {"zh": "火塔", "en": "Fire"},
	"build.house": {"zh": "房屋", "en": "House"},
	"build.farm": {"zh": "农场", "en": "Farm"},
	"build.workshop": {"zh": "工坊", "en": "Workshop"},
	"build.lumber": {"zh": "木坊", "en": "Lumber mill"},
	"build.spear_barracks": {"zh": "矛兵营", "en": "Spear barracks"},
	"build.gun_barracks": {"zh": "枪兵营", "en": "Gun barracks"},
	"role.wall": {"zh": "挡路", "en": "Blocks"},
	"role.spear": {"zh": "穿刺", "en": "Pierce"},
	"role.fire": {"zh": "溅射", "en": "Splash"},
	"role.house": {"zh": "床位", "en": "Beds"},
	"role.farm": {"zh": "清波木材", "en": "Wave wood"},
	"role.workshop": {"zh": "工兵空缺", "en": "Engineer slots"},
	"role.lumber": {"zh": "驻人产木", "en": "Staffed wood"},
	"role.spear_barracks": {"zh": "矛兵空缺", "en": "Spearman slots"},
	"role.gun_barracks": {"zh": "枪兵空缺", "en": "Gunner slots"},
	"cost.wood": {"zh": "%d木", "en": "%d wood"},
	"cost.gold": {"zh": "%d金", "en": "%d gold"},
	"popup.gold": {"zh": "+%d金", "en": "+%d gold"},
	"popup.wood": {"zh": "+%d木", "en": "+%d wood"},
	"popup.assigned": {"zh": "已派人", "en": "Assigned"},
	"popup.dismissed": {"zh": "已遣散", "en": "Dismissed"},
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
		"zh": "方向键或 WASD 走动。按 1-8 或 [ ] 切换场景。每个人的落点是一块椭圆。整块椭圆到了占地北侧，才会被挡住。空心的农场和木墙用一块盖住内部的凸多边形，人走不进去。彩线画的是占地。",
		"en": "Arrow keys or WASD to walk. Keys 1-8 or [ ] change the scene. A person's ground contact is an oval. Something covers them only after the whole oval is north of its footprint. The open farm and wall use one convex polygon over the interior, and people cannot walk into it. Colored lines draw each footprint.",
	},
	"lab.l1": {"zh": "树的北侧", "en": "North of the tree"},
	"lab.l2": {"zh": "树的东侧", "en": "East of the tree"},
	"lab.l3": {"zh": "岩石北侧", "en": "North of the rock"},
	"lab.l4": {"zh": "房屋南侧", "en": "South of the house"},
	"lab.l5": {"zh": "两棵树", "en": "Two trees"},
	"lab.l6": {"zh": "选中房屋", "en": "Selected house"},
	"lab.l7": {"zh": "木墙北侧", "en": "North of the wall"},
	"lab.l8": {"zh": "两人交错", "en": "Two people"},
	"lab.l9": {"zh": "农场外沿", "en": "Outside the farm"},
	"lab.l10": {"zh": "贴着树干", "en": "Against the trunk"},
	"lab.l11": {"zh": "木墙墙角", "en": "Wall corner"},
	"lab.l12": {"zh": "密集人群", "en": "Dense crowd"},
	"lab.btn_l1": {"zh": "树后", "en": "Tree"},
	"lab.btn_l2": {"zh": "树侧", "en": "Side"},
	"lab.btn_l3": {"zh": "石后", "en": "Rock"},
	"lab.btn_l4": {"zh": "屋前", "en": "House"},
	"lab.btn_l5": {"zh": "双树", "en": "Trees"},
	"lab.btn_l6": {"zh": "选中", "en": "Select"},
	"lab.btn_l7": {"zh": "墙后", "en": "Wall"},
	"lab.btn_l8": {"zh": "两人", "en": "Pair"},
	"lab.btn_l9": {"zh": "农场", "en": "Farm"},
	"lab.btn_l10": {"zh": "贴树", "en": "Trunk"},
	"lab.btn_l11": {"zh": "墙角", "en": "Corner"},
	"lab.btn_l12": {"zh": "人群", "en": "Crowd"},
	"lab.expect_l1": {"zh": "椭圆整块在树干北侧时，树挡住整个人。南侧则人在前面。", "en": "When the whole oval is north of the trunk, the tree covers the person. South of it, the person is in front."},
	"lab.expect_l2": {"zh": "椭圆在树干东侧时，树冠不该挡住整个人。只取椭圆北缘的一个点会误判成在树后。", "en": "East of the trunk, the canopy should not cover the person. A single point on the oval's north rim would wrongly count as behind the trunk."},
	"lab.expect_l3": {"zh": "岩石和树用同一条规则。", "en": "Rocks use the same rule as trees."},
	"lab.expect_l4": {"zh": "南侧整个人在前，北侧整个人在后。", "en": "The whole person is in front on the south side and behind on the north side."},
	"lab.expect_l5": {"zh": "两棵树的前后稳定，不来回跳。", "en": "The two trees keep a stable order."},
	"lab.expect_l6": {"zh": "人在前面时盖住选中框，人在后面时框和房子盖住人。", "en": "Someone in front covers the selection. Someone behind is covered by the mark and the house."},
	"lab.expect_l7": {"zh": "墙按占地挡住人，不按贴图有多宽。", "en": "The wall occludes by its footprint, not by how wide the sprite is."},
	"lab.expect_l8": {"zh": "更靠近镜头的人画在前面，顺序稳定。", "en": "The person closer to the camera draws in front, and the order stays put."},
	"lab.expect_l9": {"zh": "农场框是实心凸多边形。人贴在外面，不能站进框里。南侧的人在整座农场前面。", "en": "The farm frame is one solid convex footprint. The person stays outside it. South of it, they draw in front of the whole farm."},
	"lab.expect_l10": {"zh": "椭圆贴着树干但不相交。北侧整个人在后，东侧贴着时人在前面。", "en": "The oval touches the trunk and does not cross it. North of the trunk the person is behind; pressed to the east, they stay in front."},
	"lab.expect_l11": {"zh": "人贴着木墙凸角的外侧。占地不相交，前后也不会绕成环。", "en": "The person is pressed against the outside of the wall corner. The footprints do not overlap, and the order does not cycle."},
	"lab.expect_l12": {"zh": "一群人保持椭圆间距。没有占地重叠，也没有前后环。", "en": "The crowd keeps the ovals apart. No footprint overlaps, and the order does not cycle."},
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
		"zh": "房屋、木墙、树和岩石的比较结果会留下。只有挪动过的人会重新比较。盒子分开就用包围盒定前后，叠在一起才做整块是否在北侧的比较。",
		"en": "Houses, walls, trees, and rocks keep their pair results. Only people who moved are compared again. Separated boxes take their order from the box. Overlapping boxes ask whether one footprint is entirely to the north.",
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
