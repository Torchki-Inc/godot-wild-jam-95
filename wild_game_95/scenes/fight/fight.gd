extends Node3D

signal fight_finished(result: Dictionary)

enum BattleState {
	STARTING,
	PLAYER_TURN,
	SELECTING_TARGET,
	RESOLVING_TURN,
	FINISHED,
}

const SLASH_DAMAGE := 5
const SLASH_ACCURACY := 0.95

const HEAVY_STRIKE_DAMAGE := 8
const HEAVY_STRIKE_ACCURACY := 0.70

const POTION_HEAL := 20
const BOMB_DAMAGE := 8

var player_is_defending := false
var player_is_aiming := false
var player_dodges_next_attack := false
var player_accuracy_modifier := 0.0
var player_accuracy_debuff_turns := 0
var last_player_move: BattleAction.PlayerMove = BattleAction.PlayerMove.NONE

const CROSSBOW_DAMAGE := 15

@onready var main_buttons: GridContainer = $BattleUI/Root/MainButtons
@onready var attack_buttons: GridContainer = $BattleUI/Root/AttackButtons
@onready var skill_buttons: GridContainer = $BattleUI/Root/SkillButtons
@onready var item_buttons: GridContainer = $BattleUI/Root/ItemButtons
@onready var target_buttons: GridContainer = $BattleUI/Root/TargetButtons

@onready var target_button_nodes: Array[TextureButton] = [
	$BattleUI/Root/TargetButtons/Target0,
	$BattleUI/Root/TargetButtons/Target1,
	$BattleUI/Root/TargetButtons/Target2,
]

@onready var enemy_slots: Array[Node3D] = [
	$EnemySlots/Slot0,
	$EnemySlots/Slot1,
	$EnemySlots/Slot2,
]

@onready var intent_panels: Array[PanelContainer] = [
	$BattleUI/Root/IntentUI/Intent0,
	$BattleUI/Root/IntentUI/Intent1,
	$BattleUI/Root/IntentUI/Intent2,
]

@onready var intent_name_labels: Array[Label] = [
	$BattleUI/Root/IntentUI/Intent0/MarginContainer/VBoxContainer/EnemyName,
	$BattleUI/Root/IntentUI/Intent1/MarginContainer/VBoxContainer/EnemyName,
	$BattleUI/Root/IntentUI/Intent2/MarginContainer/VBoxContainer/EnemyName,
]

@onready var primary_intent_labels: Array[Label] = [
	$BattleUI/Root/IntentUI/Intent0/MarginContainer/VBoxContainer/PrimaryIntent,
	$BattleUI/Root/IntentUI/Intent1/MarginContainer/VBoxContainer/PrimaryIntent,
	$BattleUI/Root/IntentUI/Intent2/MarginContainer/VBoxContainer/PrimaryIntent,
]

@onready var bonus_intent_labels: Array[Label] = [
	$BattleUI/Root/IntentUI/Intent0/MarginContainer/VBoxContainer/BonusIntent,
	$BattleUI/Root/IntentUI/Intent1/MarginContainer/VBoxContainer/BonusIntent,
	$BattleUI/Root/IntentUI/Intent2/MarginContainer/VBoxContainer/BonusIntent,
]

@onready var player_health_bar: TextureProgressBar = (
	$BattleUI/Root/HealthUI/PlayerHealthBar
)

@onready var enemy_health_bars: Array[TextureProgressBar] = [
	$BattleUI/Root/HealthUI/EnemyHealthRow/EnemyHealthBar0,
	$BattleUI/Root/HealthUI/EnemyHealthRow/EnemyHealthBar1,
	$BattleUI/Root/HealthUI/EnemyHealthRow/EnemyHealthBar2,
]

var intent_world_offsets := [
	Vector3(0.0, 1.10, 0.0),
	Vector3(0.0, 0.92, 0.0),
	Vector3(0.0, 1.08, 0.0),
]

@onready var player_visual: Node3D = $PlayerSlot/PlayerBattleActor

var player_health: int

var encounter_data: EncounterData
var enemies: Array[BattleEnemy] = []

var battle_state: BattleState = BattleState.STARTING

var selected_move: BattleAction.PlayerMove = BattleAction.PlayerMove.NONE
var selected_target_index: int = -1

func setup(encounter: EncounterData) -> void:
	encounter_data = encounter

func _process(_delta: float) -> void:
	update_intent_positions()
	update_health_bars()

