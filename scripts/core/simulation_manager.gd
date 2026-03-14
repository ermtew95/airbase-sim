extends Node

const AircraftScene = preload("res://scenes/entities/Aircraft.tscn")
const MissionMarkerScene = preload("res://scenes/entities/MissionMarker.tscn")

var bases = []
var aircraft_list = []
var mission_markers = {}
var missions = []
var mission_counter = 1
var aircraft_counter = 1

var awaiting_map_click := false
var selected_mission_type := Mission.MissionType.RECCE
var selected_aircraft_type := "GripenE"
var selected_aircraft_count := 1
var last_click_down := false

var fleet_inventory = {
    "GripenE": {"total": 4, "available": 4, "busy": 0},
    "LOTUS": {"total": 1, "available": 1, "busy": 0},
    "GlobalEye": {"total": 1, "available": 1, "busy": 0},
    "VLO/UCAV": {"total": 2, "available": 2, "busy": 0}
}

@onready var world = get_parent().get_node("World")
@onready var hud = get_parent().get_node("HUD")
@onready var map_sprite = world.get_node("MapSprite")

func _ready():
    randomize()
    spawn_bases()

    if hud != null and hud.has_method("set_simulation"):
        hud.set_simulation(self)

func spawn_bases():
    bases.clear()

    if world.has_node("Base"):
        var existing_base = world.get_node("Base")
        bases.append(existing_base)
    else:
        push_error("Base node not found under World")

func get_allowed_aircraft_for_mission_type(mission_type: int) -> Array[String]:
    match mission_type:
        Mission.MissionType.AEW:
            return ["GlobalEye"]
        Mission.MissionType.RECCE:
            return ["LOTUS", "GripenE"]
        Mission.MissionType.QRA:
            return ["GripenE"]
        Mission.MissionType.DCA:
            return ["GripenE"]
        Mission.MissionType.ATTACK_AI_DT:
            return ["GripenE", "VLO/UCAV"]
        Mission.MissionType.ATTACK_AI_ST:
            return ["GripenE", "VLO/UCAV"]
        _:
            return ["GripenE"]

func arm_manual_mission(mission_type: int, aircraft_type: String, aircraft_count: int):
    selected_mission_type = mission_type
    selected_aircraft_type = aircraft_type
    selected_aircraft_count = aircraft_count
    awaiting_map_click = true

func add_aircraft_inventory(aircraft_type: String, count: int):
    if not fleet_inventory.has(aircraft_type):
        fleet_inventory[aircraft_type] = {"total": 0, "available": 0, "busy": 0}

    fleet_inventory[aircraft_type]["total"] += count
    fleet_inventory[aircraft_type]["available"] += count

func get_map_global_rect() -> Rect2:
    var local_rect = map_sprite.get_rect()

    var top_left = map_sprite.to_global(local_rect.position)
    var top_right = map_sprite.to_global(local_rect.position + Vector2(local_rect.size.x, 0))
    var bottom_left = map_sprite.to_global(local_rect.position + Vector2(0, local_rect.size.y))

    var width = top_left.distance_to(top_right)
    var height = top_left.distance_to(bottom_left)

    return Rect2(top_left, Vector2(width, height))

func create_mission_at(pos: Vector2):
    var mission = Mission.new()
    mission.id = "M%d" % mission_counter
    mission_counter += 1
    mission.target = pos
    mission.type = selected_mission_type
    mission.aircraft_type = selected_aircraft_type
    mission.aircraft_count = selected_aircraft_count
    mission.priority = 1
    mission.status = "QUEUED"

    missions.append(mission)
    spawn_mission_marker(mission)

func spawn_mission_marker(mission):
    var marker = MissionMarkerScene.instantiate()
    world.add_child(marker)
    marker.position = mission.target

    if marker.has_node("Label"):
        marker.get_node("Label").text = "%s\n%s" % [
            mission.id,
            Mission.MissionType.keys()[mission.type]
        ]

    mission_markers[mission.id] = marker

func get_launch_position(slot_index: int) -> Vector2:
    var base = bases[0]
    return base.get_parking_position(slot_index % 4)

func can_assign_aircraft_type(aircraft_type: String, count: int) -> bool:
    if not fleet_inventory.has(aircraft_type):
        return false
    return fleet_inventory[aircraft_type]["available"] >= count

func reserve_aircraft_type(aircraft_type: String, count: int):
    fleet_inventory[aircraft_type]["available"] -= count
    fleet_inventory[aircraft_type]["busy"] += count

func release_aircraft_type(aircraft_type: String, count: int):
    fleet_inventory[aircraft_type]["available"] += count
    fleet_inventory[aircraft_type]["busy"] -= count

