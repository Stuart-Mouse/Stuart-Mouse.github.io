
Game: struct {
    worldmap: Worldmap;
    active_layout: Level_Layout;
    
    player_controllers: [4] Player_Controller;
    
    // For events that occur outside the context of a single layout, we just put those on the gamestate directly.
    // So we just set the proper event flag and properties and the gamestate will have to handle it.
    // The presumption here is also that we won't have multiple of this class of event happening at once, or if we do we will have to decide which one(s) actually gets executed and in what order.
    
    event_flags: enum_flags { WARP; SCENE_TRANSITION; };
    warp_event: struct {
        locator: Warp_Locator;
        force_reload: bool;
    };
    
    last_significant_warp: Warp_Locator;
    
    scene_transition: Scene_Transition;
    
    
    // frame timing info
    ms_per_update:          s64;
    last_update_time:       Apollo_Time;
    
    last_render_time:       Apollo_Time;
    render_delta_time:      float;  // delta_time used for variable-step update
};

get_active_level :: inline () -> *Level_Layout { 
    return *Game.active_layout;
}

// TODO: probably figure out a more structure method which uses directional flags
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
    WORLDMAP;
}

Scene_Transition :: struct {
    src_scene:  Scene_Type;
    dst_scene:  Scene_Type;
    // out_style:  Scene_Transition_Style;
    // in\_style:  Scene_Transition_Style;
    clock:      int;
    fading_in:  bool;
    
    TRANSITION_FADE_TIME :: 0.75;
};