func update_intent_positions() -> void:
	var camera := $Camera3D as Camera3D
	var ui_root := $BattleUI/Root as Control

	for index in range(intent_panels.size()):
		var panel := intent_panels[index]

		if index >= enemies.size():
			panel.hide()
			continue

		var enemy := enemies[index]

		if enemy.health <= 0:
			panel.hide()
			continue

		var slot: Node3D = enemy_slots[index]

		var world_position: Vector3 = (
			slot.global_position
			+ intent_world_offsets[index]
		)

		if camera.is_position_behind(world_position):
			panel.hide()
			continue

		panel.show()

		var screen_position := camera.unproject_position(world_position)

		panel.position = Vector2(
			screen_position.x - panel.size.x * 0.5,
			screen_position.y - panel.size.y
		)

	resolve_intent_panel_overlaps(ui_root.size)

func resolve_intent_panel_overlaps(ui_size: Vector2) -> void:
	var visible_panels: Array[PanelContainer] = []

	for panel in intent_panels:
		if panel.visible:
			visible_panels.append(panel)

	if visible_panels.is_empty():
		return

	visible_panels.sort_custom(
		func(a: PanelContainer, b: PanelContainer) -> bool:
			return a.position.x < b.position.x
	)

	var spacing := 5.0
	var left_limit := 18.0
	var right_limit := ui_size.x - 18.0

	for index in range(1, visible_panels.size()):
		var previous := visible_panels[index - 1]
		var current := visible_panels[index]

		var minimum_x := (
			previous.position.x
			+ previous.size.x
			+ spacing
		)

		current.position.x = maxf(
			current.position.x,
			minimum_x
		)

	var last_panel: PanelContainer = visible_panels.back()

	var right_overflow: float = last_panel.position.x + last_panel.size.x - right_limit

	if right_overflow > 0.0:
		for panel in visible_panels:
			panel.position.x -= right_overflow

	var first_panel: PanelContainer = visible_panels.front()

	var left_overflow: float = left_limit - first_panel.position.x

	if left_overflow > 0.0:
		for panel in visible_panels:
			panel.position.x += left_overflow

	for panel in visible_panels:
		panel.position.y = clampf(
			panel.position.y,
			8.0,
			205.0 - panel.size.y
		)

func update_enemy_health_bars() -> void:
	for index in range(enemy_health_bars.size()):
		var bar: TextureProgressBar = enemy_health_bars[index]

		if index >= enemies.size():
			bar.hide()
			continue

		var enemy: BattleEnemy = enemies[index]

		if enemy.health <= 0:
			bar.hide()
			continue

		bar.show()
		bar.max_value = float(enemy.data.max_health)
		bar.value = float(enemy.health)

func update_player_health_bar() -> void:
	player_health_bar.max_value = float(
		GameState.player["max_health"]
	)
	player_health_bar.value = float(player_health)

func update_health_bars() -> void:
	update_player_health_bar()
	update_enemy_health_bars()

func arrange_enemy_slots() -> void:
	var formation: Array[Vector3] = []

	match enemies.size():
		1:
			formation = [
				Vector3(2.05, -0.02, -1.54),
			]

		2:
			formation = [
				Vector3(1.65, -0.02, -1.50),
				Vector3(2.45,  0.02, -1.58),
			]

		3:
			formation = [
				Vector3(1.45, -0.02, -1.50), # left/front
				Vector3(2.05, -0.08, -1.66), # middle/back
				Vector3(2.72, -0.01, -1.52), # right/front
			]

		_:
			formation = [
				Vector3(1.45, -0.02, -1.50),
				Vector3(2.05, -0.08, -1.66),
				Vector3(2.72, -0.01, -1.52),
			]

	for i in range(enemy_slots.size()):
		if i < formation.size():
			enemy_slots[i].position = formation[i]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	if encounter_data == null:
		push_error("Fight started without EncounterData.")
		return

	player_health = GameState.player["health"]

	for enemy_data in encounter_data.enemies:
		if enemy_data == null:
			push_warning("Encounter contains an empty enemy entry.")
			continue

		enemies.append(BattleEnemy.new(enemy_data))

	if enemies.is_empty():
		push_error("Encounter contains no valid enemies.")
		await win_fight()
		return

	spawn_battle_environment()
	spawn_enemy_models()

	choose_enemy_intents()

	await get_tree().process_frame
	update_intent_positions()

	start_player_turn()

func spawn_battle_environment() -> void:
	if encounter_data.battle_environment == null:
		return

	var environment := encounter_data.battle_environment.instantiate()
	add_child(environment)

func spawn_enemy_models() -> void:
	if enemies.size() > enemy_slots.size():
		push_error("Encounter has more enemies than available slots.")
		return

	for index in enemies.size():
		var enemy := enemies[index]

		if enemy.data.model_scene == null:
			continue

		var model := enemy.data.model_scene.instantiate() as Node3D

		if model == null:
			push_error(
				"%s has a model scene without a Node3D root."
				% enemy.data.display_name
			)
			continue

		enemy_slots[index].add_child(model)