func spawn_active_aircraft_for_mission(mission):
    var base = bases[0]

    for i in range(mission.aircraft_count):
        var aircraft = AircraftScene.instantiate()
        aircraft.aircraft_id = "AC_%d" % aircraft_counter
        aircraft_counter += 1
        aircraft.aircraft_type = mission.aircraft_type
        aircraft.home_base = base
        aircraft.current_base = base
        aircraft.assigned_mission = mission
        aircraft.launch_slot_index = i
        aircraft.position = get_launch_position(i)
        aircraft.fuel_level = 70.0
        aircraft.set_state(Aircraft.AircraftState.SPAWNED)
        aircraft.apply_aircraft_sprite()

        world.add_child(aircraft)
        aircraft_list.append(aircraft)
        mission.assigned_aircraft.append(aircraft)

func activate_ready_missions():
    for mission in missions:
        if mission.status == "QUEUED":
            if can_assign_aircraft_type(mission.aircraft_type, mission.aircraft_count):
                reserve_aircraft_type(mission.aircraft_type, mission.aircraft_count)
                spawn_active_aircraft_for_mission(mission)
                mission.status = "ACTIVE"

func complete_mission_for_aircraft(aircraft):
    var mission = aircraft.assigned_mission
    if mission == null:
        return

    mission.assigned_aircraft.erase(aircraft)

    if mission.assigned_aircraft.is_empty():
        mission.status = "COMPLETE"

        if mission_markers.has(mission.id):
            var marker = mission_markers[mission.id]
            if is_instance_valid(marker):
                marker.queue_free()
            mission_markers.erase(mission.id)

        release_aircraft_type(mission.aircraft_type, mission.aircraft_count)

func remove_active_aircraft(aircraft):
    aircraft_list.erase(aircraft)
    if is_instance_valid(aircraft):
        aircraft.queue_free()

