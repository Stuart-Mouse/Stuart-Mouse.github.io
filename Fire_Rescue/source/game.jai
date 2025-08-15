
Game: struct {
    // These constants actually get loaded from LSD data file on init so that we can more rapidly play with the values and prototype things out.
    // Should only contain simple values, not anything which would allocate memory.
    using constants: struct {
        desired_aspect_ratio:       float; // width / height
        
        tile_unit_basis:            float;
        tile_unit_basis_axis:       Axis;
        
        stretcher_render_width:     float; // width in render units
        stretcher_collision_size:   Vec2f;
        stretcher_collision_offset: Vec2f;
        
        ambulance_render_width:     float; // width in render units
        ambulance_collision_size:   Vec2f;
        ambulance_collision_offset: Vec2f;
        
        // positions are in terms of tile units
        // by our current defaults, the gameplay viewport is 16 units wide by 9 units tall
        stretcher_init_position:    Vec2f;
        ambulance_init_position:    Vec2f;
        
        window_positions:           [3] float;
        floor_height:               float;
        
        game_over_display_time:     float; // seconds
        game_ready_display_time:    float; // seconds
        
        stretcher_speed:            float;
        player_animation_rate:      float;
        
        // debug
        debug_rendering_flags:      enum_flags { COLLISION; }; 
    }
    
    using assets: struct {
        // Not doing a simple animator for player atm, because the player would need to be able to animate in reverse and we can't do that yet
        stretcher_clips: [] Rect;
        // player_animations: Enumerated_Array(Player_State, Simple_Animation(8));
        
        textures:       Enumerated_Array(Texture_ID, Simp.Texture);
        texture_paths:  Enumerated_Array(Texture_ID, string);
        
        guy_templates:  [] Guy_Template;
        decorations:    [] Decoration;
    }
    
    controller: Enumerated_Array(Controller_Keys, Input_Key);
    
    tile_render_unit:   float;
    viewport:           Rectf;
    pending_reload:     bool;
    
    using state: struct {
        mode:           Mode; 
        player:         Player;
        guys:           Slot_Array(Guy, 8);
        
        score:          int;
        lives:          int;
        
        Mode :: enum { READY; IN_GAME; GAME_OVER; }
        
        next_jump_time:             float;
        time_of_last_mode_change:   float;
        
        
        // visual 
        // foreground_particles: Slot_Array(Particle, 256);
        // background_particles: Slot_Array(Particle, 256);
        // Particle_Emitter smoke_emitter;
        // Particle_Emitter fire_emitter;
        
        
        // frame timing info
        last_update_time:       Apollo_Time;
        
        last_render_time:       Apollo_Time;
        render_delta_time:      float;  // delta_time used for variable-step update
        
        // TODO: need to actually update this value per update/render
        ticks_since_start:      u64;    // game update ticks, not milliseconds
        time_since_start:       float;
    }
    
    
    // shorthand for debugging, scoped inside game to prevent using elsewhere
    draw_rect :: (rect: Rectf, color := COLORS.WHITE) {
        render_draw_rect(world_to_screen(rect), color = color);
    }
}

// TODO: in future will need to consider position of camera
world_to_screen :: (point: Vec2f) -> Vec2f {
    unit   := Game.tile_render_unit;
    offset := Game.viewport.position;
    return .{
        x = point.x * unit + offset.x,
        y = point.y * unit + offset.y,
    };
}

// TODO: in future will need to consider position of camera
world_to_screen :: (rect: Rectf) -> Rectf {
    unit   := Game.tile_render_unit;
    offset := Game.viewport.position;
    return .{
        x = rect.x * unit + offset.x,
        y = rect.y * unit + offset.y,
        w = rect.w * unit,
        h = rect.h * unit,
    };
}