func choose_enemy_intents() -> void:
	for enemy in enemies:
		if enemy.health <= 0:
			continue

		enemy.bonus_intent = null

		if enemy.forced_next_intent != null:
			enemy.current_intent = enemy.forced_next_intent
			enemy.forced_next_intent = null
		else:
			enemy.current_intent = choose_intent_for_enemy(enemy)

		if enemy.data.passive == EnemyData.Passive.DEMON_CROW \
		and enemy.boss_phase_two:
			enemy.bonus_intent = choose_boss_bonus_intent(enemy)

	update_intent_ui()

func choose_intent_for_enemy(enemy: BattleEnemy) -> EnemyMoveData:
	if enemy.data.moves.is_empty():
		push_warning("%s has no moves." % enemy.data.display_name)
		return null

	if enemy.data.passive != EnemyData.Passive.DEMON_CROW:
		return enemy.data.moves.pick_random()

	var possible_moves: Array[EnemyMoveData] = []

	for move in enemy.data.moves:
		if move == null:
			continue

		if move.effect == EnemyMoveData.Effect.HEAL:
			var player_showed_fear := (
				last_player_move == BattleAction.PlayerMove.DEFEND
				or last_player_move == BattleAction.PlayerMove.SMOKE_BOMB
			)

			if not player_showed_fear:
				continue

			if enemy.health >= enemy.data.max_health:
				continue

		possible_moves.append(move)

	if possible_moves.is_empty():
		return enemy.data.moves[0]

	return possible_moves.pick_random()

func choose_boss_bonus_intent(enemy: BattleEnemy) -> EnemyMoveData:
	var possible_moves: Array[EnemyMoveData] = []

	for move in enemy.data.moves:
		if move == null:
			continue

		# The second action should not begin another forced two-turn move.
		if move.effect == EnemyMoveData.Effect.TAKE_FLIGHT:
			continue

		# Do not let the boss heal as its bonus action.
		if move.effect == EnemyMoveData.Effect.HEAL:
			continue

		possible_moves.append(move)

	if possible_moves.is_empty():
		return null

	return possible_moves.pick_random()

func get_intent_text(enemy: BattleEnemy,	move: EnemyMoveData) -> String:
	if move == null:
		return "No action"

	if enemy.data.passive != EnemyData.Passive.DEMON_CROW \
	or not enemy.boss_phase_two:
		return move.display_name

	match move.effect:
		EnemyMoveData.Effect.DAMAGE, \
		EnemyMoveData.Effect.ACCURACY_DOWN:
			return "An attack"

		EnemyMoveData.Effect.POWER_UP_NEXT_ATTACK:
			return "A dark omen"

		EnemyMoveData.Effect.HEAL:
			return "Feeding"

		EnemyMoveData.Effect.TAKE_FLIGHT:
			return "Taking flight"

		_:
			return "Something dreadful"

func update_intent_ui() -> void:
	for index in range(intent_panels.size()):
		var panel := intent_panels[index]

		if index >= enemies.size():
			panel.hide()
			continue

		var enemy := enemies[index]

		if enemy.health <= 0:
			panel.hide()
			continue

		panel.show()

		intent_name_labels[index].text = enemy.data.display_name.to_upper()

		primary_intent_labels[index].text = get_intent_description(
			enemy,
			enemy.current_intent
		)

		if enemy.bonus_intent != null:
			bonus_intent_labels[index].text = (
				"+ "
				+ get_intent_description(
					enemy,
					enemy.bonus_intent
				)
			)
			bonus_intent_labels[index].show()
		else:
			bonus_intent_labels[index].hide()

func get_intent_description(
	enemy: BattleEnemy,
	move: EnemyMoveData
) -> String:
	if move == null:
		return "No action"

	# The phase-two boss conceals exact move information.
	if enemy.data.passive == EnemyData.Passive.DEMON_CROW \
	and enemy.boss_phase_two:
		return get_intent_text(enemy, move)

	match move.effect:
		EnemyMoveData.Effect.DAMAGE:
			return "%s · %d DMG" % [
				move.display_name,
				move.damage,
			]

		EnemyMoveData.Effect.ACCURACY_DOWN:
			return "%s · %d DMG · ACC ↓" % [
				move.display_name,
				move.damage,
			]

		EnemyMoveData.Effect.POWER_UP_NEXT_ATTACK:
			return "%s · POWER ↑" % move.display_name

		EnemyMoveData.Effect.STEAL_ITEM:
			return "%s · STEALS ITEM" % move.display_name

		EnemyMoveData.Effect.DODGE_NEXT_TURN:
			return "%s · DODGE ↑" % move.display_name

		EnemyMoveData.Effect.PREPARE_MOVE:
			return "%s · PREPARING" % move.display_name

		EnemyMoveData.Effect.HEAL:
			return "%s · HEAL %d" % [
				move.display_name,
				roundi(move.effect_amount),
			]

		EnemyMoveData.Effect.TAKE_FLIGHT:
			return "%s · DODGE ↑" % move.display_name

		_:
			return move.display_name

