

/*
    basic moving platform
        render range in editor
        
    vertical looping platforms
        define path using arbitrary function

    weighted pair of platforms
        independently move each platform?
        
*/

Platform_Type :: enum {
    SINGLE;
    ELEVATOR;
    WEIGHTED;
    FALLING;
}

Platform :: struct {
    using base : Entity;
    // base.position is origin point of platform, does not change
    
    type   : Platform_Type;
    width  : s32;
    
    // position is base position, position_offset is position + offset computed based on cycle
    position_offset : Vector2;
    // speed  : float;
    
    cycle_time : float;
    range      : Vector2;
    
    // only for elevator
    count  : s32;
    
    RENDER_CLIP :: Rectf.{ 80, 16, 8, 8 };
}

// will only need a single clip for platform tile, repeat depending on width

init_platform :: (using platform: *Platform) {
    platform.*  = .{};
    entity_type = .PLATFORM;
    width       = 5;
    range       = .{ 5, 3 };
    cycle_time  = 5;
}

update_platform :: (using platform: *Platform) {
    time := get_active_level().frames_since_start;
    position_prev = (position + position_offset);
    
    if type == {
      case .SINGLE;
        // offset as a function of time
        cycle_time_frames := cycle_time * FRAMES_PER_SECOND;
        lerp := time / cycle_time_frames;
        position_offset = sin(lerp * 2 * PI) * 0.5 * range;
        
        // velocity needs to be computed 
        velocity = (position + position_offset) - position_prev;
                
        platform_rect := get_platform_collision_rect(platform);
        
        plumber := *get_active_level().plumber;
        plumber_rect := get_plumber_collision_rect(plumber);
        
        push_plumber := false;
        
        // TODO: dont use sewpt rect, just use vertical vel
        result, time, dir := swept_aabb_frect(plumber_rect, plumber.velocity, platform_rect, platform.velocity);
        if (result == 1 && dir == .D)
        || (result == 0 && plumber_rect.y + plumber_rect.h - platform_rect.y < 0.125 && plumber.velocity.y > 0) {
            push_plumber = true;
        }
        
        if push_plumber {
            plumber.position.y -= plumber_rect.y + plumber_rect.h - platform_rect.y;
            plumber.velocity.y = 0;
            plumber.flags |= .ON_GROUND;
            plumber.ground_velocity = velocity;
        }
    }
}

editor_update_platform_handle :: (using platform: *Platform, handle: Editor_Grab_Handles) {
    if handle == {
      case .PLATFORM_LIMIT_POS;
        offset := get_grab_offset();
        range = snap_to_nearest_unit((Editor_State.mouse_tile_position - position - offset) * 2, 0.5);
        
      case .PLATFORM_LIMIT_NEG;
        offset := get_grab_offset();
        range = snap_to_nearest_unit((Editor_State.mouse_tile_position - position - offset) * -2, 0.5);
    }
}

editor_get_hovered_platform_handle  :: (using platform: *Platform) -> (handle: Editor_Grab_Handles, offset: Vector2) {
    platform_rect := get_platform_collision_rect(platform);
    
    platform_limit_pos_rect := platform_rect;
    platform_limit_pos_rect.position += range / 2;
    if is_point_within_frect(Editor_State.mouse_tile_position, platform_limit_pos_rect) {
        return .PLATFORM_LIMIT_POS, Editor_State.mouse_tile_position - (platform.position + range/2);
    }
    
    platform_limit_neg_rect := platform_rect;
    platform_limit_neg_rect.position -= range / 2;
    if is_point_within_frect(Editor_State.mouse_tile_position, platform_limit_neg_rect) {
        return .PLATFORM_LIMIT_NEG, Editor_State.mouse_tile_position - (platform.position - range/2);
    }
    
    return .CANNOT_GRAB, .{};
}

render_platform :: (using platform: *Platform, render_unit: float, offset: Vector2, alpha_mod: float = 1) {
    half_width := cast(float) width * 0.5;
    actual_position := position + position_offset;
    
    render_position := Vector2.{
        x = (actual_position.x + offset.x - half_width) * render_unit,
        y = (actual_position.y + offset.y) * render_unit,
    };
    
    render_size := Vector2.{
        x = 0.5 * render_unit,
        y = 0.5 * render_unit,
    };
    
    pieces := platform.width * 2;
    for 0..pieces-1 {
        render_draw_quad(
            color    = .{ 1, 1, 1, alpha_mod },
            texture  = *entities_texture,
            position = render_position,
            size     = render_size,
            clip     = *RENDER_CLIP,
            palette  = .ITEM_COIN, // TODO: enum value correct?
        );
        render_position.x += render_unit / 2;
    }
}

editor_render_platform :: (
    using platform : *Platform, 
    entity_index   : int,
    render_unit    : float, 
    offset         : Vector2, 
    alpha_mod      : float    = 1.0, 
    unplaced       : bool     = false
) {
    render_platform(platform, render_unit, offset, alpha_mod);
    if !unplaced {
        render_platform(platform, render_unit, offset + range/2.0, 0.25 );
        render_platform(platform, render_unit, offset - range/2.0, 0.125);
        render_draw_line(
            (platform.position - range/2.0 + offset) * render_unit, 
            (platform.position + range/2.0 + offset) * render_unit, 
            .{1, 1, .5, 1}
        );
        grab_handle, grab_state := get_grab_state_for_entity(entity_index);
        if grab_handle >= 0 {
            outline_color := Color4.{0.5, 1, 0.5, 0.5};
            if grab_state == .HELD {
                outline_color = .{1, 0.5, 0.5, 0.5};
            }
            
            render_rect: Rectf;
            if grab_handle == {
              case .PLATFORM_LIMIT_POS;
                render_rect = get_platform_collision_rect(platform);
                render_rect.position +=  range / 2 + offset; 
                
              case .PLATFORM_LIMIT_NEG;
                render_rect = get_platform_collision_rect(platform);
                render_rect.position += -range / 2 + offset; 
            }
            
            render_rect *= render_unit;
            render_draw_rect(render_rect, outline_color, 3);
        }
    }
}

// The get collision rect procedures for platforms and firebars are basically useless.
// The only thing they currently do is allow us to delete the entities in the editor.
// We should probably just have a more general "is point within entity" proc that does a point test for the purposes of grabbing things in the editor.
// This will work much better for these mutli-collider entities.
get_platform_collision_rect :: (using platform: Platform) -> Rectf {
    half_width := cast(float) width * 0.5;
    actual_position := position + position_offset;
    return .{ actual_position.x - half_width, actual_position.y, xx width, 0.5 };
}

