## gdscript_move_and_slide.gd
## This extension of CharacterBody2D has the move_and_slide function in gdscript
## for educational purposes.

extends CharacterBody2D
class_name GdScriptMoveAndSlide

@export var debug: bool = true
@export var gravity_on: bool = false

const GRAVITY_STRENGTH: float = 980.0
const TERMINAL_VELOCITY: float = 1400.0
const SPEED: float = 200.0
var facing: Vector2 = Vector2.RIGHT:
  set(value):
    facing = value
    $Node2D.rotation = facing.angle()


func _ready() -> void:
  mr.debug = debug

func _physics_process(delta: float) -> void:
  if not gravity_on:
    _floating_movement()
  else:
    _gravity_movement(delta)


func _gravity_movement(delta: float) -> void:
  var direction: int = Input.get_axis("ui_left", "ui_right")
  var jumped: bool = Input.is_action_just_pressed("ui_accept")
  _change_facing(Vector2(direction, 0.0))
  velocity.x = direction * SPEED
  if not mr.is_on_floor():
    velocity.y += GRAVITY_STRENGTH * delta   
    velocity.y = minf(velocity.y, TERMINAL_VELOCITY)
  else:
    velocity.y = 0.0
    if jumped:
      velocity.y = -600.0
  gdscript_move_and_slide()

func _floating_movement() -> void:
  var direction: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
  _change_facing(direction)
  velocity = direction * SPEED
  gdscript_move_and_slide()


func _change_facing(direction: Vector2) -> void:
  if direction != Vector2.ZERO and direction != facing:
    facing = direction





const FLOOR_ANGLE_THRESHOLD: float = 0.01
var motion_results: Array = []  ## Stores collision results from each iteration
var last_motion: Vector2 = Vector2() ## The travel motion from this collision iteration
var floor_normal: Vector2 = Vector2() ## floor normal is set when snapping to ground
var wall_normal: Vector2 = Vector2() ## wall normal is set on wall collision

var mr: MoveAndSlideResource = MoveAndSlideResource.new()


func gdscript_move_and_slide() -> bool:

    var delta: float = get_physics_process_delta_time() if Engine.is_in_physics_frame() else get_process_delta_time()

    var current_platform_velocity: Vector2 = mr.platform_velocity
    mr.previous_position = global_position
    
    if ((mr.on_floor or mr.on_wall) and mr.platform_rid.is_valid()):
        #region SET CURRENT PLATFORM VELOCITY
        var excluded: bool = false
        if mr.on_floor:
            excluded = (platform_floor_layers & mr.platform_layer) == 0
        elif mr.on_wall:
            excluded = (platform_wall_layers & mr.platform_layer) == 0
        if not excluded:
            var body_state: PhysicsDirectBodyState2D = PhysicsServer2D.body_get_direct_state(mr.platform_rid)
            if body_state:
                var local_position: Vector2 = global_position - body_state.transform.get_origin()
                current_platform_velocity = body_state.get_velocity_at_local_position(local_position)
            else:
                current_platform_velocity = Vector2()
                mr.platform_rid = RID()
        else:
            current_platform_velocity = Vector2()
        #endregion
    
    # reset variables to starting states
    motion_results.clear()
    last_motion = Vector2()
    mr.reset_collision_state()
    
    if not current_platform_velocity.is_zero_approx():
        #region ADD CURRENT PLATFORM VELOCITY
        PhysicsServer2D.body_add_collision_exception(get_rid(), mr.platform_rid)
        var floor_result: KinematicCollision2D = move_and_collide(current_platform_velocity * delta, false, safe_margin, true)
        if floor_result:
            motion_results.push_back(floor_result)
            _set_collision_direction_from_motion_test(floor_result)
        PhysicsServer2D.body_remove_collision_exception(get_rid(), mr.platform_rid)
        #endregion
    
    if motion_mode == MOTION_MODE_GROUNDED:
        _gdscript_move_and_slide_grounded(delta)
    else:
        _gdscript_move_and_slide_floating(delta)
    
    if platform_on_leave != PLATFORM_ON_LEAVE_DO_NOTHING:
        if (not mr.on_floor and not mr.on_wall):
            if platform_on_leave == PLATFORM_ON_LEAVE_ADD_VELOCITY and current_platform_velocity.dot(up_direction) < 0:
                current_platform_velocity = current_platform_velocity.slide(up_direction)
            velocity += current_platform_velocity
    
    return motion_results.size() > 0