init_game :: () {
    using Game;
    Game = .{};
    
    // TODO: can remove need for this by reimplementing struct literals for LSD
    // helper functions for LSD files
    make_vec2 :: (x: float, y: float) -> Vec2f { return .{x,y}; };
    
    ok := LSD.load_and_parse_file("data/game_data.lsd", #code {
        LSD.register_procedure(*parser, "vec2",     make_vec2);
        LSD.register_procedure(*parser, "load_sfx", load_sfx);
        
        LSD.add_data_binding_to_dom(*parser, constants,  "constants");
        LSD.add_data_binding_to_dom(*parser, assets,     "assets");
        LSD.add_data_binding_to_dom(*parser, controller, "controller");
    });
    if !ok  exit(1);
    
    // post-processing on physics valuesk
    for *guy_templates {
        using it;
        
        gravity             = gravity           / (updates_per_second * updates_per_second);
        max_speed           = max_speed         / updates_per_second;
        bounce_deflection   = bounce_deflection / updates_per_second;
        bounce_min          = compute_jump_force(bounce_min,  gravity);
    }
    
    for *textures  Simp.texture_load_from_file(it, texture_paths[it_index]);
    
    // window resize needs to be handled after loading tile_unit_basis
    handle_window_resize_for_game();
}

deinit_game :: () {
    using Game;
    
    array_free(stretcher_clips);
    
    for *decorations {
        free_decoration(it);
    }
    array_free(decorations);
    
    for *guy_templates {
        free_guy_template(it);
    }
    array_free(guy_templates);
    
    for texture_paths {
        free(it);
    }
    
    for *textures {
        Simp.texture_destroy(it);
    }
    
    Game = .{};
}

Controller_Keys :: enum {
    TILT_LEFT;
    TILT_RIGHT;
    BOUNCE_HIGH;
    
    // DEBUG KEYS
    RELOAD_ASSETS;
}

Player :: struct {
    position:         Vec2f;
    position_prev:    Vec2f;
    
    animator:   Simple_Animator(Player_State);
    // TODO: maybe should have some way of computing velocity that is more cumulative rather than instantaneous
}

// not sure how exactly to handle player animations yet, since we probabyl want to animate the firemen and the stretcher somewhat independently?
// really just depends on what we decide from and art perspective...
Player_State :: enum {
    WALK;
}

Guy :: struct {
    template_index: int;
    
    position:       Vec2f;
    velocity:       Vec2f;
    rotation:       float;
    
    animator:       Simple_Animator(Guy_State);
    state:          Guy_State;
}

Guy_State :: enum {
    FALLING;
    SAFE;
    DEAD;
}

Guy_Template :: struct {
    name:                   string;
    
    collision_offset:       Vec2f;
    collision_size:         Vec2f;
    render_width:           float;  // height is automatically scaled to preserve source aspect ratio
    
    gravity:                float;  // units per second per second
    max_speed:              Vec2f;  // units per second
    bounce_min:             float;  // minimum bounce height
    bounce_low:             float;  // scale factor for reflecting guy's current speed
    bounce_high:            float;  // scale factor for reflecting guy's current speed
    bounce_deflection:      float;  // units_per_second of speed (left or right) imparted to guy when tilting stretcher
    rotation_speed:         float;  // degrees per unit of speed
    
    animations:             Enumerated_Array(Guy_State, Simple_Animation);
    noises:                 Enumerated_Array(Guy_Noises, [] Noise);
}

free_guy_template :: (template: *Guy_Template) {
    free(template.name);
    for template.noises {
        array_free(it);
    }
    for template.animations {
        array_free(it.frames);
    }
}

Guy_Noises :: enum {
    YELL;
    BOUNCE;
    DEAD;
    SAFE;
}

Texture_ID :: enum {
    FIRE;
    GUY;
    STRETCHER;
    AMBULANCE;
    BG_SKY;
    BG_CITY;
    BG_CLOUDS;
    BUILDING_BACK;
    BUILDING_FRONT;
    
    DECORATION;
}

