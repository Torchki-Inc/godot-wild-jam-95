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

var player_health: int

var encounter_data: EncounterData
var enemies: Array[BattleEnemy] = []

var battle_state: BattleState = BattleState.STARTING

var selected_move: BattleAction.PlayerMove = BattleAction.PlayerMove.NONE
var selected_target_index: int = -1

func setup(encounter: EncounterData) -> void:
	encounter_data = encounter

func _ready() -> void:
	$Camera3D.add_to_group("camera")
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

		if enemy.forced_next_intent != null:
			enemy.current_intent = enemy.forced_next_intent
			enemy.forced_next_intent = null
			continue

		if enemy.data.moves.is_empty():
			push_warning(
				"%s has no moves." % enemy.data.display_name
			)
			enemy.current_intent = null
			continue

		enemy.current_intent = enemy.data.moves.pick_random()

	update_intent_ui()

# TODO
func update_intent_ui() -> void:
	print("--- ENEMY INTENTS ---")

	for enemy in enemies:
		if enemy.health <= 0:
			continue

		if enemy.current_intent == null:
			print("%s: no action" % enemy.data.display_name)
		else:
			print(
				"%s intends to use %s"
				% [
					enemy.data.display_name,
					enemy.current_intent.display_name,
				]
			)

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
		enemy_action.priority = get_enemy_priority(enemy)

		actions.append(enemy_action)

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

	var move := enemy.current_intent

	if move == null:
		return

	print(
		"%s uses %s."
		% [
			enemy.data.display_name,
			move.display_name,
		]
	)

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


		_:
			print(
				"Enemy effect not implemented yet: ",
				EnemyMoveData.Effect.keys()[move.effect]
			)

	await get_tree().create_timer(0.4, true).timeout

func deal_enemy_damage(
	enemy: BattleEnemy,
	base_damage: int
) -> bool:
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
	for enemy in enemies:
		if enemy.health > 0:
			continue

		if enemy.death_processed:
			continue

		enemy.death_processed = true
		return_stolen_items(enemy)

		print("%s was defeated." % enemy.data.display_name)