func resolve_round(player_action: BattleAction) -> void:
	if battle_state == BattleState.RESOLVING_TURN:
		return

	battle_state = BattleState.RESOLVING_TURN
	hide_all_menus()

	var actions: Array[BattleAction] = []
	actions.append(player_action)

	for enemy_index in enemies.size():
		var enemy := enemies[enemy_index]

		if enemy.health <= 0:
			continue

		if enemy.current_intent == null:
			continue

		var enemy_action := BattleAction.new()
		enemy_action.actor_type = BattleAction.ActorType.ENEMY
		enemy_action.enemy_index = enemy_index
		enemy_action.enemy_move = enemy.current_intent
		enemy_action.priority = get_enemy_priority(enemy)

		actions.append(enemy_action)

		if enemy.bonus_intent != null:
			var bonus_action := BattleAction.new()
			bonus_action.actor_type = BattleAction.ActorType.ENEMY
			bonus_action.enemy_index = enemy_index
			bonus_action.enemy_move = enemy.bonus_intent
			bonus_action.priority = get_enemy_priority(enemy) - 1

			actions.append(bonus_action)

	actions.sort_custom(
		func(a: BattleAction, b: BattleAction) -> bool:
			return a.priority > b.priority
	)

	for action in actions:
		if battle_state == BattleState.FINISHED:
			return

		if player_health <= 0:
			await lose_fight()
			return

		await execute_action(action)
		process_enemy_deaths()
		process_boss_phase_changes()

		if get_living_enemy_indices().is_empty():
			await win_fight()
			return

	await finish_round()

func get_enemy_priority(enemy: BattleEnemy) -> int:
	if enemy.data.passive == EnemyData.Passive.ACTS_FIRST:
		return 200

	return 50

func execute_action(action: BattleAction) -> void:
	match action.actor_type:
		BattleAction.ActorType.PLAYER:
			await execute_player_action(action)

		BattleAction.ActorType.ENEMY:
			await execute_enemy_action(action)

func execute_player_action(action: BattleAction) -> void:
	last_player_move = action.player_move

	match action.player_move:
		BattleAction.PlayerMove.SLASH, \
		BattleAction.PlayerMove.HEAVY_STRIKE, \
		BattleAction.PlayerMove.CROSSBOW:
			await execute_player_attack_action(action)

		BattleAction.PlayerMove.DEFEND:
			await perform_defend()

		BattleAction.PlayerMove.AIM:
			await perform_aim()

		BattleAction.PlayerMove.POTION:
			await use_potion()

		BattleAction.PlayerMove.BOMB:
			await use_bomb()

		BattleAction.PlayerMove.SMOKE_BOMB:
			await use_smoke_bomb()

func execute_player_attack_action(action: BattleAction) -> void:
	if action.target_index < 0:
		return

	if action.target_index >= enemies.size():
		return

	var target := enemies[action.target_index]

	if target.health <= 0:
		var living_enemies := get_living_enemy_indices()

		if living_enemies.is_empty():
			return

		action.target_index = living_enemies[0]
		target = enemies[action.target_index]

	await animate_lunge(player_visual, 1.0)
	match action.player_move:
		BattleAction.PlayerMove.SLASH:
			await perform_player_attack(
				"Slash",
				target,
				SLASH_DAMAGE,
				SLASH_ACCURACY
			)

		BattleAction.PlayerMove.HEAVY_STRIKE:
			await perform_player_attack(
				"Heavy Strike",
				target,
				HEAVY_STRIKE_DAMAGE,
				HEAVY_STRIKE_ACCURACY
			)

		BattleAction.PlayerMove.CROSSBOW:
			if GameState.player["arrows"] <= 0:
				print("No arrows left.")
				return

			GameState.player["arrows"] -= 1

			await perform_player_attack(
				"Crossbow",
				target,
				CROSSBOW_DAMAGE,
				1.0
			)

func perform_defend() -> void:
	player_is_defending = true

	print("Player defends.")
	await get_tree().create_timer(0.4, true).timeout

func perform_aim() -> void:
	player_is_aiming = true

	print("Player takes aim. The next attack cannot miss and deals double damage.")
	await get_tree().create_timer(0.4, true).timeout

