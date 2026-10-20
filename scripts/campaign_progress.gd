class_name CampaignProgress
extends RefCounted

const SAVE_PATH := "user://campaign.cfg"
static var selected_mission: int = 1
static var debug_mission: int = 0
static var save_path: String = SAVE_PATH

static func highest_mission() -> int:
	var config := ConfigFile.new()
	if config.load(save_path) != OK:
		return 1
	return clampi(int(config.get_value("campaign", "unlocked", 1)), 1, 50)

static func unlock(mission: int) -> void:
	var config := ConfigFile.new()
	config.set_value("campaign", "unlocked", maxi(highest_mission(), clampi(mission, 1, 50)))
	config.save(save_path)
