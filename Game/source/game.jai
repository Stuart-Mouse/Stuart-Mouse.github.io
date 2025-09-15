
Game: struct {
    worldmap: Worldmap;
    
    loaded_level_layouts:   Table(string, *Level_Layout);
    saved_level_state:      [..] Level_Saved_State;
    
    active_level: struct {
        id:                 Level_ID;
        map_index:          Vec2i;
        info_index:         int;
        layout_index:       int;
        layout:             Level_Layout;
        saved_state_index:  int;
    }
    
    player:             Player;
    player_controllers: [1] Player_Controller;
    
    // For events that occur outside the context of a single layout, we just put those on the gamestate directly.
    // So we just set the proper event flag and properties and the gamestate will have to handle it.
    // The presumption here is also that we won't have multiple of this class of event happening at once, or if we do we will have to decide which one(s) actually gets executed and in what order.
    event_flags: enum_flags { SCENE_TRANSITION; };
    
    scene_transition:   Scene_Transition;
    checkpoint:         Checkpoint;
    
    
    // frame timing info
    last_update_time:           Apollo_Time;
    last_render_time:           Apollo_Time;
    render_delta_time:          float;
    
    viewport: Rect;
};

Checkpoint :: struct {
    warp_locator: Warp_Locator;
}

reset_level_cache :: () {
    Editor.level = null;
    
    for Game.loaded_level_layouts {
        deinit_level(it);
        free(it_index);
    }
    
    table_reset(*Game.loaded_level_layouts);
}

get_active_level :: inline () -> *Level_Layout { 
    return *Game.active_level.layout;
}

get_game_mouse :: () -> *Mouse {
    #if EDITOR_ENABLED {
        context.mouse = ifx !ImGui.GetIO().WantCaptureMouse then *global_mouse;
    } else {
        context.mouse = *global_mouse;
    }
    return context.mouse;
}

update_game :: () {
    using Game;
    
    context.current_level = get_active_level();
    level := context.current_level;
    
    current_time := current_time_monotonic();
    
    microseconds_since_last_update := max(to_microseconds(current_time - last_update_time), 0);
    microseconds_safety_margin := 0;
    
    should_update := ifx !vsync_enabled then microseconds_since_last_update + microseconds_safety_margin >= microseconds_per_update else true;
    
    update_iteration := 0;
    UPDATE_ITERATION_HARD_LIMIT :: 4;
    while update_loop := should_update {
        if update_iteration >= UPDATE_ITERATION_HARD_LIMIT {
            last_update_time = current_time;
            break update_loop;
        }
        defer {
            update_iteration += 1;
            last_update_time += microseconds_to_apollo(microseconds_per_update);
            if !vsync_enabled {
                microseconds_since_last_update -= microseconds_per_update;
                should_update = microseconds_since_last_update + microseconds_safety_margin >= microseconds_per_update;
            } else {
                should_update = update_iteration < updates_per_frame.(int);
            }
        }
        
        Input.update_window_events();
        
        
        #if EDITOR_ENABLED { imgui_handle_input_events(Input.events_this_frame); }
        process_input_events();
        update_mouse(*global_mouse);
        #if GAMEPAD_SUPPORTED { update_gamepad(); }
        // #if EDITOR_ENABLED { 
            update_input_controller(editor_controller.data);
        // }
        
        for *player_controllers {
            update_input_controller(it.data, should_read_gamepad = it_index == 0);
        }
        
        // handle global hotkeys
        {
            if editor_controller.GAME_RESET_LEVEL.state == .PRESSED {
                Game.player.is_dead = 1; // have to do this to get a proper reinit on player
                begin_level_with_id(to_string(*Game.active_level.id));
            }
            #if EDITOR_ENABLED {
                if editor_controller.SET_STATE_EDITOR.state == .PRESSED {
                    pause_music();
                    Program_State = .EDITOR;
                    return;
                }
                if editor_controller.TOGGLE_SHOW_DEBUG_WINDOW.state == .PRESSED {
                    show_debug_window = !show_debug_window;
                }
            }
            
            // TODO: should have a straghtforward load_game_assets proc
            if editor_controller.RELOAD_ASSETS.state == .PRESSED {
                load_color_palette();
                
                load_tile_info();
                load_player_templates();
                load_entity_templates();
                
                free_textures();
                load_textures();
                
                copy_editor_level_to_active_level();
                print("assets reloaded\n");
                break update_loop;
                
                // TODO: do we need to break here?
                // should we return and just set some flag to reload assets like in fire rescue?
            }
            
            if editor_controller.TOGGLE_FULLSCREEN.state == .PRESSED {
                toggle_fullscreen();
            }
        }
        
        // for scene transition, we will just completely skip the update for the current scene
        // we will only update the logic for the transition itself 
        if event_flags & .SCENE_TRANSITION {
            handle_scene_transition();
            continue update_loop;
        }
        
        
        // ACTUAL LEVEL UPDATE LOGIC BEGINS
        // TODO: factor into some update_level routine?
        
        // In certain circumstances, we don't want to advance the level timer, 
        //   essentially pausing everything which operates based on that timer.
        // For example, when the player collects a powerup or enters a door.
        should_update_time := true;
        defer if should_update_time  level.ticks_since_start += 1;
        
        // Set time_since_start every frame so that other things can read it.
        level.time_since_start = level.ticks_since_start.(float) * microseconds_per_update.(float) / 1000000.0;

        should_update_tilemaps  := true;
        should_update_players   := true;
        should_update_entities  := true;
        should_update_particles := true;
        should_process_events   := true;
        
        if player.state == {
          case .ENTERING_WARP;  #through;
          case .EXITING_WARP;
            // TODO: would need to prevent updating of other players in multiplayer
            should_update_tilemaps  = false;
            should_update_entities  = false;
            should_update_time      = false;
        }
        
        if player.is_dead > 0 {
            should_update_tilemaps  = false;
            should_update_entities  = false;
            should_process_events   = false;
        }
        
        if should_update_tilemaps {
            for *level.tilemaps  update_tilemap_prescript(it);
            execute_level_script(level);
            for *level.tilemaps  update_tilemap_postscript(it);
        }
        
        if should_update_entities {
            live_entities = 0;
            for *level.entities {
                live_entities += 1;
                update_entity(it);
                if it.flags & .REMOVE_ME then remove;
            }
        }
        
        if should_update_players {
            update_player(*Game.player);
        }
        
        if should_update_particles {
            for *level.particles.front {
                if !update_particle(it) {
                    free_particle(it);
                    remove;
                }
            }
            
            for *level.particles.middle {
                if !update_particle(it) {
                    free_particle(it);
                    remove;
                }
            }
            
            for *level.particles.back {
                if !update_particle(it) {
                    free_particle(it);
                    remove;
                }
            }
            
            spawn_cloud_particles(level);
        }
        
        if should_process_events {
            // process_new_events(*level.event_queue);
        }
    }
}