// general structure for visual elements, so that they may be animated based on time and game state
// TODO: in future may want to separate into Decoration template and instance 
//       - prevent deuplication of animation arrays
//       - randomize certain properties of decoration per instance (scale, clips, particular animation)
Decoration :: struct {
    name:               string;
    z_index:            int; // negative is rendered behind player and guys, positive is in front
    
    position:           Vec2f;
    render_scale_basis: float;
    render_scale_axis:  Axis;
    
    texture_id:         Texture_ID;
    animator:           Simple_Animator(Game.state.Mode);
    animations:         Enumerated_Array(Game.state.Mode, Simple_Animation);
    // particle_emitters:  [] Particle_Emitter;
}

free_decoration :: (decor: *Decoration) {
    free(decor.name);
    for *decor.animations {
        free_animation(it);
    }
}

handle_window_resize_for_game :: () {
    using Game;
    
    // game viewport always maintains a 16:9 aspect ratio and scales to the window viewport
    window_viewport := Rectf.{ w = xx window_width, h = xx window_height };
    aspect_rect     := Rectf.{ w = constants.desired_aspect_ratio, h = 1 };
    Game.viewport    = center_and_scale_rect_within_container(aspect_rect, window_viewport, .MAJOR);
    
    tile_render_unit = Game.viewport.w / tile_unit_basis;
}

update_game :: () {
    using Game;
    
    did_update := false;
    current_time := current_time_monotonic();
    defer if did_update then last_update_time = current_time;
    
    ms_since_last_update := max(to_milliseconds(current_time - last_update_time), 0);
    should_update := ifx do_manual_timing then ms_since_last_update >= ms_per_update else true;
    
    update_iteration := 0;
    UPDATE_ITERATION_HARD_LIMIT :: 4;
    while should_update {
        if update_iteration >= UPDATE_ITERATION_HARD_LIMIT then break;
        defer {
            update_iteration += 1;
            if do_manual_timing {
                ms_since_last_update -= ms_per_update;
                should_update = ms_since_last_update >= ms_per_update;
            } else {
                should_update = update_iteration < (updates_per_frame).(int);
            }
        }
        
        did_update = true;
        should_update_time := true;
        
        Input.update_window_events();
        process_input_events();
        update_mouse();
        // update_gamepad();
        
        pending_reload ||= controller.RELOAD_ASSETS.state == .PRESSED;
        
        time_since_start = ticks_since_start.(float) * ms_per_update.(float) / 1000.0;
        defer if should_update_time  ticks_since_start += 1;
        
        inline __update_game();
    }
}