func use_potion() -> void:
	if GameState.inventory["potions"] <= 0:
		print("No potions left.")
		return

	if player_health >= GameState.player["max_health"]:
		print("Player is already at full health.")
		return

	GameState.inventory["potions"] -= 1

	var old_health := player_health

	player_health = mini(
		player_health + POTION_HEAL,
		GameState.player["max_health"]
	)

	GameState.player["health"] = player_health

	var restored := player_health - old_health

	print("Player restores %d HP. HP: %d/%d" % [
		restored,
		player_health,
		GameState.player["max_health"],
	])

	await get_tree().create_timer(0.5, true).timeout

func use_bomb() -> void:
	if GameState.inventory["bombs"] <= 0:
		print("No bombs left.")
		return

	GameState.inventory["bombs"] -= 1

	print("Player throws a bomb.")
	await get_tree().create_timer(0.4, true).timeout

	for enemy in enemies:
		if enemy.health <= 0:
			continue

		var damage := maxi(
			BOMB_DAMAGE - enemy.damage_reduction,
			0
		)

		enemy.health = maxi(
			enemy.health - damage,
			0
		)

		print("%s takes %d damage. HP: %d/%d" % [
			enemy.data.display_name,
			damage,
			enemy.health,
			enemy.data.max_health,
		])

	await get_tree().create_timer(0.5, true).timeout

func use_smoke_bomb() -> void:
	if GameState.inventory["smoke_bombs"] <= 0:
		print("No smoke bombs left.")
		return

	GameState.inventory["smoke_bombs"] -= 1
	player_dodges_next_attack = true

	print("Player will dodge the next attack.")
	await get_tree().create_timer(0.4, true).timeout

func perform_player_attack(
	move_name: String,
	target: BattleEnemy,
	damage: int,
	accuracy: float
) -> void:
	print(
		"Player uses %s on %s."
		% [move_name, target.data.display_name]
	)

	await get_tree().create_timer(0.4, true).timeout

	var aimed_attack := player_is_aiming
	var final_damage := damage
	var hit_chance := accuracy

	if aimed_attack:
		final_damage *= 2
		hit_chance = 1.0
		player_is_aiming = false
	if not aimed_attack:
		hit_chance += player_accuracy_modifier
		hit_chance -= target.dodge_bonus
		hit_chance -= target.temporary_dodge_bonus

	hit_chance = clampf(hit_chance, 0.0, 1.0)

	if randf() > hit_chance:
		print("%s missed." % move_name)
		await get_tree().create_timer(0.4, true).timeout
		return

	final_damage = maxi(
		final_damage - target.damage_reduction,
		0
	)

	target.health = maxi(
		target.health - final_damage,
		0
	)

	print(
		"%s takes %d damage. HP: %d/%d"
		% [
			target.data.display_name,
			final_damage,
			target.health,
			target.data.max_health,
		]
	)

	await get_tree().create_timer(0.4, true).timeout

func execute_enemy_action(action: BattleAction) -> void:
	if action.enemy_index < 0:
		return

	if action.enemy_index >= enemies.size():
		return

	var enemy := enemies[action.enemy_index]

	if enemy.health <= 0:
		return

	var move := action.enemy_move

	if move == null:
		move = enemy.current_intent

	if move == null:
		return

	print(
		"%s uses %s."
		% [
			enemy.data.display_name,
			move.display_name,
		]
	)

	var enemy_visual := get_enemy_visual(action.enemy_index)
	await animate_lunge(enemy_visual, -1.0)

	await get_tree().create_timer(0.5, true).timeout

	match move.effect:
		EnemyMoveData.Effect.DAMAGE:
			deal_enemy_damage(enemy, move.damage)

		EnemyMoveData.Effect.POWER_UP_NEXT_ATTACK:
			enemy.damage_bonus += move.damage_bonus
			enemy.damage_multiplier *= move.damage_multiplier
			print("%s powers up." % enemy.data.display_name)

		EnemyMoveData.Effect.PREPARE_MOVE:
			enemy.forced_next_intent = move.follow_up_move
			print("%s prepares its next move." % enemy.data.display_name)

		EnemyMoveData.Effect.ACCURACY_DOWN:
			var hit := deal_enemy_damage(enemy, move.damage)

			if hit:
				player_accuracy_modifier = -move.effect_amount
				player_accuracy_debuff_turns = move.duration_turns + 1
				print("Player accuracy was reduced.")

		EnemyMoveData.Effect.STEAL_ITEM:
			steal_random_item(enemy)

		EnemyMoveData.Effect.DODGE_NEXT_TURN:
			enemy.temporary_dodge_bonus = move.effect_amount
			enemy.temporary_dodge_turns = move.duration_turns + 1

			print("%s becomes harder to hit." % enemy.data.display_name)

		EnemyMoveData.Effect.HEAL:
			var heal_amount := roundi(move.effect_amount)
			var old_health := enemy.health

			enemy.health = mini(
				enemy.health + heal_amount,
				enemy.data.max_health
			)

			print(
				"%s restores %d HP. HP: %d/%d"
				% [
					enemy.data.display_name,
					enemy.health - old_health,
					enemy.health,
					enemy.data.max_health,
				]
			)

		EnemyMoveData.Effect.TAKE_FLIGHT:
			enemy.temporary_dodge_bonus = move.effect_amount
			enemy.temporary_dodge_turns = move.duration_turns + 1
			enemy.forced_next_intent = move.follow_up_move

			print(
				"%s takes flight and prepares Death From Above."
				% enemy.data.display_name
			)
		_:
			print(
				"Enemy effect not implemented yet: ",
				EnemyMoveData.Effect.keys()[move.effect]
			)

	await get_tree().create_timer(0.4, true).timeout