set_game_viewport :: () {
    tile_render_unit = (max(min(window_width  / (16 * 40), window_height / (16 * 30)), 1) * 16).(float);
    context.layout_context.tile_unit = tile_render_unit;
    
    game_layout :: Layout.{
        size = .{
            units = .TILE,
            value = .{ 40, 30 },
        },
        position = .{
            units = .WINDOW,
            value = .{ 0.5, 0.5 },
        },
        offset = .{
            units = .SELF,
            value = .{ -0.5, -0.5 },
        },
    };
    
    Game.viewport = to_Rect(get_rect(game_layout));
    
    if Game.viewport.w > window_width {
        Game.viewport.x = 0;
        Game.viewport.w = xx window_width;
    }
    if Game.viewport.h > window_height {
        Game.viewport.y = 0;
        Game.viewport.h = xx window_height;
    }
}

render_game :: () {
    using Game;
    
    current_time := current_time_monotonic();
    defer last_render_time = current_time;
    
    us_since_last_render := max(to_microseconds(current_time - last_render_time), 0);
    render_delta_time = us_since_last_render.(float) / 1000000.0;
    
    level := get_active_level();
    mouse := get_game_mouse();
    
    // RENDER HUD
    
    // TODO: should not have to recalculate game viewport every frame
    set_game_viewport();
    render_set_viewport(*Game.viewport); 
    
    render_begin_batch();
    
    hud_height := (2 * tile_render_unit).(s32);
    
    render_draw_quad(position = .{}, size = .{ xx viewport.w, xx hud_height }, color = .{0,0,0,1});
    render_player_hud(*Game.player, tile_render_unit, .{ 0.5, 0.5 } * tile_render_unit);
    
    render_end_batch();
    render_flush();
    
    // RENDER LEVEL
    
    viewport.y += hud_height;
    viewport.h -= hud_height;
    render_set_viewport(*viewport);
    
    update_tile_animations();
    update_camera(0.25 * 60 * render_delta_time); // TODO: adjust for delta time
    
    render_begin_batch();
    
    // draw level background
    render_draw_quad(
        position = (level.bounds.position - level.camera) * tile_render_unit, 
        size     = level.bounds.size * tile_render_unit, 
        palette  = get_color_animation_index("background"),
        do_color_per_vertex = false,
    );
    
    for *level.particles.back  render_particle(it, tile_render_unit, -level.camera);
    
    render_end_batch();
    render_flush();
    
    tilemaps_sorted := get_tilemaps_sorted(level.tilemaps);
    tilemaps_back, tilemaps_fore: [] *Tilemap;
    
    for tilemaps_sorted {
        if it.z_index >= 0 {
            tilemaps_back = array_view(tilemaps_sorted, 0, it_index);
            tilemaps_fore = array_view(tilemaps_sorted, it_index);
            break;
        }
        if it_index == tilemaps_sorted.count-1 {
            tilemaps_back = tilemaps_sorted;
        }
    }
    
    for tilemaps_back {
        render_begin_batch();
        // NOTE: We use floor() here to prevent fractional pixel offsets. 
        //       This helps prevent weird graphical bugs, primarily gaps between tiles of tilemap.
        // TODO: we should do something similar when rendering entities, methinks.
        render_offset := floor((it.offset - level.camera) * tile_render_unit); 
        render_tilemap(it, tile_render_unit, offset = render_offset);
        
        render_end_batch();
        render_flush();
    }
    
    render_begin_batch();
    
    for *level.particles.middle  render_particle(it, tile_render_unit, -level.camera);
    
    for *level.entities {
        if should_render_before_player(it) {
            render_entity(it, tile_render_unit, -level.camera);
        }
    }
    
    render_player(*Game.player, tile_render_unit, -level.camera);
    
    // render_draw_line((mouse_ray_start_position-level.camera) * tile_render_unit, (mouse_ray_end_position-level.camera) * tile_render_unit, .{1,0,1,1}, 2);
    
    for *level.entities {
        if !should_render_before_player(it) {
            render_entity(it, tile_render_unit, -level.camera);
        }
    }
    
    render_end_batch();
    render_flush();
    
    for tilemaps_fore {
        render_begin_batch();
        // NOTE: We use floor() here to prevent fractional pixel offsets. 
        //       This helps prevent weird graphical bugs, primarily gaps between tiles of tilemap.
        // TODO: we should do something similar when rendering entities, methinks.
        render_offset := floor((it.offset - level.camera) * tile_render_unit); 
        render_tilemap(it, tile_render_unit, offset = render_offset);
        
        render_end_batch();
        render_flush();
    }
    
    render_begin_batch();
    
    for *level.particles.front  render_particle(it, tile_render_unit, -level.camera);
    
    if event_flags & .SCENE_TRANSITION {
        using Game.scene_transition;
        lerp := clock.(float) / (Scene_Transition.TRANSITION_FADE_TIME * updates_per_second);
        lerp = smooth_0_to_1(1-lerp);
        
        if flags & .FADING_IN {
            position := Vec2f.{ x = -window_width * (lerp) };
            render_draw_quad(
                position = position,
                size     = Vec2f.{ window_width.(float), window_height.(float) },
                color    = .{ 0, 0, 0, 1 }
            );
        } else {
            position := Vec2f.{ x = window_width * (1-lerp) };
            render_draw_quad(
                position = position,
                size     = Vec2f.{ window_width.(float), window_height.(float) },
                color    = .{ 0, 0, 0, 1 }
            );
        }
    }
    
    render_end_batch();
    render_flush();
}