func _process(delta):
    # one-click mission placement
    if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        if not last_click_down:
            last_click_down = true

            if awaiting_map_click:
                var mouse_pos = get_viewport().get_camera_2d().get_global_mouse_position()
                var local = map_sprite.to_local(mouse_pos)

                if map_sprite.get_rect().has_point(local):
                    create_mission_at(mouse_pos)
                    awaiting_map_click = false
    else:
        last_click_down = false

    activate_ready_missions()

    var finished_aircraft: Array = []

    for aircraft in aircraft_list:
        var base = aircraft.current_base
        aircraft.tick(delta)

        if aircraft.state == Aircraft.AircraftState.SPAWNED:
            if base.try_reserve_fuel(aircraft):
                var fuel_pos = base.get_fuel_position()
                aircraft.point_toward(fuel_pos)
                aircraft.set_state(Aircraft.AircraftState.GOING_TO_FUEL)
                aircraft.move_to_position(fuel_pos, 0.8)
            else:
                aircraft.set_state(Aircraft.AircraftState.WAITING_FOR_FUEL)

        elif aircraft.state == Aircraft.AircraftState.WAITING_FOR_FUEL:
            if base.try_reserve_fuel(aircraft):
                base.fuel_queue.erase(aircraft)
                var fuel_pos = base.get_fuel_position()
                aircraft.point_toward(fuel_pos)
                aircraft.set_state(Aircraft.AircraftState.GOING_TO_FUEL)
                aircraft.move_to_position(fuel_pos, 0.8)

        elif aircraft.state == Aircraft.AircraftState.GOING_TO_FUEL:
            var fuel_pos = base.get_fuel_position()
            if aircraft.position.distance_to(fuel_pos) < 8:
                aircraft.set_state(Aircraft.AircraftState.FUELING)
                aircraft.timer_remaining = 1.0

        elif aircraft.state == Aircraft.AircraftState.FUELING:
            if aircraft.timer_remaining <= 0.0:
                var fuel_needed = aircraft.max_fuel - aircraft.fuel_level
                var fuel_to_take = min(fuel_needed, 25.0)

                if base.consume_fuel(fuel_to_take):
                    aircraft.fuel_level += fuel_to_take

                base.release_fuel()

                if base.try_reserve_ammo(aircraft):
                    var ammo_pos = base.get_ammo_position()
                    aircraft.point_toward(ammo_pos)
                    aircraft.set_state(Aircraft.AircraftState.GOING_TO_AMMO)
                    aircraft.move_to_position(ammo_pos, 0.8)
                else:
                    aircraft.set_state(Aircraft.AircraftState.WAITING_FOR_AMMO)

        elif aircraft.state == Aircraft.AircraftState.WAITING_FOR_AMMO:
            if base.try_reserve_ammo(aircraft):
                base.ammo_queue.erase(aircraft)
                var ammo_pos = base.get_ammo_position()
                aircraft.point_toward(ammo_pos)
                aircraft.set_state(Aircraft.AircraftState.GOING_TO_AMMO)
                aircraft.move_to_position(ammo_pos, 0.8)

        elif aircraft.state == Aircraft.AircraftState.GOING_TO_AMMO:
            var ammo_pos = base.get_ammo_position()
            if aircraft.position.distance_to(ammo_pos) < 8:
                aircraft.set_state(Aircraft.AircraftState.REARMING)
                aircraft.timer_remaining = 1.0

        elif aircraft.state == Aircraft.AircraftState.REARMING:
            if aircraft.timer_remaining <= 0.0:
                base.consume_ammo(1)
                base.release_ammo()

                var bay_id = base.try_reserve_service_bay(aircraft)
                if bay_id >= 0:
                    aircraft.assigned_service_bay = bay_id
                    var bay_target = base.get_service_bay_position(bay_id)
                    aircraft.point_toward(bay_target)
                    aircraft.set_state(Aircraft.AircraftState.GOING_TO_SERVICE)
                    aircraft.move_to_position(bay_target, 0.8)
                else:
                    aircraft.set_state(Aircraft.AircraftState.WAITING_FOR_SERVICE)

        elif aircraft.state == Aircraft.AircraftState.WAITING_FOR_SERVICE:
            var bay_id = base.try_reserve_service_bay(aircraft)
            if bay_id >= 0:
                base.service_queue.erase(aircraft)
                aircraft.assigned_service_bay = bay_id
                var bay_target = base.get_service_bay_position(bay_id)
                aircraft.point_toward(bay_target)
                aircraft.set_state(Aircraft.AircraftState.GOING_TO_SERVICE)
                aircraft.move_to_position(bay_target, 0.8)

        elif aircraft.state == Aircraft.AircraftState.GOING_TO_SERVICE:
            var bay_target = base.get_service_bay_position(aircraft.assigned_service_bay)
            if aircraft.position.distance_to(bay_target) < 8:
                aircraft.set_state(Aircraft.AircraftState.MAINTENANCE)
                aircraft.timer_remaining = 1.0

        elif aircraft.state == Aircraft.AircraftState.MAINTENANCE:
            if aircraft.timer_remaining <= 0.0:
                base.release_service_bay(aircraft.assigned_service_bay)
                aircraft.assigned_service_bay = -1

                if base.try_reserve_runway(aircraft):
                    var runway_start = base.get_runway_start_position()
                    aircraft.point_toward(runway_start)
                    aircraft.set_state(Aircraft.AircraftState.TAKEOFF_TO_RUNWAY_START)
                    aircraft.move_to_position(runway_start, 1.0)
                else:
                    aircraft.set_state(Aircraft.AircraftState.WAITING_FOR_RUNWAY)

        elif aircraft.state == Aircraft.AircraftState.WAITING_FOR_RUNWAY:
            if base.try_reserve_runway(aircraft):
                base.runway_queue.erase(aircraft)
                var runway_start = base.get_runway_start_position()
                aircraft.point_toward(runway_start)
                aircraft.set_state(Aircraft.AircraftState.TAKEOFF_TO_RUNWAY_START)
                aircraft.move_to_position(runway_start, 1.0)

        elif aircraft.state == Aircraft.AircraftState.TAKEOFF_TO_RUNWAY_START:
            var runway_start = base.get_runway_start_position()
            if aircraft.position.distance_to(runway_start) < 10:
                var runway_end = base.get_runway_end_position()
                aircraft.point_toward(runway_end)
                aircraft.set_state(Aircraft.AircraftState.TAKEOFF_ROLL)
                aircraft.move_to_position(runway_end, 1.8)

        elif aircraft.state == Aircraft.AircraftState.TAKEOFF_ROLL:
            var runway_end = base.get_runway_end_position()
            if aircraft.position.distance_to(runway_end) < 12:
                base.release_runway()
                var mission = aircraft.assigned_mission
                aircraft.point_toward(mission.target)
                aircraft.set_state(Aircraft.AircraftState.ON_MISSION)
                aircraft.move_to_position(mission.target, 3.5)

        elif aircraft.state == Aircraft.AircraftState.ON_MISSION:
            var mission = aircraft.assigned_mission
            if aircraft.position.distance_to(mission.target) < 10:
                var runway_end = base.get_runway_end_position()
                aircraft.point_toward(runway_end)
                aircraft.set_state(Aircraft.AircraftState.RETURNING)
                aircraft.move_to_position(runway_end, 3.5)

        elif aircraft.state == Aircraft.AircraftState.RETURNING:
            var runway_end = base.get_runway_end_position()
            if aircraft.position.distance_to(runway_end) < 12:
                aircraft.set_state(Aircraft.AircraftState.LANDING_ROLL)
                aircraft.timer_remaining = 0.6

        elif aircraft.state == Aircraft.AircraftState.LANDING_ROLL:
            if aircraft.timer_remaining <= 0.0:
                complete_mission_for_aircraft(aircraft)
                aircraft.set_state(Aircraft.AircraftState.COMPLETED)
                finished_aircraft.append(aircraft)

    for ac in finished_aircraft:
        remove_active_aircraft(ac)

    if hud != null and hud.has_method("update_hud"):
        hud.update_hud(self)