func deal_enemy_damage(enemy: BattleEnemy, base_damage: int) -> bool:
	var damage := roundi(
		(base_damage + enemy.damage_bonus)
		* enemy.damage_multiplier
	)

	enemy.damage_bonus = 0
	enemy.damage_multiplier = 1.0

	if player_dodges_next_attack:
		player_dodges_next_attack = false
		print("Player dodges the attack.")
		return false

	if player_is_defending:
		damage = ceili(damage * 0.5)

	damage = maxi(damage, 0)

	player_health = maxi(player_health - damage, 0)
	GameState.player["health"] = player_health

	print(
		"Player takes %d damage. HP: %d/%d"
		% [
			damage,
			player_health,
			GameState.player["max_health"],
		]
	)

	return true

func steal_random_item(enemy: BattleEnemy) -> void:
	var available_items: Array[String] = []

	if GameState.player["arrows"] > 0:
		available_items.append("arrows")

	for item_name in GameState.inventory:
		if GameState.inventory[item_name] > 0:
			available_items.append(item_name)

	if available_items.is_empty():
		print("%s tried to steal, but you had nothing." % enemy.data.display_name)
		return

	var stolen_item:String = available_items.pick_random()

	if stolen_item == "arrows":
		GameState.player["arrows"] -= 1
	else:
		GameState.inventory[stolen_item] -= 1

	enemy.stolen_items[stolen_item] += 1

	print("%s stole one %s." % [
		enemy.data.display_name,
		stolen_item,
	])

func return_stolen_items(enemy: BattleEnemy) -> void:
	for item_name in enemy.stolen_items:
		var amount: int = enemy.stolen_items[item_name]

		if amount <= 0:
			continue

		if item_name == "arrows":
			GameState.player["arrows"] += amount
		else:
			GameState.inventory[item_name] += amount

		print("%s returned %d %s." % [
			enemy.data.display_name,
			amount,
			item_name,
		])

		enemy.stolen_items[item_name] = 0

func show_main_menu() -> void:
	main_buttons.show()
	attack_buttons.hide()
	skill_buttons.hide()
	item_buttons.hide()
	target_buttons.hide()

func show_attack_menu() -> void:
	main_buttons.hide()
	attack_buttons.show()
	skill_buttons.hide()
	item_buttons.hide()
	target_buttons.hide()

func show_skill_menu() -> void:
	main_buttons.hide()
	attack_buttons.hide()
	skill_buttons.show()
	item_buttons.hide()
	target_buttons.hide()

func show_item_menu() -> void:
	main_buttons.hide()
	attack_buttons.hide()
	skill_buttons.hide()
	item_buttons.show()
	target_buttons.hide()

func show_target_selection() -> void:
	battle_state = BattleState.SELECTING_TARGET

	main_buttons.hide()
	attack_buttons.hide()
	skill_buttons.hide()
	item_buttons.hide()
	target_buttons.show()

	for button_index in target_button_nodes.size():
		var button := target_button_nodes[button_index]
		var label := button.get_node("Label") as Label

		if button_index >= enemies.size():
			button.hide()
			continue

		var enemy := enemies[button_index]

		if enemy.health <= 0:
			button.hide()
			continue

		button.show()

		label.text = "%s" % [
			enemy.data.display_name
		]

func hide_all_menus() -> void:
	main_buttons.hide()
	attack_buttons.hide()
	skill_buttons.hide()
	item_buttons.hide()
	target_buttons.hide()