__update_game :: () {
    using Game;
    
    context.mouse = *global_mouse;
    mouse := context.mouse;
    
    // maybe change game mode, based on current mode and timer
    time_since_last_mode_change := time_since_start - time_of_last_mode_change;
    
    if time_since_start >= next_jump_time {
        spawn_new_guy();
        next_jump_time = time_since_start + random_get_within_range(1, 4);
    }
    
    if mode == {
      case .READY; 
        if time_since_last_mode_change >= game_ready_display_time {
            // TODO: maybe instead of using a timer here, we want to just wait until player clicks in the game viewport
            mode = .IN_GAME;
            time_of_last_mode_change = time_since_start;
            return;
        }
        
      case .GAME_OVER;
        if time_since_last_mode_change >= game_over_display_time {
            // TODO: should instead set some flag that signifies we should reinit on next frame?
            start_game();
            return;
        }
        
      case .IN_GAME;
        player.position_prev = player.position;
        
        update_input_controller(controller.data);
        
        mouse_position_local := (to_Vec2f(mouse.position) - Game.viewport.position) / tile_render_unit;
        if mouse.left & .PRESSED {
            move_player_towards_target_position(*player, mouse_position_local);
        }
        
        // paddles must have positions limited by top and bottom of screen
        // player.position.y = clamp(player.position.y, PLAYER_HEIGHT / 2.0, 1.0 - PLAYER_HEIGHT / 2.0);
        player.position.x = clamp(player.position.x, stretcher_collision_size.x / 2.0, 16.0 - stretcher_collision_size.x / 2.0);
        
        player_move      := player.position - player.position_prev;
        player_rect      := get_player_collision_rect(player);
        high_bounce_held := controller.BOUNCE_HIGH.state & .PRESSED;
        
        
        ambulance_collision_rect: Rectf;
        ambulance_collision_rect.position = ambulance_init_position + ambulance_collision_offset;
        ambulance_collision_rect.size     = ambulance_collision_size;
        
        for *guy: guys {
            using template := *guy_templates[guy.template_index];
            
            if guy.state == {
              case .FALLING;
                guy.velocity.y += gravity;
                
                guy_rect := get_guy_collision_rect(guy);
                guy_move := guy.velocity;
                
                result, collision_time, direction := swept_aabb_frect(guy_rect, guy_move, player_rect, player_move);
                if result == 1 {
                    guy_move *= collision_time;
                    
                    if direction == {
                      case .L; 
                        if guy.velocity.x <= 0 {
                            guy.velocity.x *= -bounce_high;
                        }
                        
                      case .R; 
                        if guy.velocity.x >= 0 {
                            guy.velocity.x *= -bounce_high;
                        }
                        
                      case .D; 
                        if guy.velocity.y >= 0 {
                            guy.velocity.y *= ifx high_bounce_held 
                                then -bounce_high
                                else -bounce_low;
                            guy.velocity.y = min(guy.velocity.y, -bounce_min);
                        }
                        if controller.TILT_LEFT.state & .PRESSED {
                            guy.velocity.x -= bounce_deflection;
                        } else if controller.TILT_RIGHT.state & .PRESSED {
                            guy.velocity.x += bounce_deflection;
                        }
                        
                        play_random_noise(noises.BOUNCE);
                        play_random_noise(noises.YELL);
                        
                        // TODO: spawn some cloud particles when player bounces
                        for 0..9 {
                            // uint32_t ticks_now = SDL_GetTicks();
                            
                            // Particle* p = NULL;
                            // for (Particle& p0: fg_particles) {
                            //     if (!p0.active) { p = &p0; break; }
                            // }
                            
                            // memset(p, 0, sizeof(Particle));
                            
                            // p.active     = true;
                            // p.spawn_time = ticks_now;
                            // p.lifetime   = (int)(random_get_within_range(0.25, 0.5) * 1000.0f);
                            
                            // p.position.x = guy.position.x + random_get_within_range(-0.04, 0.04);
                            // p.position.y = guy.position.y + random_get_within_range(-0.02, 0.02) + GUY_SIZE / 2;
                            
                            // p.velocity.x = random_get_within_range(-0.1,  0.1);
                            // p.velocity.y = random_get_within_range(0.0f, 0.5f) * guy.velocity.y;
                            // // Vec2 {  0.0,  -0.00003   };
                            // // Vec2 {  0.0,  -0.000005  };
                            // // Vec2 { -0.0000001, -0.0000006 };
                            // // Vec2 {  0.0000001, -0.0000002 };
                            // // p.acceleration.x = random_get_within_range(e->init_acceleration[0].x, e->init_acceleration[1].x);
                            // // p.acceleration.y = random_get_within_range(e->init_acceleration[0].y, e->init_acceleration[1].y);
                            
                            // p.scale            = random_get_within_range(0.03f, 0.06f);
                            // // p.rotation         = random_get_within_range();
                            // // p.angular_velocity = random_get_within_range();
                            
                            // // p.color_mod = Color4 { 1, 1, 1, 1 };
                            // p.color_mod = Color4 {
                            //     .r = 1.0,
                            //     .g = 1.0,
                            //     .b = 1.0,
                            //     .a = random_get_within_range(0.5, 0.9),
                            // };
                            
                            // p.fadeout_time = 1.0;
                            // p.texture = textures.CLOUD;
                            // p.texture_clip = Rect { 0, 0, textures.CLOUD.width, textures.CLOUD.height };
                        }
                    }
                }
                
                guy.position += guy_move;
                guy.rotation += guy.velocity.x * rotation_speed;
                
                if guy.position.y > floor_height {
                    guy.velocity = .{};
                    guy.state = .DEAD;
                    lives -= 1;
                    play_random_noise(noises.DEAD);
                }
                if guy.position.x < 0 {
                    guy.position.x = 0;
                    guy.velocity.x = -guy.velocity.x;
                }
                if guy.position.x > 16 {
                    guy.position.x = 16;
                    guy.velocity.x = -guy.velocity.x;
                }
                guy.velocity.x = clamp(guy.velocity.x, -max_speed.x, max_speed.x);
                guy.velocity.y = clamp(guy.velocity.y, -max_speed.y, max_speed.y);
            
                if is_point_within_frect(guy.position, ambulance_collision_rect) {
                    guy.state = .SAFE;
                    score += 1;
                    play_random_noise(noises.SAFE);
                }
                
                
              case .DEAD;
                // TODO
                remove;
                
              case .SAFE;
                // TODO
                remove;
            } 
        }
        
        // for *fg_particles {
        //     if !update_particle(it) { it.active = false; }
        // }
        
        if lives <= 0 {
            mode = .GAME_OVER;
            time_of_last_mode_change = time_since_start;
        }
    } // end mode switch
    
    
}

