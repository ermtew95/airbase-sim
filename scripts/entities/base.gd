extends Node2D
class_name Airbase

@export var base_id: String = "base_a"
@export var base_name: String = "Main Base"
@export var fuel_stock: float = 1000.0
@export var ammo_stock: int = 100

var aircraft_at_base: Array = []

var fuel_busy: bool = false
var ammo_busy: bool = false
var runway_busy: bool = false

var service_bay_busy := {
    0: false,
    1: false
}

var fuel_queue: Array = []
var ammo_queue: Array = []
var service_queue: Array = []
var runway_queue: Array = []

func _ready() -> void:
    if has_node("NameLabel"):
        $NameLabel.visible = false

func consume_fuel(amount: float) -> bool:
    if fuel_stock >= amount:
        fuel_stock -= amount
        return true
    return false

func consume_ammo(amount: int) -> bool:
    if ammo_stock >= amount:
        ammo_stock -= amount
        return true
    return false

func get_parking_position(slot_index: int) -> Vector2:
    var marker_name = "Parking%d" % (slot_index + 1)
    if has_node(marker_name):
        return get_node(marker_name).global_position
    return global_position

func get_service_bay_position(slot_index: int) -> Vector2:
    var bay_name = "ServiceBay%d" % (slot_index + 1)
    if has_node(bay_name):
        return get_node(bay_name).global_position
    return global_position

func get_fuel_position() -> Vector2:
    if has_node("FuelDepotMarker"):
        return $FuelDepotMarker.global_position
    return global_position

func get_ammo_position() -> Vector2:
    if has_node("AmmoDepotMarker"):
        return $AmmoDepotMarker.global_position
    return global_position

func get_runway_start_position() -> Vector2:
    if has_node("RunwayStart"):
        return $RunwayStart.global_position
    return global_position

func get_runway_end_position() -> Vector2:
    if has_node("RunwayEnd"):
        return $RunwayEnd.global_position
    return global_position

func try_reserve_fuel(aircraft) -> bool:
    if not fuel_busy:
        fuel_busy = true
        return true
    if not fuel_queue.has(aircraft):
        fuel_queue.append(aircraft)
    return false

func release_fuel() -> void:
    fuel_busy = false

func try_reserve_ammo(aircraft) -> bool:
    if not ammo_busy:
        ammo_busy = true
        return true
    if not ammo_queue.has(aircraft):
        ammo_queue.append(aircraft)
    return false

func release_ammo() -> void:
    ammo_busy = false

func try_reserve_service_bay(aircraft) -> int:
    for bay_id in service_bay_busy.keys():
        if not service_bay_busy[bay_id]:
            service_bay_busy[bay_id] = true
            return bay_id

    if not service_queue.has(aircraft):
        service_queue.append(aircraft)
    return -1

func release_service_bay(bay_id: int) -> void:
    if service_bay_busy.has(bay_id):
        service_bay_busy[bay_id] = false

func try_reserve_runway(aircraft) -> bool:
    if not runway_busy:
        runway_busy = true
        return true
    if not runway_queue.has(aircraft):
        runway_queue.append(aircraft)
    return false

func release_runway() -> void:
    runway_busy = false