func start_player_turn() -> void:
	if battle_state == BattleState.FINISHED:
		return

	battle_state = BattleState.PLAYER_TURN
	selected_move = BattleAction.PlayerMove.NONE
	selected_target_index = -1

	show_main_menu()

func win_fight() -> void:
	if battle_state == BattleState.FINISHED:
		return

	battle_state = BattleState.FINISHED
	hide_all_menus()

	print("Victory.")
	await get_tree().create_timer(1.0, true).timeout

	fight_finished.emit({
		"outcome": "victory",
		"encounter": encounter_data,
	})

func lose_fight() -> void:
	if battle_state == BattleState.FINISHED:
		return

	battle_state = BattleState.FINISHED
	hide_all_menus()

	print("Defeat.")
	await get_tree().create_timer(1.0, true).timeout

	fight_finished.emit({
		"outcome": "defeat",
		"encounter": encounter_data,
	})

func _on_attack_pressed() -> void:
	if battle_state != BattleState.PLAYER_TURN:
		return

	show_attack_menu()

func _on_back_pressed() -> void:
	if battle_state != BattleState.PLAYER_TURN:
		return

	show_main_menu()

func _on_attack_1_pressed() -> void:
	begin_attack(BattleAction.PlayerMove.SLASH)

func _on_attack_2_pressed() -> void:
	begin_attack(BattleAction.PlayerMove.HEAVY_STRIKE)

func _on_attack_3_pressed() -> void:
	if GameState.player["arrows"] <= 0:
		print("No arrows left.")
		return

	begin_attack(BattleAction.PlayerMove.CROSSBOW)

func _on_skill_1_pressed() -> void:
	await submit_non_targeted_action(
		BattleAction.PlayerMove.DEFEND
	)

func _on_skill_2_pressed() -> void:
	await submit_non_targeted_action(
		BattleAction.PlayerMove.AIM
	)

func _on_item_1_pressed() -> void:
	if GameState.inventory["potions"] <= 0:
		print("No potions left.")
		return

	if player_health >= GameState.player["max_health"]:
		print("Player is already at full health.")
		return

	await submit_non_targeted_action(
		BattleAction.PlayerMove.POTION
	)

func _on_item_2_pressed() -> void:
	if GameState.inventory["bombs"] <= 0:
		print("No bombs left.")
		return

	await submit_non_targeted_action(
		BattleAction.PlayerMove.BOMB
	)

func _on_item_3_pressed() -> void:
	if GameState.inventory["smoke_bombs"] <= 0:
		print("No smoke bombs left.")
		return

	await submit_non_targeted_action(
		BattleAction.PlayerMove.SMOKE_BOMB
	)

func _on_target_0_pressed() -> void:
	await select_target(0)

func _on_target_1_pressed() -> void:
	await select_target(1)

func _on_target_2_pressed() -> void:
	await select_target(2)

func _on_target_back_pressed() -> void:
	if battle_state != BattleState.SELECTING_TARGET:
			return

	battle_state = BattleState.PLAYER_TURN
	selected_target_index = -1
	show_attack_menu()

func select_target(index: int) -> void:
	if battle_state != BattleState.SELECTING_TARGET:
		return

	if index < 0 or index >= enemies.size():
		return

	if enemies[index].health <= 0:
		return

	selected_target_index = index
	await submit_player_action()

func _on_run_pressed() -> void:
	if battle_state != BattleState.PLAYER_TURN:
		return

	if not encounter_data.can_run:
		print("You cannot run from this encounter.")
		return

	battle_state = BattleState.FINISHED
	hide_all_menus()

	fight_finished.emit({
		"outcome": "escaped",
		"encounter": encounter_data,
	})

func _on_item_pressed() -> void:
	if battle_state != BattleState.PLAYER_TURN:
		return

	show_item_menu()

func _on_skill_pressed() -> void:
	if battle_state != BattleState.PLAYER_TURN:
		return

	show_skill_menu()

func begin_attack(move: BattleAction.PlayerMove) -> void:
	if battle_state != BattleState.PLAYER_TURN:
		return

	var living_enemies := get_living_enemy_indices()

	if living_enemies.is_empty():
		await win_fight()
		return

	selected_move = move

	if living_enemies.size() == 1:
		selected_target_index = living_enemies[0]
		await submit_player_action()
		return

	show_target_selection()

func submit_player_action() -> void:
	if selected_target_index < 0:
		return

	var action := BattleAction.new()

	action.actor_type = BattleAction.ActorType.PLAYER
	action.player_move = selected_move
	action.target_index = selected_target_index
	action.priority = get_player_priority(selected_move)

	await resolve_round(action)