/*
    We probably want to keep the the last few loaded levels in memory so that we don't have to reload them constantly
    if for example we move from one level to a bonus room and then back into the same main area.
    will use a simple array and linear search for level by name
    
    need to figure out system for determining when to show level transition screens / cutscenes
*/

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
    
    did_update := false;
    current_time := current_time_monotonic();
    defer if did_update then last_update_time = current_time;
    
    ms_since_last_update := max(to_milliseconds(current_time - last_update_time), 0);
    ms_per_update = (1000.0 / updates_per_second.(float)).(s64);
    
    should_update := ifx do_manual_timing then ms_since_last_update >= ms_per_update else true;
    
    update_iteration := 0;
    UPDATE_ITERATION_HARD_LIMIT :: 4;
    while update_loop := should_update {
        if update_iteration >= UPDATE_ITERATION_HARD_LIMIT then break update_loop;
        defer {
            update_iteration += 1;
            if do_manual_timing {
                ms_since_last_update -= ms_per_update;
                should_update = ms_since_last_update >= ms_per_update;
            } else {
                should_update = update_iteration < updates_per_frame.(int);
            }
        }
        did_update = true;
        
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
                copy_editor_level_to_active_level();
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
                load_enemy_templates();
                
                copy_editor_level_to_active_level();
                print("assets reloaded\n");
                
                // TODO: do we need to break here?
                // should we return and just set some flag to reload assets like in fire rescue?
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
        level.time_since_start = level.ticks_since_start.(float) * ms_per_update.(float) / 1000.0;
        
        do_mouse_ray_collision_test();

        should_update_tilemaps  := true;
        should_update_players   := true;
        should_update_entities  := true;
        should_update_particles := true;
        should_process_events   := true;
        
        // TODO: also pause the game world when player is undergoing a powerup change
        if level.player.state == {
          case .ENTERING_WARP;  #through;
          case .EXITING_WARP;
            // TODO: would need to prevent updating of other players in multiplayer
            should_update_tilemaps  = false;
            should_update_entities  = false;
            should_update_time      = false;
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
                if (it.entity_flags & .REMOVE_ME) {
                    remove;
                }
            }
        }
        
        if should_update_players {
            update_player(*level.player);
        }
        
        if should_update_particles {
            for *level.particles.front {
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
            process_new_events(*level.event_queue);
            process_warp_event();
        }
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
    
    update_tile_animations();
    update_camera(0.25 * 60 * render_delta_time); // TODO: adjust for delta time
    
    // draw level background
    render_draw_quad(
        position = (level.bounds.position - level.camera) * tile_render_unit, 
        size     = level.bounds.size * tile_render_unit, 
        color    = level.bg_color,
        depth    = 1.0
    );
    
    for *level.particles.back  render_particle(it, tile_render_unit, -level.camera);
    
    render_end_batch();
    render_flush();
    
    tilemaps_sorted := get_tilemaps_sorted(level.tilemaps);
    for tilemaps_sorted {
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
    
    for *level.entities {
        if should_render_before_player(it) {
            render_entity(it, tile_render_unit, -level.camera);
        }
    }
    
    render_player(*level.player, tile_render_unit, -level.camera);
    
    render_draw_line((mouse_ray_start_position-level.camera) * tile_render_unit, (mouse_ray_end_position-level.camera) * tile_render_unit, .{1,0,1,1}, 2);
    
    for *level.entities {
        if !should_render_before_player(it) {
            render_entity(it, tile_render_unit, -level.camera);
        }
    }
    
    for *level.particles.front  render_particle(it, tile_render_unit, -level.camera);
    
    render_player_hud(*level.player, tile_render_unit, .{ 1, 1 } * tile_render_unit);
    
    
    if event_flags & .SCENE_TRANSITION {
        using Game.scene_transition;
        lerp := clock.(float) / (Scene_Transition.TRANSITION_FADE_TIME * updates_per_second);
        lerp = smooth_0_to_1(1-lerp);
        
        if fading_in {
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
        move_y := player.camera.focus_point.y - cam_center.y;
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
        move_x := player.camera.focus_point.x - cam_center.x;
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

handle_scene_transition :: () {
    using Game.scene_transition;
    
    if clock <= 0 {
        if fading_in {
            Game.event_flags &= ~.SCENE_TRANSITION;
            return;
        } else {
            if dst_scene == {
              case .LEVEL;
                if Game.event_flags & .WARP {
                    Game.event_flags &= ~.WARP;
                    begin_area_with_warp(Game.warp_event.locator);
                }
            }
            fading_in = true;
            clock = (TRANSITION_FADE_TIME * updates_per_second).(int);
        }
    }
    clock -= 1;
}

// similar to begin_area_with_warp, but instead of warping to a new area immediately, we just kick off a scene transition
process_warp_event :: () {
    if !(Game.event_flags & .WARP)  return;
    Game.event_flags &= ~.WARP;
    
    using Game.worldmap;
    
    locator := Game.warp_event.locator;
    found, level_index, area_index := find_level_and_area(locator);
    if !found {
        log("Warp destination could not be resolved: %, %, %", locator.local_id, to_string(locator.level_name.data), to_string(locator.area_name.data));
        return;
    }
    log("Warping to: %, %, %", locator.local_id, to_string(locator.level_name.data), to_string(locator.area_name.data));
    
    if !Game.warp_event.force_reload {
        // If warp destination is within the same layout, we don't reload.
        // Just find the warp by local id and teleport the player there.
        if level_index == active_level
        && area_index  == active_area {
            layout := context.current_level;
            for *layout.entities {
                if it.entity_type == .WARP 
                && it.warp.local_id == locator.local_id {
                    begin_exiting_warp(*layout.player, xx it);
                    break;
                }
            }
            return;
        }
    }
    
    log("starting scene transition");
    
    Game.event_flags |= .SCENE_TRANSITION;
    Game.scene_transition = .{ 
        src_scene = .LEVEL, 
        dst_scene = .LEVEL, 
        clock     = (Scene_Transition.TRANSITION_FADE_TIME * updates_per_second).(int)
    };
    
    // put the warp event flag back on, will finish processing it when scene transition is done fading out.
    Game.event_flags |= .WARP;
    Game.warp_event.force_reload = true;
}


execute_level_script :: (layout: *Level_Layout, show_imgui := false) {
    defer_restore(*context.current_level);
    context.current_level = layout;
    
    if show_imgui {
        // imgui.Begin("Level Script");
        // layout.show_level_script_imgui = true;
    }
    if layout.script.flags & .TYPECHECKED {
        if !LS.execute_script(*layout.script) {
            log("Error: Failed to execute script!");
        }
    }
    if show_imgui {
        // imgui.End();
        // layout.show_level_script_imgui = false;
    }
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
            texture = *particles_texture,
            palette = get_color_animation_index("clouds"),
            
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




do_mouse_ray_collision_test :: () {
    mouse := context.mouse;
    level := context.current_level;
    
    if mouse {
        if mouse.left == {
          case .PRESSED;
            mouse_ray_start_position = pixel_to_internal_units(
                pixel_position  = mouse.position,
                internal_unit   = tile_render_unit,
                internal_offset = level.camera,
                pixel_offset    = Renderer.viewport.position
            );
            mouse_ray_end_position = mouse_ray_start_position;
            
          case .DOWN;
            mouse_ray_end_position = pixel_to_internal_units(
                pixel_position  = mouse.position,
                internal_unit   = tile_render_unit,
                internal_offset = level.camera,
                pixel_offset    = Renderer.viewport.position
            );
            
          case .RELEASED;
            mouse_ray_start_position, mouse_ray_end_position = .{};
        }
        
        // TODO: probably just move into player update?
        // move player with mouse
        {
            if mouse.right & .PRESSED {
                player_target := pixel_to_internal_units(
                    pixel_position  = mouse.position, 
                    internal_unit   = tile_render_unit, 
                    internal_offset = level.camera, 
                );
                level.player.position = lerp(level.player.position, player_target, 0.1);
                level.player.velocity = .{};
            } else if mouse.right == .RELEASED {
                player_target := pixel_to_internal_units(
                    pixel_position  = mouse.position, 
                    internal_unit   = tile_render_unit, 
                    internal_offset = level.camera, 
                );
                level.player.velocity = (player_target - level.player.position) / 4;
            }
        }
    }
}