update_camera :: (smoothing: float) {
    // TODO: put some actual 'locked' flag on the camera instead of this BS
    if mouse_right() & .PRESSED then return;
    using level := get_active_level();
    
    viewport := render_get_viewport();
    
    // we determine the center point of the camera, modify that, and then use new center point to set new top-left point
    cam_size   := to_Vec2f(viewport.size) / tile_render_unit;
    cam_center := camera + cam_size / 2;
    
    top_bound    := bounds.y            + cam_size.y / 2;
    bottom_bound := bounds.y + bounds.h - cam_size.y / 2;
    
    if top_bound >= bottom_bound {
        cam_center.y = (top_bound + bottom_bound) / 2;
    } else {
        move_y := Game.player.camera.focus_point.y - cam_center.y;
        if abs(move_y) < (1.0/tile_render_unit) then move_y = 0;
        if smoothing then move_y /= (frames_per_second * smoothing);
        cam_center.y += move_y;
        if cam_center.y <    top_bound then cam_center.y = top_bound;
        if cam_center.y > bottom_bound then cam_center.y = bottom_bound;
    }
    
    
    left_bound  := bounds.x            + cam_size.x / 2;
    right_bound := bounds.x + bounds.w - cam_size.x / 2;
    
    if left_bound >= right_bound {
        cam_center.x = (left_bound + right_bound) / 2;
    } else {
        move_x := Game.player.camera.focus_point.x - cam_center.x;
        if abs(move_x) < (1.0/tile_render_unit) then move_x = 0;
        if smoothing then move_x /= (frames_per_second * smoothing);
        cam_center.x += move_x;
        if cam_center.x <  left_bound then cam_center.x = left_bound;
        if cam_center.x > right_bound then cam_center.x = right_bound;
    }
    
    camera = cam_center - cam_size / 2;
}