func submit_non_targeted_action(move: BattleAction.PlayerMove) -> void:
	if battle_state != BattleState.PLAYER_TURN:
		return

	var action := BattleAction.new()

	action.actor_type = BattleAction.ActorType.PLAYER
	action.player_move = move
	action.target_index = -1
	action.priority = get_player_priority(move)

	await resolve_round(action)

func get_player_priority(move: BattleAction.PlayerMove) -> int:
	match move:
		BattleAction.PlayerMove.HEAVY_STRIKE:
			return 0

		BattleAction.PlayerMove.DEFEND:
			return 300

		BattleAction.PlayerMove.SLASH, \
		BattleAction.PlayerMove.CROSSBOW, \
		BattleAction.PlayerMove.AIM, \
		BattleAction.PlayerMove.POTION, \
		BattleAction.PlayerMove.BOMB, \
		BattleAction.PlayerMove.SMOKE_BOMB:
			return 100

		_:
			return 100

func get_living_enemy_indices() -> Array[int]:
	var result: Array[int] = []

	for index in enemies.size():
		if enemies[index].health > 0:
			result.append(index)

	return result

func tick_temporary_effects() -> void:
	if player_accuracy_debuff_turns > 0:
		player_accuracy_debuff_turns -= 1

		if player_accuracy_debuff_turns == 0:
			player_accuracy_modifier = 0.0
			print("The accuracy reduction wore off.")

	for enemy in enemies:
		if enemy.temporary_dodge_turns <= 0:
			continue

		enemy.temporary_dodge_turns -= 1

		if enemy.temporary_dodge_turns == 0:
			enemy.temporary_dodge_bonus = 0.0
			print(
				"%s is no longer hiding."
				% enemy.data.display_name
			)

func finish_round() -> void:
	player_is_defending = false
	tick_temporary_effects()

	if player_health <= 0:
		await lose_fight()
		return

	if get_living_enemy_indices().is_empty():
		await win_fight()
		return

	choose_enemy_intents()
	start_player_turn()

func process_enemy_deaths() -> void:
	for enemy_index in range(enemies.size()):
		var enemy = enemies[enemy_index]

		if enemy.health > 0:
			continue

		if enemy.death_processed:
			continue

		enemy.death_processed = true

		return_stolen_items(enemy)
		await animate_enemy_death(enemy_index)

		print("%s was defeated." % enemy.data.display_name)

func animate_lunge(actor: Node3D, direction: float) -> void:
	if actor == null:
		return

	var start_position := actor.position

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(
		actor,
		"position:x",
		start_position.x + 0.18 * direction,
		0.10
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.tween_property(
		actor,
		"position:x",
		start_position.x,
		0.14
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await tween.finished

func get_enemy_visual(enemy_index: int) -> Node3D:
	if enemy_index < 0 or enemy_index >= enemy_slots.size():
		return null

	if enemy_slots[enemy_index].get_child_count() == 0:
		return null

	return enemy_slots[enemy_index].get_child(0) as Node3D

func animate_hit(actor: Node3D) -> void:
	if actor == null:
		return

	var sprite := actor.get_node_or_null("Sprite") as Sprite3D
	var start_position := actor.position

	if sprite != null:
		sprite.modulate = Color(1.8, 1.8, 1.8, 1.0)

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	tween.tween_property(actor, "position:x", start_position.x + 0.05, 0.035)
	tween.tween_property(actor, "position:x", start_position.x - 0.05, 0.035)
	tween.tween_property(actor, "position:x", start_position.x, 0.035)

	await tween.finished

	if sprite != null:
		sprite.modulate = Color.WHITE

func animate_enemy_death(enemy_index: int) -> void:
	var visual := get_enemy_visual(enemy_index)

	if visual == null:
		return

	var sprite := visual.get_node_or_null("Sprite") as GeometryInstance3D
	var shadow := visual.get_node_or_null("Shadow") as GeometryInstance3D

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)

	tween.tween_property(
		visual,
		"position:y",
		visual.position.y - 0.12,
		0.30
	)

	if sprite != null:
		tween.tween_property(sprite, "transparency", 1.0, 0.30)

	if shadow != null:
		tween.tween_property(shadow, "transparency", 1.0, 0.22)

	await tween.finished
	visual.hide()

func process_boss_phase_changes() -> void:
	for enemy in enemies:
		if enemy.health <= 0:
			continue

		if enemy.data.passive != EnemyData.Passive.DEMON_CROW:
			continue

		if enemy.boss_phase_two:
			continue

		var phase_two_threshold := ceili(
			enemy.data.max_health * 0.5
		)

		if enemy.health > phase_two_threshold:
			continue

		enemy.boss_phase_two = true

		print(
			"Omen of Death awakens. "
			+ "The Demon Crow will act twice each round."
		)
