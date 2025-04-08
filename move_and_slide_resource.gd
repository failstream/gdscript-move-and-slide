## move_and_slide_resource.gd
## This resource holds variables for the gdscript_move_and_slide function so that
## the CharacterBody2D functions can access out of scope variables that are passed
## and modified by reference in the C++ code. This lets me carve out functionality
## into separate functions instead of having one big function that does everything
## or cluttering up the script with higher scope variable names.

extends Resource
class_name MoveAndSlideResource

var debug: bool = false ## enables print statements when touching floor/wall/ceiling


var platform_velocity: Vector2 ## platform velocity taken from colliding platform
var platform_rid: RID ## platform RID
var platform_object_id: int ## platform instance id
var platform_layer: int ## platform collision layer


var previous_position: Vector2 ## global position on the previous frame
var motion: Vector2 ## the current pixel offset that the body will be attempted to be moved by this frame
var motion_slide_up: Vector2 ## the motion pixel offset perpendicular to the up_direction
var prev_floor_normal: Vector2 ## floor normal on the previous frame


var sliding_enabled: bool ## stops on slopes if true
var can_apply_constant_speed: bool ## applies constant speed on slopes if true
var apply_ceiling_velocity: bool ## slide on ceiling if true
var first_slide: bool ## this is the first slide collision check in the iteration loop if true
var vel_dir_facing_up: bool ## velocity direction is facing up if true
var last_travel: Vector2 ## stores the last collision's travel vector


#region wall boolean functionality recreation

var on_floor: bool = false:
    set(value):
        if debug and value and was_on_floor != value and not on_floor:
            print("TOUCHED FLOOR")
        on_floor = value

var was_on_floor: bool = false

var on_ceiling: bool = false:
    set(value):
        if debug and value and was_on_ceiling != value and not on_ceiling:
            print("TOUCHED CEILING")
        on_ceiling = value

var was_on_ceiling: bool = false

var on_wall: bool = false:
    set(value):
        if debug and value and was_on_wall != value and not on_wall:
            print("TOUCHED WALL")
        on_wall = value

var was_on_wall: bool = false

var on_left_wall: bool = false:
    set(value):
        if debug and value and was_on_left_wall != value and not on_left_wall:
            print("TOUCHED LEFT WALL")
        on_left_wall = value

var was_on_left_wall: bool = false

var on_right_wall: bool = false:
    set(value):
        if debug and value and was_on_right_wall != value and not on_right_wall:
            print("TOUCHED RIGHT WALL")
        on_right_wall = value

var was_on_right_wall: bool = false

func reset_collision_state() -> void:
    was_on_ceiling = on_ceiling
    was_on_floor = on_floor
    was_on_wall = on_wall
    was_on_left_wall = on_left_wall
    was_on_right_wall = on_right_wall
    on_ceiling = false
    on_floor = false
    on_wall = false
    on_left_wall = false
    on_right_wall = false


func is_on_floor_only() -> bool:
    return on_floor and not on_wall and not on_ceiling

func is_on_wall_only() -> bool:
    return on_wall and not on_floor and not on_ceiling

func is_on_ceiling_only() -> bool:
    return on_ceiling and not on_floor and not on_wall

func is_on_floor() -> bool:
    return on_floor

func is_on_ceiling() -> bool:
    return on_ceiling

func is_on_wall() -> bool:
    return on_wall

func is_on_left_wall() -> bool:
    return on_left_wall

func is_on_right_wall() -> bool:
    return on_right_wall

#endregion