render_game :: () {
    using Game;
    
    current_time := current_time_monotonic();
    defer last_render_time = current_time;
    
    us_since_last_render := max(to_microseconds(current_time - last_render_time), 0);
    render_delta_time = us_since_last_render.(float) / 1000000.0;
    
    render_set_viewport();
    render_clear();
    
    render_set_viewport(*to_Rect(Game.viewport));
    render_clear(*(Color4.{0,0,0,1}));
    
    render_begin_batch();
    
    // TODO: print mouse coordinates on right click
    
    // actual game rendering here
    
    global_time := seconds_since_init().(float);
    
    // sky bg and clouds are not defined as decorations due to the fact that clouds are manually animated 
    // and I don't see any benefit to them not just being hardcoded at this time.
    render_draw_quad(
        position = Game.viewport.position,
        size     = Game.viewport.size,
        texture  = *textures.BG_SKY,
    );
    
    cloud_cycle_lerp := fmod_cycling(global_time, 30) / 30;
    render_draw_quad(
        position = Game.viewport.position + .{ Game.viewport.w * cloud_cycle_lerp, 0 },
        size     = Game.viewport.size,
        texture  = *textures.BG_CLOUDS,
    );
    render_draw_quad(
        position = Game.viewport.position + .{ Game.viewport.w * (cloud_cycle_lerp - 1), 0 },
        size     = Game.viewport.size,
        texture  = *textures.BG_CLOUDS,
    );
    
    // TODO: city bg should also be defined as a decoration item
    {
        bg_rect := center_and_scale_rect_within_container(.{ 0, 0, xx textures.BG_CITY.width, xx textures.BG_CITY.height }, Game.viewport, .Y);
        bg_rect.x = Game.viewport.w - bg_rect.w;
        render_draw_quad(
            position = bg_rect.position,
            size     = bg_rect.size,
            texture  = *textures.BG_CITY,
        );
    }
    
    bg_decor, fg_decor := get_sorted_decorations();
    
    for bg_decor  render_decoration(it);
    
    render_ambulance();
    
    for *guys  render_guy(it);
    
    render_player();
    
    for fg_decor  render_decoration(it);
    
    render_grid(
        dst_rect    = Game.viewport,
        tile_size   = to_Vec2f(tile_render_unit), 
        tile_offset = Game.viewport.position,
        color       = .{1,1,1,0.25}
    );
    
    render_end_batch();
    render_flush();
}

