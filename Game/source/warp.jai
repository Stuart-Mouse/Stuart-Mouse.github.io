
WARP_DOOR_ENTRY_TIME :: 0.25;
WARP_DOOR_EXIT_TIME  :: 0.50;

Warp :: struct {
    using #as base: Entity;
    local_id:       int;            // uniquely identifies a warp within a level layout
    dst_locator:    Warp_Locator;
    warp_form:      Warp_Form;
    warp_type:      Warp_Type;
    warp_flags:     Warp_Flags;
}

Warp_Locator :: struct {
    local_id:   int;
    level_name: [16] u8;
    area_name:  [16] u8;
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

// TODO: maybe make palette id a parameter for init'ing entities in general
init_warp_entity :: (warp: *Warp) {
    warp.* = .{
        entity_type = .WARP,
        palette = get_color_animation_index("girders"),
    };
    warp.size = get_warp_size(warp);
}

update_warp :: (using warp: *Warp) {
    // remove this flag, will be set by player update if player is still using the warp
    warp_flags &= ~.PLAYER_USING_THIS_FRAME;
    
    // TODO: we probably only need to call get_warp_size on warp entity init
    size = get_warp_size(warp);
    
    player := *get_active_level().player;
    player_controller := get_controller(player);
    
    warp_rect   := get_collision_rect(warp);
    player_rect := get_collision_rect(player);
    
    // TODO: we will later be able to rotate warp entities as they'll be connected to a tilemap, probably
    if player.state == .STANDARD 
    && player_controller.UP.state == .PRESSED
    && is_point_within_frect(player.position, warp_rect) {
        begin_entering_warp(player, warp);
    }
}

render_warp :: (warp: *Warp, render_unit: float, offset: Vector2, alpha_mod: float) {
    // TODO: actually render door for that warp type
    if warp.warp_form == {
      case .DOOR;
        door_clip := Rectf.{ 192, 0, 16, 32 };
        render_size := warp.size * render_unit;
        render_position := (warp.position + offset) * render_unit - render_size/2;
        
        // if player is currently using door, we colormod it to all black, so that it appears to be open
        color := Color4.{ 1, 1, 1, alpha_mod };
        if warp.warp_flags & .PLAYER_USING_THIS_FRAME {
            color.rgb = .{ 0, 0, 0 };
        }
        
        render_draw_quad(
            texture  = *entities_texture,
            color    = color,
            position = render_position,
            size     = render_size,
            clip     = *door_clip,
            palette  = warp.palette,
            rotate   = warp.rotation
        );
        
      case;
        warp_rect := get_collision_rect(warp);
        warp_rect.position += offset;
        warp_rect *= render_unit;
        render_draw_rect(warp_rect, color = .{1,0,0,alpha_mod});
    }
    
    // for now, just rendering some text so that we can at least see the entity
    text_position := (warp.position + offset) * render_unit;
    text_size := Vector2.{ 1, 1 } * render_unit * 0.25;
    render_small_text("%", warp.local_id, position = text_position, size = text_size, align = 0.5);
}

// if the level/area name are empty, we assume that the warp references the current level/area
find_level_and_area :: (locator: Warp_Locator) -> (found: bool, level_index: int, area_index: int) {
    level_name := to_string(locator.level_name.data);
    area\_name := to_string(locator.area\_name.data);
    
    level_index, area_index := -1;
    
    if level_name {
        for *Game.worldmap.levels {
            if it.name == level_name {
                level_index = it_index;
                break;
            }
        }
    }
    else {
        level_index = Game.worldmap.active_level;
        
        // special case for level layout copied from editor, no need to check the area index
        if level_index == -1 {
            return true, -1, -1;
        }
    }
    
    if level_index >= 0 {
        if area_name {
            level := *Game.worldmap.levels[level_index];
            for level.areas {
                if it.name == area_name {
                    area_index = it_index;
                    break;
                }
            }
        }
        else area_index = Game.worldmap.active_area;
        
        if area_index >= 0 {
            return true, level_index, area_index;
        }
    }
    
    return false, 0, 0;
}


create_door_entry_particles :: (position: Vec2f) {
    particle_count := 8;
    
    for 0..particle_count-1 {
        slot := get_next_slot(*get_active_level().particles.front);
        slot.occupied = true;
        
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
        
        slot.data = .{
            texture         = *particles_texture,
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