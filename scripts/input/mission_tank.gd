extends "res://scripts/pvp/pvp_tank.gd"

var was_mine_held := false

func wants_mine() -> bool:
	var held := Input.is_action_pressed("solo_mine") if device == -1 else (Input.is_physical_key_pressed(KEY_G if device == -2 else KEY_SLASH) if device < -1 else ControllerInput.button(device, ControllerInput.mine_button(device)))
	var pressed := held and not was_mine_held
	was_mine_held = held
	return pressed