func _gdscript_move_and_slide_floating(delta: float) -> void:

    mr.motion = velocity * delta
    mr.platform_rid = RID()
    mr.platform_object_id = 0
    mr.platform_velocity = Vector2()
    floor_normal = Vector2()
    mr.first_slide = true
    
    for iteration in range(max_slides):
        
        var result: KinematicCollision2D = move_and_collide(mr.motion, false, safe_margin, true)
        var collided: bool = false
        if result:
            collided = true
        
        if collided:
            motion_results.push_back(result)
            _set_collision_direction_from_motion_test(result)
            
            if result.get_remainder().is_zero_approx():
                mr.motion = Vector2()
                break
            
            if wall_min_slide_angle != 0 and result.get_angle(-velocity.normalized()) < wall_min_slide_angle + FLOOR_ANGLE_THRESHOLD:
                mr.motion = Vector2()
            elif mr.first_slide:
                var motion_slide_norm: Vector2 = result.get_remainder().slide(result.get_normal()).normalized()
                mr.motion = motion_slide_norm * (mr.motion.length() - result.get_travel().length())
            else:
                mr.motion = result.get_remainder().slide(result.get_normal())
            
            if mr.motion.dot(velocity) <= 0.0:
                mr.motion = Vector2()
        
        if not collided or mr.motion.is_zero_approx():
            break
        
        mr.first_slide = false
    
    return