// the dumb ifx check on fmod_cycling is just to prevent the log spam we get when the divisor is zero
render_grid :: (
    dst_rect:       Rectf,
    tile_size:      Vector2, 
    tile_offset:    Vector2  = .{ 0, 0 }, 
    color:          Color4   = .{ 1, 1, 1, 1 },
    thickness:      float    = 1
) {
    x_pos := ifx tile_size.x == 0 
        then FLOAT32_INFINITY 
        else dst_rect.x + fmod_cycling(dst_rect.x - tile_offset.x, tile_size.x);
    while x_pos < dst_rect.x + dst_rect.w {
        render_draw_line(.{ x_pos, dst_rect.y }, .{ x_pos, dst_rect.y + dst_rect.h }, color, thickness);
        x_pos += tile_size.x;
    }
    y_pos := dst_rect.y + ifx tile_size.y == 0 
        then FLOAT32_INFINITY 
        else fmod_cycling(dst_rect.y - tile_offset.y, tile_size.y);
    while y_pos < dst_rect.y + dst_rect.h {
        render_draw_line(.{ dst_rect.x, y_pos }, .{ dst_rect.x + dst_rect.w, y_pos }, color, thickness);
        y_pos += tile_size.y;
    }
}

render_decoration :: (decor: *Decoration) {
    using Game;
    
    maybe_set_animation(*decor.animator, Game.mode, decor.animations.data);
    step_animator(*decor.animator, decor.animations.data, render_delta_time);
    current_frame := get_current_frame(decor.animator, decor.animations.data);
    clip          := to_Rectf(current_frame.clip);
    texture       := *textures[decor.texture_id];
    
    render_scale  := decor.render_scale_basis / get_axis(clip.size, decor.render_scale_axis);
    render_offset := current_frame.offset * render_scale;
    
    render_rect := Rectf.{
        size     = .{ xx texture.width, xx texture.height } * render_scale,
        position = decor.position + render_offset,
    };
    render_rect = world_to_screen(render_rect);
    
    render_draw_quad(
        position = render_rect.position,
        size     = render_rect.size,
        texture  = texture,
    );
}

render_ambulance :: () {
    using Game;
    
    render_rect := make_rect_centered(
        scale_to_width(.{ xx textures.AMBULANCE.width, xx textures.AMBULANCE.height }, ambulance_render_width),
        ambulance_init_position,
    );
    render_rect = world_to_screen(render_rect);
    
    render_draw_quad(
        position = render_rect.position,
        size     = render_rect.size,
        texture  = *textures.AMBULANCE,
    );
    
    if debug_rendering_flags & .COLLISION {
        ambulance_collision_rect: Rectf;
        ambulance_collision_rect.position = ambulance_init_position + ambulance_collision_offset;
        ambulance_collision_rect.size     = ambulance_collision_size;
        
        draw_rect(ambulance_collision_rect, color = COLORS.BLUE);
    }
}


render_player :: () {
    using Game;
    
    paddle_rotation := 0.0;
    if Game.controller.TILT_LEFT.state & .PRESSED {
        paddle_rotation = -7 * PI / 180.0;
    } else if Game.controller.TILT_RIGHT.state & .PRESSED {
        paddle_rotation = 7 * PI / 180.0;
    }
    
    // animations    := player_animations.data;
    // current_frame := get_current_frame(player.animator, animations);
    
    clip_index := (player.position.x * player_animation_rate).(int) % stretcher_clips.count;
    clip       := to_Rectf(stretcher_clips[clip_index]);
    
    render_rect := make_rect_centered(
        scale_to_width(clip.size, stretcher_render_width), 
        player.position
    );
    render_rect = world_to_screen(render_rect);
    
    render_draw_quad(
        position = render_rect.position,
        size     = render_rect.size,
        texture  = *textures.STRETCHER,
        clip     = *clip,
        rotate   = paddle_rotation,
    );
    
    if debug_rendering_flags & .COLLISION {
        draw_rect(get_player_collision_rect(player), color = COLORS.GREEN);
    }
}