get_camera_visible_rect :: (pad := Vec2f.{}) -> Rectf {
    visible_rect: Rectf;
    visible_rect.size = .{ window_width.(float), window_height.(float) } / tile_render_unit + pad;
    visible_rect.position = context.current_level.camera - pad/2;
    return visible_rect;
}

spawn_cloud_particles :: (level: *Level_Layout) {
    // we should have an actual particle spawner struct with its own particle slots for this
    // that way we can more easily render it behind everything else, and also limit the spawning to a set amount
    if level.time_since_start >= level.cloud_spawn_time {        
        slot := get_next_slot(*get_active_level().particles.back);
        slot.occupied = true;
        
        position := Vec2f.{
            random_get_within_range(level.bounds.x, level.bounds.x + level.bounds.w),
            random_get_within_range(level.bounds.y, level.bounds.y + 6),
        };
        
        offset := Vec2f.{ random_get_within_range(-5, -15), 0 };
        
        active_time_seconds := random_get_within_range(5.0, 10.0);
        
        // scale_start := random_get_within_range(0.8, 1.2);
        scale_start := 1.0;
        scale_end   := scale_start;
        alpha := random_get_within_range(0.5, 0.9);
        
        fade_in_easing_proc  :: (l: float, p1: float, p2: float) -> float { return smooth_0_to_1(l); };
        fade_out_easing_proc :: (l: float, p1: float, p2: float) -> float { return smooth_0_to_1(l); };
        
        slot.data = .{
            texture = *textures.PARTICLES,
            palette = get_color_animation_index("white"),
            
            particle_type = .CLOSED_FORM,
            closed_form = .{
                position        = .{ start = position,       end = position + offset },
                scale           = .{ start = scale_start,    end = scale_end },
                color           = .{ start = .{1,1,1,alpha}, end = .{1,1,1,alpha} },
                
                fade_in         = .{ start = 0, end = 0.5, easing = .{ proc = fade_in_easing_proc } },
                fade_out        = .{ start = 0.5, end = 1, easing = .{ proc = fade_out_easing_proc } },
                
                timing          = .GLOBAL,
                start_time      = seconds_since_init().(float),
                lifetime        = active_time_seconds,
            }
        };
        
        anim := *slot.animation;
        anim.frame_count = 1;
        anim.frames[0] = .{ clip = .{ 8, 0, 32, 24 }, duration = 1.0 };
        
        level.cloud_spawn_time = level.time_since_start + 100.0 / level.bounds.w.(float);;
    }
}

// ================================
//      SCENE TRANSITION STUFF
// ================================

// Scene_Transition_Style :: enum {
//     WIPE_LEFT;
//     WIPE_RIGHT;
//     WIPE_UP;
//     WIPE_DOWN;
//     WIPE_CRUNCH_HORIZONTAL;
//     WIPE_CRUNCH_VERTICAL;
// }

Scene_Type :: enum {
    LEVEL;
    // WORLDMAP;
}

Scene_Transition :: struct {
    src_scene_type:      Scene_Type;
    dst_scene_type:      Scene_Type;
    
    // fade_out_style:      Scene_Transition_Style;
    // fade_in\_style:      Scene_Transition_Style;
    
    // fade_out_timespan: Range(float); // 0-1 range during which we display and fade the src scene
    // fade_in\_timespan: Range(float); // 0-1 range during which we display and fade the dst scene
    
    level_transition: struct {
        flags:              enum_flags { USING_WARP; };
        warp_locator:       Warp_Locator;
        player_position:    Vec2f;
    }
    
    clock:  int;
    flags:  enum_flags { FADING_IN; };
    
    TRANSITION_FADE_TIME :: 0.0;
};

handle_scene_transition :: () {
    using Game.scene_transition;
    
    clock -= 1;
    if clock <= 0 {
        if flags & .FADING_IN {
            Game.event_flags &= ~.SCENE_TRANSITION;
        } else {
            if dst_scene_type == {
              case .LEVEL;
                // TODO: in the future we will probably only be using warps for this, 
                // instead of having automatic level transitions when player goes out of level bounds
                if level_transition.flags & .USING_WARP {
                    begin_level_with_warp(level_transition.warp_locator);
                } else {
                    level_name := to_string(*level_transition.warp_locator.level_name);
                    begin_level_with_id(level_name);
                    Game.player.position = level_transition.player_position;
                }
            }
            flags |= .FADING_IN;
            clock = (TRANSITION_FADE_TIME * updates_per_second).(int);
        }
    }
}