func _gdscript_move_and_slide_grounded(delta: float) -> void:

    _initialize_moving_resource_variables(delta)

    #region COLLISION ITERATION LOOP
    for iteration in range(max_slides):
        
        var prev_position: Vector2 = global_position
        
        var result: KinematicCollision2D = move_and_collide(mr.motion, false, safe_margin, true)
        var collided: bool = false
        if result:
            collided = true
        
        # Store movement result
        last_motion = result.get_travel() if collided else Vector2()

        if collided:
            #region COLLISION HANDLING
            motion_results.append(result)
            _set_collision_direction_from_motion_test(result)
            
            var collider_vel: Vector2 = result.get_collider_velocity()
            if mr.on_ceiling and collider_vel != Vector2() and collider_vel.dot(up_direction) < 0:
                _handle_ceiling_collision(result, collider_vel)
            if mr.on_floor && floor_stop_on_slope && (velocity.normalized() + up_direction).length() < 0.01:
                _stop_on_slope(result, prev_position)
                break
            if floor_block_on_wall && mr.on_wall && mr.motion_slide_up.dot(result.get_normal()) <= 0:
                if _stopped_by_wall_check(result, prev_position):
                    break
            elif floor_constant_speed && mr.is_on_floor_only() && mr.can_apply_constant_speed && mr.was_on_floor && mr.motion.dot(result.get_normal()) < 0:
                #region MAINTAIN SPEED WHEN CLIMBING SLOPES
                mr.can_apply_constant_speed = false
                var motion_slide_norm: Vector2 = result.get_remainder().slide(result.get_normal()).normalized()
                mr.motion = motion_slide_norm * (mr.motion_slide_up.length() - result.get_travel().slide(up_direction).length() - mr.last_travel.slide(up_direction).length())
                #endregion MAINTAIN SPEED WHEN CLIMBING SLOPES
            elif (mr.sliding_enabled || !mr.on_floor) && (!mr.on_ceiling || slide_on_ceiling || !mr.vel_dir_facing_up) && !mr.apply_ceiling_velocity:
                #region STANDARD SLIDING BEHAVIOR
                var slide_motion: Vector2 = result.get_remainder().slide(result.get_normal())
                mr.motion = slide_motion if slide_motion.dot(velocity) > 0.0 else Vector2()
                if slide_on_ceiling && mr.on_ceiling:
                    # Handle ceiling sliding special case
                    velocity = velocity.slide(result.get_normal()) if mr.vel_dir_facing_up else up_direction * up_direction.dot(velocity)
                #endregion STANDARD SLIDING BEHAVIOR
            else:
                # Fallback motion handling
                mr.motion = result.get_remainder()
                if mr.on_ceiling && !slide_on_ceiling && mr.vel_dir_facing_up:
                    velocity = velocity.slide(up_direction)
                    mr.motion = mr.motion.slide(up_direction)
            
            mr.last_travel = result.get_travel()
            #endregion COLLISION HANDLING
        elif floor_constant_speed && mr.first_slide && _on_floor_if_snapped() && mr.prev_floor_normal.is_normalized():
            #region NO-COLLISION CONSTANT SPEED HANDLING
            # Maintain speed when moving down slopes without collisions
            mr.can_apply_constant_speed = false
            mr.sliding_enabled = true
            global_position = prev_position
            var motion_slide_norm: Vector2 = mr.motion.slide(mr.prev_floor_normal).normalized()
            mr.motion = motion_slide_norm * mr.motion_slide_up.length()
            collided = true
            #endregion NO-COLLISION CONSTANT SPEED HANDLING

        #region LOOP CONTROL UPDATES
        mr.can_apply_constant_speed = !mr.can_apply_constant_speed && !mr.sliding_enabled
        mr.sliding_enabled = true
        mr.first_slide = false
        
        if !collided || mr.motion.is_zero_approx():
            break
        #endregion LOOP CONTROL UPDATES
    #endregion COLLISION ITERATION LOOP

    #region POST-MOVEMENT ADJUSTMENTS
    _snap_on_floor()
    
    # Wall velocity projection
    if mr.is_on_wall() && mr.motion_slide_up.dot(motion_results[0].get_normal()) < 0:
        var slide_motion: Vector2 = velocity.slide(motion_results[0].get_normal())
        velocity = up_direction * up_direction.dot(velocity) + (slide_motion.slide(up_direction) if mr.motion_slide_up.dot(slide_motion) >= 0 else Vector2())
    
    # Floor velocity adjustment
    if mr.on_floor && !mr.vel_dir_facing_up:
        velocity = velocity.slide(up_direction)
    #endregion POST-MOVEMENT ADJUSTMENTS

    return



## This function determines if the ceiling platform velocity can be added to the body and adds it if it can.
func _handle_ceiling_collision(result: KinematicCollision2D, collider_vel: Vector2) -> void:

    if (!mr.slide_on_ceiling || mr.motion.dot(up_direction) < 0 || (result.get_normal() + up_direction).length() < 0.01):
        mr.apply_ceiling_velocity = true
        var ceiling_vert_vel: Vector2 = up_direction * up_direction.dot(collider_vel)
        var motion_vert_vel: Vector2 = up_direction * up_direction.dot(velocity)
        if motion_vert_vel.dot(up_direction) > 0 || ceiling_vert_vel.length_squared() > motion_vert_vel.length_squared():
            velocity = ceiling_vert_vel + velocity.slide(up_direction)
    return


## This function stops the body from moving down slopes when it has a downward velocity if floor_stop_on_slope is set to true in the CharacterBody2D
func _stop_on_slope(result: KinematicCollision2D, prev_position: Vector2) -> void:

    if result.get_travel().length() <= safe_margin + 1e-5:
        global_position = prev_position
    velocity = Vector2()
    last_motion = Vector2()
    mr.motion = Vector2()
    return