render_guy :: (guy: *Guy) {
    using Game;
    
    using template := *guy_templates[guy.template_index];
    
    step_animator(*guy.animator, animations.data, render_delta_time);
    current_frame := get_current_frame(guy.animator, animations.data);
    clip          := to_Rectf(current_frame.clip);
    
    // TODO: are we going to use animation frame offset in this game?
    
    render_rect := make_rect_centered(
        scale_to_width(clip.size, template.render_width),
        guy.position
    );
    render_rect = world_to_screen(render_rect);
    
    render_draw_quad(
        position = render_rect.position,
        size     = render_rect.size,
        texture  = *textures.GUY,
        clip     = *clip,
        rotate   = guy.rotation,
    );
    
    if debug_rendering_flags & .COLLISION {
        draw_rect(get_guy_collision_rect(guy), color = COLORS.GREEN);
    }
}

render_player_score :: () {
    // TODO: render with a real font
    
    text_render_position := Game.viewport.size * .{ 0.5, 0.075 };
    render_small_text("%", Game.score, position = text_render_position, align = 0.5);
}

play_random_noise :: (noises: [] Noise) {
    if !noises  return;
    play(noises[random_get() % xx noises.count]);
}

get_player_collision_rect :: (player: Player) -> Rectf {
    return .{
        position = player.position + Game.constants.stretcher_collision_offset,
        size     = Game.constants.stretcher_collision_size,
    };
}

get_guy_collision_rect :: (guy: Guy) -> Rectf {
    template := *Game.guy_templates[guy.template_index];
    return .{
        position = guy.position + template.collision_offset,
        size     = template.collision_size,
    };
}

move_player_towards_target_position :: (player: *Player, target_position: Vec2f) {
    // TODO: maybe limit how far target position can be from current position
    // that way, we don't move too far in one frame, have a sort of max speed
    // float y_difference = p.position.y;
    // float y_target = clamp(target_position.y, 0, 1);
    // p.position.y = lerp(p.position.y, y_target, speed_scale * get_delta_time());
    
    // TODO: could also add more charm to the player's movement if the stretcher guys kind of skid when turning around quickly.
    
    x_target := clamp(target_position.x, 0, 16);
    move := Game.constants.stretcher_speed / updates_per_second;
    player.position.x = lerp(player.position.x, x_target, move);
}

start_game :: () {
    using Game;
    state = .{};
    
    mode = .READY;
    
    current_time := current_time_monotonic();
    last_render_time, last_update_time = current_time;
    
    // TODO: put player position in terms of tile units
    player.position = constants.stretcher_init_position;
    score = 0;
    lives = 3;
}

spawn_new_guy :: () {
    using Game;
    
    new_guy := get_next_empty_slot(*guys);
    if new_guy {
        new_guy.occupied = true;
        new_guy.data = .{
            template_index = xx (random_get() % guy_templates.count.(u64)),
            position       = .{ 0, window_positions[random_get() % 3] },
            velocity       = .{ random_get_within_range(1, 3), random_get_within_range(-4, -1) } / updates_per_second,
        };
        
        play_random_noise(guy_templates[new_guy.template_index].noises.YELL);
    }
}

get_sorted_decorations :: () -> (bg: [] *Decoration, fg: [] *Decoration) {
    using Game;
    
    sorted := NewArray(decorations.count, *Decoration,, temp);
    for *sorted  it.* = *decorations[it_index];
    quick_sort(sorted, (a, b) => a.z_index - b.z_index);
    
    first_fg_index := sorted.count;
    for sorted {
        if it.z_index >= 0 {
            first_fg_index = it_index;
            break;
        }
    }
    
    bg := array_view(sorted, 0, first_fg_index);
    fg := array_view(sorted, first_fg_index);
    return bg, fg;
}