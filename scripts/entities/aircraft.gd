extends Node2D
class_name Aircraft

enum AircraftState {
    SPAWNED,
    WAITING_FOR_FUEL,
    GOING_TO_FUEL,
    FUELING,
    WAITING_FOR_AMMO,
    GOING_TO_AMMO,
    REARMING,
    WAITING_FOR_SERVICE,
    GOING_TO_SERVICE,
    MAINTENANCE,
    WAITING_FOR_RUNWAY,
    TAKEOFF_TO_RUNWAY_START,
    TAKEOFF_ROLL,
    ON_MISSION,
    RETURNING,
    LANDING_ROLL,
    COMPLETED
}

@export var aircraft_id: String = "AC_1"
@export var aircraft_type: String = "GripenE"
@export var max_fuel: float = 100.0
@export var fuel_level: float = 70.0
@export var health: float = 100.0

var state: AircraftState = AircraftState.SPAWNED
var home_base: Airbase
var current_base: Airbase
var assigned_mission = null
var timer_remaining: float = 0.0
var assigned_service_bay: int = -1
var launch_slot_index: int = 0

func _ready() -> void:
    apply_aircraft_sprite()
    refresh_color()
    update_label()

func set_state(new_state: AircraftState) -> void:
    state = new_state
    refresh_color()
    update_label()

func tick(delta_minutes: float) -> void:
    if timer_remaining > 0.0:
        timer_remaining -= delta_minutes

func move_to_position(target_pos: Vector2, duration_sec: float = 1.0) -> void:
    var tween = create_tween()
    tween.tween_property(self, "position", target_pos, duration_sec)

func point_toward(target_pos: Vector2) -> void:
    var direction = target_pos - position
    rotation = direction.angle() + deg_to_rad(90)

func update_label() -> void:
    if has_node("StateLabel"):
        $StateLabel.visible = false

func apply_aircraft_sprite() -> void:
    if not has_node("Sprite2D"):
        return

    var sprite: Sprite2D = $Sprite2D

    match aircraft_type:
        "GripenE":
            sprite.texture = load("res://assets/GripenEF.png")
            sprite.scale = Vector2(0.10, 0.10)
        "GlobalEye":
            sprite.texture = load("res://assets/GlobalEye.png")
            sprite.scale = Vector2(0.12, 0.12)
        "LOTUS":
            sprite.texture = load("res://assets/LOTUS.png")
            sprite.scale = Vector2(0.10, 0.10)
        "VLO/UCAV":
            sprite.texture = load("res://assets/UAV.png")
            sprite.scale = Vector2(0.10, 0.10)
        _:
            sprite.texture = load("res://assets/GripenEF.png")
            sprite.scale = Vector2(0.10, 0.10)

func refresh_color() -> void:
    if not has_node("Sprite2D"):
        return

    var sprite: Sprite2D = $Sprite2D

    match state:
        AircraftState.SPAWNED:
            sprite.modulate = Color(1, 1, 1)
        AircraftState.WAITING_FOR_FUEL, AircraftState.WAITING_FOR_AMMO, AircraftState.WAITING_FOR_SERVICE, AircraftState.WAITING_FOR_RUNWAY:
            sprite.modulate = Color(1.0, 0.35, 0.35)
        AircraftState.GOING_TO_FUEL, AircraftState.FUELING:
            sprite.modulate = Color(0.35, 0.9, 1.0)
        AircraftState.GOING_TO_AMMO, AircraftState.REARMING:
            sprite.modulate = Color(1.0, 0.75, 0.25)
        AircraftState.GOING_TO_SERVICE, AircraftState.MAINTENANCE:
            sprite.modulate = Color(1.0, 0.55, 0.3)
        AircraftState.TAKEOFF_TO_RUNWAY_START, AircraftState.TAKEOFF_ROLL:
            sprite.modulate = Color(1.0, 1.0, 0.5)
        AircraftState.ON_MISSION:
            sprite.modulate = Color(0.4, 1.0, 0.4)
        AircraftState.RETURNING, AircraftState.LANDING_ROLL:
            sprite.modulate = Color(1.0, 0.65, 0.35)
        AircraftState.COMPLETED:
            sprite.modulate = Color(0.8, 0.8, 0.8)
