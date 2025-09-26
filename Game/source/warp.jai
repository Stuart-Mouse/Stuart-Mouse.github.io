
WARP_DOOR_ENTRY_TIME :: 0.25;
WARP_DOOR_EXIT_TIME  :: 0.25;

Warp :: struct {
    local_id:       int;            // uniquely identifies a warp within a level layout
    dst_locator:    Warp_Locator;
    warp_form:      Warp_Form;
    warp_type:      Warp_Type;
    warp_flags:     Warp_Flags;
}

Warp_Locator :: struct {
    local_id:       int;
    level_name:     Level_ID;
}

Warp_Form :: enum {
    DOOR; 
    PIPE_ENTRY;
}

Warp_Type :: enum { 
    STANDARD; 
    LEVEL_END; 
    WARP_ZONE; 
}

Warp_Flags :: enum_flags {
    EXIT_ONLY;
    IN_POTION;
    
    PLAYER_USING_THIS_FRAME;
}

get_warp_size :: (warp: *Warp) -> Vec2f {
    if #complete warp.warp_form == {
      case .DOOR;       return .{ 1, 2 };
      case .PIPE_ENTRY; return .{ 1, 1 };
    }
    unreachable();
    return .{};
}

update_warp :: (using warp: *Warp) {
    // remove this flag, will be set by player update if player is still using the warp
    // warp_flags &= ~.PLAYER_USING_THIS_FRAME;
    
    // player := *Game.player;
    // player_controller := get_controller(player);
    
    // warp_rect   := get_collision_rect(warp);
    // player_rect := get_collision_rect(player);
    
    // // TODO: we will later be able to rotate warp entities as they'll be connected to a tilemap, probably
    // if player.state == .STANDARD 
    // && player_controller.UP.state == .PRESSED
    // && is_point_within_frect(player.position, warp_rect) {
    //     begin_entering_warp(player, warp);
    // }
}

render_warp :: (warp: *Warp, render_unit: float, offset: Vector2, alpha_mod: float) {
    // TODO: actually render door for that warp type
    // if warp.warp_form == {
    //   case .DOOR;
    //     door_clip := Rectf.{ 192, 0, 16, 32 };
    //     render_size := warp.size * render_unit;
    //     render_position := (warp.position + offset) * render_unit - render_size/2;
        
    //     // if player is currently using door, we colormod it to all black, so that it appears to be open
    //     color := Color4.{ 1, 1, 1, alpha_mod };
    //     if warp.warp_flags & .PLAYER_USING_THIS_FRAME {
    //         color.rgb = .{ 0, 0, 0 };
    //     }
        
    //     render_draw_quad(
    //         texture  = *entities_texture,
    //         color    = color,
    //         position = render_position,
    //         size     = render_size,
    //         clip     = *door_clip,
    //         palette  = warp.palette,
    //     );
        
    //   case;
    //     warp_rect := get_collision_rect(warp);
    //     warp_rect.position += offset;
    //     warp_rect *= render_unit;
    //     render_draw_rect(warp_rect, color = .{1,0,0,alpha_mod});
    // }
    
    // // for now, just rendering some text so that we can at least see the entity
    // text_position := (warp.position + offset) * render_unit;
    // text_size := Vector2.{ 1, 1 } * render_unit * 0.25;
    // render_small_text("%", warp.local_id, position = text_position, size = text_size, align = 0.5);
}

// if the level name is empty, then the warp references the current active level
find_warp_destination :: (locator: Warp_Locator) -> level_id: string {
    level_id := to_string(*locator.level_name);
    return ifx level_id else to_string(*Game.active_level.id);
}

find_warp_entity_by_id :: (layout: *Level_Layout, local_id: int) -> *Entity {
    for *layout.entities {
        if (it.flags & .IS_WARP) && it.warp.local_id == local_id {
            return it;
        }
    }
    return null;
}

intiate_warp :: (locator: Warp_Locator, force_reload := false) {
    level_id := find_warp_destination(locator);
    
    // If warp destination is within the active level, we don't reload.
    // Just find the warp by local id and teleport the player there.
    if !force_reload && level_id == to_string(*Game.active_level.id) {
        warp_entity := find_warp_entity_by_id(context.current_level, locator.local_id);
        if warp_entity  begin_exiting_warp(*Game.player, warp_entity);
        return;
    }
    
    // else the warp is going to initiate a scene transition...
    Game.event_flags |= .SCENE_TRANSITION;
    Game.scene_transition = .{ 
        src_scene_type = .LEVEL, 
        dst_scene_type = .LEVEL, 
        clock          = (Scene_Transition.TRANSITION_FADE_TIME * updates_per_second).(int),
        
        level_transition = .{
            flags = .USING_WARP,
            warp_locator = locator,
        },
    };
}

create_door_entry_particles :: (position: Vec2f) {
    particle_count := 8;
    array := *get_active_level().particles.front;
        
    for 0..particle_count-1 {
        slot := get_next_slot(array, true);
        
        // velocity := Vec2f.{
        //     0.0055 * (random_get_zero_to_one() - 0.5),
        //     0.0055 * (random_get_zero_to_one() - 0.5),
        // } * updates_per_second.(float);
        
        offset := Vec2f.{
            0.45 * random_get_within_range(-1, 1),
            0.75 * random_get_within_range(-1, 1),
        };
        
        offset_2 := offset * 3;
        
        // active_time_seconds := random_get_within_range(0.1, 0.4);
        active_time_seconds := random_get_within_range(0.2, 0.8);
        active_time_frames  := active_time_seconds * updates_per_second;
        
        scale_start := random_get_within_range(0.8, 1.2);
        scale_end   := scale_start * 0.8;
        alpha       := random_get_within_range(0.8, 1.2);
        
        rotation_start := random_get_within_range(0, 360);
        rotation_end   := random_get_within_range(-30, 30) + rotation_start;
        
        slot.* = .{
            texture         = *textures.PARTICLES,
            palette         = get_color_animation_index("white"),
            
            particle_type = .CLOSED_FORM,
            closed_form = .{
                position        = .{ start = position + offset, end = position + offset_2 },
                scale           = .{ start = scale_start,       end = scale_end },
                rotation        = .{ start = rotation_start,    end = rotation_end },
                color           = .{ start = .{1,1,1,alpha},    end = .{1,1,1,alpha} },
                
                fade_in         = .{ start = 0, end = 0.2 },
                fade_out        = .{ start = 0.2, end = 1 },
                start_time      = seconds_since_init().(float),
                lifetime        = active_time_seconds,
                timing          = .GLOBAL,
            }
        };
        
        anim := *slot.animation;
        anim.frame_count = 2;
        anim.frames[0] = .{ clip = .{ 64, 0, 16, 16 }, duration = 0.5 };
        anim.frames[1] = .{ clip = .{ 80, 0, 16, 16 }, duration = 0.5 };
    }
}