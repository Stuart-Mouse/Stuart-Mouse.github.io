
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
    
    
    
    FIXING MY TIMSTEP NOTES
    
    need to put animation updates in some variable-rate update proc
    these should actually take delta time
    
    need to fix how mouse input is updated for the game's mouse
    or we just make all mouse stuff part of the variable update
        this is probably the easier option, since nothing the mouse does is part of normal gameplay, so it's basically fine to do it at variable update
        
        
*/

update_game :: () {
    using Game;
    
    context.current_level = get_active_level();
    level := context.current_level;
    
    context.mouse =  *global_mouse;
    // context.mouse = ifx !imgui.GetIO().WantCaptureMouse then *global_mouse;
    mouse := context.mouse;
    
    // TODO: fix smoothing to accoutn for framerate or something
    //       or maybe just give the game its own mouse and call it a day
    if mouse {
        if mouse.left == {
          case .PRESSED;
            mouse_ray_start_position = pixel_to_internal_units(
                pixel_position  = mouse.position,
                internal_unit   = TILE_UNIT,
                internal_offset = level.camera,
                pixel_offset    = Renderer.viewport.position
            );
            mouse_ray_end_position = mouse_ray_start_position;
            
          case .DOWN;
            mouse_ray_end_position = pixel_to_internal_units(
                pixel_position  = mouse.position,
                internal_unit   = TILE_UNIT,
                internal_offset = level.camera,
                pixel_offset    = Renderer.viewport.position
            );
            
          case .RELEASED;
            mouse_ray_start_position, mouse_ray_end_position = .{};
        }
        
        // move player with mouse
        {
            if mouse.right & .PRESSED {
                player_target := pixel_to_internal_units(
                    pixel_position  = mouse.position, 
                    internal_unit   = TILE_UNIT, 
                    internal_offset = level.camera, 
                );
                level.player.position = lerp(level.player.position, player_target, 0.1);
                level.player.velocity = .{};
            } else if mouse.right == .RELEASED {
                player_target := pixel_to_internal_units(
                    pixel_position  = mouse.position, 
                    internal_unit   = TILE_UNIT, 
                    internal_offset = level.camera, 
                );
                level.player.velocity = (player_target - level.player.position) / 4;
            }
        }
    }
    
    
    did_update := false;
    current_time := current_time_monotonic();
    defer if did_update then last_update_time = current_time;
    
    ms_since_last_update := max(to_milliseconds(current_time - last_update_time), 0);
    ms_per_update = (1000.0 / UPDATES_PER_SECOND.(float)).(s64);
    
    update_iteration := 0;
    // for update_iteration: 1..UPDATES_PER_FRAME {
    should_update := ifx do_manual_timing then ms_since_last_update >= ms_per_update else true;
    
    while update_loop := should_update {
        if update_iteration >= 2 then break;
        
        defer {
            update_iteration += 1;
            if do_manual_timing {
                should_update = ms_since_last_update >= ms_per_update;
                ms_since_last_update -= ms_per_update;
            } else {
                should_update = update_iteration < (UPDATES_PER_FRAME).(int);
            }
        }
        
        did_update = true;
        should_update_time := true;
        
        Input.update_window_events();
        process_input_events();
        // update_gamepad();
        
        // for scene transition, we will just completely skip the update for the current scene
        // we will only update the logic for the transition itself 
        if event_flags & .SCENE_TRANSITION {
            handle_scene_transition();
            continue update_loop;
        }
        
        level.time_since_start = level.ticks_since_start.(float) * ms_per_update.(float) / 1000.0;
        defer if should_update_time  level.ticks_since_start += 1;
        
        
        should_update_tilemaps  := true;
        should_update_players   := true;
        should_update_entities  := true;
        should_update_particles := true;
        should_process_events   := true;
        
        // TODO: also pause the game world when player is undergoing a powerup change
        if level.player.state == {
          case .ENTERING_WARP;  #through;
          case .EXITING_WARP;   #through;
          case .POWERUP_CHANGE;
            // TODO: would need to prevent updating of other players in multiplayer
            should_update_tilemaps  = false;
            should_update_entities  = false;
            should_update_time      = false;
        }
        
        // if should_update_tilemaps {
        for *level.tilemaps  update_tilemap_prescript(it);
        execute_level_script(level);
        for *level.tilemaps  update_tilemap_postscript(it);
        // }
        
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

/*
    Rendering Notes
    
    We currently don't have any sort of depth buffer, so render order is very important.
    We also can only set one transform per batch for all of the vertices in that batch.
        (This means that each tilemap has to be in its own batch, for example.)
    
    Things we need to render:
        1. background
        2. tilemaps
        3. player
        4. entities
        5. particles
        
    The background and tilemaps are the most straightforward, but the player, entities, and particles will be more complicated.
    We would like to be able to render these elements at variable depths, sometimes in front of or behind tilemaps, or relative to other entities.
    Using a depth buffer would be the most straightforward solution, but we would potentially run into some problems with transparency. (I certainly intend to use transparency on many particles and certain enemies.)
    
    For particles, we could have a couple pre-defined spots to render groups of particles
    (behind tilemaps, in front of tilemaps but behind entities, or in front of everything)
    But then we have to maintain separate pools of particles for each of these main "layers"
    This also does not give us the option to render particles between tilemaps or between entities...
    
    we also have the same probelm with entities where we sometimes want to be in front of or behind the player
    

    If we used a depth buffer, we would want to keep the player always at 0, so that bg elements are negative and fg are positive (or vice versa)      
    Then surely we could develop some other convention on top of that, e.g. tilemaps always go on integer indices and entities/particles may go on halves/quarters
    
    
    I think what I will end up having to do is a mix of both the manual sorting and depth buffer
        Sort tilemaps
        Sort entities 
            when rendering entites, we draw back to front so that transparency is OK
            presumably we would use the depth buffer so that we can render entities behind tilemaps
            but maybe this won't work for transparent tiles...
            
    We could also potentially just store up all draw commands for tilemaps and entities, put them into one buffer, then sort by depth
    This is probably the most robust solution if I want to be able to arbitrarily order tilemaps/entities/particles all of which could have transparency
    
    implemented a basic depth buffer check, but we do get issues with transparency as expected
    We could use discard to fix the issue wrt completely transparent pixels, but that still leaves us with a problem if we have partially transparent elements
    So, looks like we will probably just have to sort elements manually after all...
    But then we still have the batching issue... AAAHHH
    We can maybe get aroudn the batching issue by rendering tilemaps to textures, but that could also be very slow and bad, since we won't be able to take advantage of the GPU culling quads that are off-screen
    
    
    
    Maybe better to answer the question of what would be the ideal way to have rendering be structured.
    The ideal is something akin to the disnay multi-plane camera setup, where each tilemap layer is pretty much analogous to a plane
    
    And then we also have a main plane for the player
    I think its a pretty safe assumption to make that we won't ever want the player to move between tilemaps layers, nor will we 
        at least for this game
        
    I would like to be able to attach the rendering of entities and particles to be explicitly directly in front of or behind particular tilemaps
    That way I could attach particle emitters and such to particular points on a tilemap, and know that the rendering will jsu twork out as it should
    
    
    Also, if I build out the Spade game idea, things would need to work a bit differently
        the player would move between differnet tilemaps or spaces
        if we have some general way to render things wrt tilemaps then this is not hard to implement
        
    for now the ideal is probably some mixed approach weher ewe have a generalized absolute world space layer
        by default all entities and particles are render wrt this
        and the player is by definition in the very center
        so particles and entities can be flagged as front/rear to control rendering order wrt the layer
    
    then attachment to a layer also defines render order
    
    the tricky part becomes how to make this all more efficient bc of how we handle batching
    it would be one thing if we could just render entities/particles that are attached to a layer in the same batch as that layer
    but we can't do this bc of the uniform transform
    we could maybe tag the vertex to denote that the transform should not be applied though
        then we can still send it in the batch, but just use some selector expression in the vertex shader to make transform optional
    
    when we start attaching entities to a tilemap, we need to rethink how collision with entities works
    for example, things like piranha plants need to be attached to tilemaps such that they also inherit the tilemap's transform
        e.g. they rotate along with the tilemap
        we can probably handle these kinds of cases on a per-entity-type basis for now
    
    
*/
render_game :: () {
    using Game;
    
    level := get_active_level();
    // context.mouse = ifx !imgui.GetIO().WantCaptureMouse then *global_mouse;
    context.mouse = *global_mouse;
    
    current_time := current_time_monotonic();
    defer last_render_time = current_time;
    
    us_since_last_render := max(to_microseconds(current_time - last_render_time), 0);
    render_delta_time = us_since_last_render.(float) / 1000000.0;
    
    update_color_palette_animations(render_delta_time);
    update_color_palettes_on_gpu();
    update_tile_animations();
    step_animator(*fire_bar_animator, fire_bar_animation, Game.render_delta_time);
    update_camera(0.25 * 60 * render_delta_time); // TODO: adjust for delta time
    
    // draw level background
    render_draw_quad(
        position = (level.bounds.position - level.camera) * TILE_UNIT, 
        size     = level.bounds.size * TILE_UNIT, 
        color    = level.sky_color,
        depth    = 1.0
    );
    
    for *level.particles.back  render_particle(it, TILE_UNIT, -level.camera);
    
    render_end_batch();
    render_flush();
    
    tilemaps_sorted := get_tilemaps_sorted(level.tilemaps);
    for tilemaps_sorted {
        render_begin_batch();
        // NOTE: We use floor() here to prevent fractional pixel offsets. 
        //       This helps prevent weird graphical bugs, primarily gaps between tiles of tilemap.
        // TODO: we should do something similar when rendering entities, methinks.
        render_offset := floor((it.offset - level.camera) * TILE_UNIT); 
        translate(*Renderer.transform, .{ xy = render_offset });
        rotate2D (*Renderer.transform, -it.rotation * PI / 180.0);
        // scale    (*Renderer.transform, .{ it.scale.x, it.scale.y, 0});
        // skew2D   (*Renderer.transform, it.skew * PI / 180);
        
        render_tilemap(it, TILE_UNIT);
        
        // shade first solid tile hit by mouse ray
        if mouse_left() & .PRESSED {
            start := get_position_in_tilemap(it, mouse_ray_start_position);
            end   := get_position_in_tilemap(it, mouse_ray_end_position);
            vec   := end - start;

            index, intersect, had_collision := cast_ray_to_first_solid_tile(it, start, end, vec);
            if had_collision {
                tile_rect := Rectf.{
                    position = TILE_UNIT * (to_Vec2f(index) - it.anchor_point),
                    size     = to_Vec2f(TILE_UNIT)
                };
                render_draw_quad(tile_rect.position, tile_rect.size, color = .{ 1, 0, 0, 0.25 });
            }
        }
        
        render_end_batch();
        render_flush();
    }
    
    render_begin_batch();
    
    for *level.entities {
        if should_render_before_player(it) {
            render_entity(it, TILE_UNIT, -level.camera);
        }
    }
    
    render_player(*level.player, TILE_UNIT, -level.camera);
    
    render_draw_line((mouse_ray_start_position-level.camera) * TILE_UNIT, (mouse_ray_end_position-level.camera) * TILE_UNIT, .{1,0,1,1}, 2);
    
    for *level.entities {
        if !should_render_before_player(it) {
            render_entity(it, TILE_UNIT, -level.camera);
        }
    }
    
    for *level.particles.front  render_particle(it, TILE_UNIT, -level.camera);
    
    render_player_hud(*level.player, TILE_UNIT, .{ 1, 1 } * TILE_UNIT);
    
    
    if event_flags & .SCENE_TRANSITION {
        using Game.scene_transition;
        lerp := clock.(float) / (Scene_Transition.TRANSITION_FADE_TIME * UPDATES_PER_SECOND);
        lerp = smooth_0_to_1(1-lerp);
        
        if fading_in {
            position := Vec2f.{ x = -WINDOW_WIDTH * (lerp) };
            render_draw_quad(
                position = position,
                size     = Vec2f.{ WINDOW_WIDTH.(float), WINDOW_HEIGHT.(float) },
                color    = .{ 0, 0, 0, 1 }
            );
        } else {
            position := Vec2f.{ x = WINDOW_WIDTH * (1-lerp) };
            render_draw_quad(
                position = position,
                size     = Vec2f.{ WINDOW_WIDTH.(float), WINDOW_HEIGHT.(float) },
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
    cam_size   := to_Vec2f(viewport.size) / TILE_UNIT;
    cam_center := camera + cam_size / 2;
    
    top_bound    := bounds.y            + cam_size.y / 2;
    bottom_bound := bounds.y + bounds.h - cam_size.y / 2;
    
    if top_bound >= bottom_bound {
        cam_center.y = (top_bound + bottom_bound) / 2;
    } else {
        move_y := player.camera.focus_point.y - cam_center.y;
        if abs(move_y) < (1.0/TILE_UNIT) then move_y = 0;
        if smoothing then move_y /= (FRAMES_PER_SECOND * smoothing);
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
        if abs(move_x) < (1.0/TILE_UNIT) then move_x = 0;
        if smoothing then move_x /= (FRAMES_PER_SECOND * smoothing);
        cam_center.x += move_x;
        if cam_center.x <  left_bound then cam_center.x = left_bound;
        if cam_center.x > right_bound then cam_center.x = right_bound;
    }
    
    camera = cam_center - cam_size / 2;
}

get_camera_visible_rect :: (pad := Vec2f.{}) -> Rectf {
    visible_rect: Rectf;
    visible_rect.size = .{ WINDOW_WIDTH.(float), WINDOW_HEIGHT.(float) } / TILE_UNIT + pad;
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
            clock = (TRANSITION_FADE_TIME * UPDATES_PER_SECOND).(int);
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
        clock     = (Scene_Transition.TRANSITION_FADE_TIME * UPDATES_PER_SECOND).(int)
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
            palette = get_palette_index("clouds"),
            
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