## This function checks if the body should be stopped by a wall or not and stops it if so
func _stopped_by_wall_check(result: KinematicCollision2D, prev_position: Vector2) -> bool:

    if mr.was_on_floor && !mr.on_floor && !mr.vel_dir_facing_up:
        if result.get_travel().length() <= safe_margin + 1e-5:
            global_position = prev_position
        _snap_on_floor()
        velocity = Vector2()
        last_motion = Vector2()
        mr.motion = Vector2()
        return true
    elif !mr.on_floor:
        # Adjust motion for wall sliding
        mr.motion = up_direction * up_direction.dot(result.get_remainder())
        mr.motion = mr.motion.slide(result.get_normal())
    else:
        mr.motion = result.get_remainder()
    return false


## Helper function checks the collision angle and sets the correct boolean in the move resource
func _set_collision_direction_from_motion_test(result: KinematicCollision2D) -> void:

    if motion_mode == MOTION_MODE_GROUNDED and result.get_angle(up_direction) <= floor_max_angle + FLOOR_ANGLE_THRESHOLD:
        mr.on_floor = true
        floor_normal = result.get_normal()
        _set_platform_data(result)
    elif motion_mode == MOTION_MODE_GROUNDED and result.get_angle(-up_direction) <= floor_max_angle + FLOOR_ANGLE_THRESHOLD:
        mr.on_ceiling = true
    else:
        mr.on_wall = true
        wall_normal = result.get_normal()
        if motion_mode == MOTION_MODE_GROUNDED:
            var left_wall_angle: float = abs(wall_normal.angle_to(up_direction.rotated(deg_to_rad(90.0))))
            var right_wall_angle: float = abs(wall_normal.angle_to(up_direction.rotated(deg_to_rad(-90.0))))
            var max_angle: float = floor_max_angle + FLOOR_ANGLE_THRESHOLD
            if left_wall_angle <= max_angle or is_equal_approx(left_wall_angle, max_angle):
                mr.on_left_wall = true
            elif right_wall_angle <= max_angle or is_equal_approx(right_wall_angle, max_angle):
                mr.on_right_wall = true
    return



## Helper function snaps the body to the floor if it is close enough
func _snap_on_floor() -> void:

    if !mr.on_floor && mr.was_on_floor && !mr.vel_dir_facing_up:
        var snap: Vector2 = -up_direction * floor_snap_length
        var collision: KinematicCollision2D = move_and_collide(snap, true)
        if collision:
            mr.on_floor = true
            floor_normal = collision.get_normal()
    return



## Helper function determines if the floor can be snapped to
func _on_floor_if_snapped() -> bool:

    if up_direction == Vector2() or mr.on_floor or not mr.was_on_floor or mr.vel_dir_facing_up:
      return false
    
    var length: float = maxf(floor_snap_length, safe_margin)
    var snap_motion: Vector2 = -up_direction * length
    var collision: KinematicCollision2D = move_and_collide(snap_motion, true)
    
    if collision != null:
        var normal: Vector2 = collision.get_normal()
        var floor_angle: float = abs(normal.angle_to(up_direction))
        if floor_angle <= floor_max_angle + FLOOR_ANGLE_THRESHOLD:
            return true
    return false



## Helper function that sets the platform variables in the move resource
func _set_platform_data(collision: KinematicCollision2D) -> void:

    mr.platform_rid = collision.get_collider_rid()
    mr.platform_object_id = collision.get_collider_id()
    mr.platform_velocity = collision.get_collider_velocity()
    mr.platform_layer = PhysicsServer2D.body_get_collision_layer(mr.platform_rid)
    return



## Helper function initializes all the resource variables when starting a body movement
func _initialize_moving_resource_variables(delta: float) -> void:

    # Calculate initial motion vectors and reset collision state
    mr.motion = velocity * delta
    mr.motion_slide_up = mr.motion.slide(up_direction)

    mr.prev_floor_normal = floor_normal

    mr.platform_rid = RID()
    mr.platform_object_id = 0
    floor_normal = Vector2()

    # Configure sliding behavior flags
    mr.sliding_enabled = !floor_stop_on_slope
    mr.can_apply_constant_speed = mr.sliding_enabled
    mr.apply_ceiling_velocity = false
    mr.first_slide = true
    mr.vel_dir_facing_up = velocity.dot(up_direction) > 0
    mr.last_travel = Vector2()
    return
