extends GdScriptMoveAndSlide


@export var gravity_on: bool = false

@export var gravity_strength: float = 980.0
@export var terminal_velocity: float = 1400.0
@export var speed: float = 200.0

var facing: Vector2 = Vector2.RIGHT:
    set(value):
        facing = value
        rotation = facing.angle()



func _physics_process(delta: float) -> void:
    if not gravity_on:
        _floating_movement()
    else:
        _gravity_movement(delta)



func _gravity_movement(delta: float) -> void:
    var direction: int = Input.get_axis("ui_left", "ui_right")
    var jumped: bool = Input.is_action_just_pressed("ui_accept")
    _change_facing(Vector2(direction, 0.0))
    velocity.x = direction * speed
    if not mr.is_on_floor():
        velocity.y += gravity_strength * delta
        velocity.y = minf(velocity.y, terminal_velocity)
    else:
        velocity.y = 0.0
        if jumped:
            velocity.y = -600.0
    
    gdscript_move_and_slide()



func _floating_movement() -> void:
    var direction: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    _change_facing(direction)
    velocity = direction * speed
    
    gdscript_move_and_slide()



func _change_facing(direction: Vector2) -> void:
    if direction != Vector2.ZERO and direction != facing:
        facing = direction
