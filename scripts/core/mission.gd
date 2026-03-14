extends Resource
class_name Mission

enum MissionType {
    AEW,
    RECCE,
    QRA,
    DCA,
    ATTACK_AI_DT,
    ATTACK_AI_ST
}

var id: String = ""
var type: MissionType = MissionType.RECCE
var target: Vector2 = Vector2.ZERO
var priority: int = 1
var aircraft_type: String = ""
var aircraft_count: int = 1
var assigned_aircraft: Array = []
var status: String = "QUEUED"
