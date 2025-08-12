
Game: struct {
    // These constants actually get loaded from LSD data file on init so that we can more rapidly play with the values and prototype things out.
    using constants: struct {
        desired_aspect_ratio:       float; // width / height
        
        tile_unit_basis:            float;
        tile_unit_basis_axis:       Axis;
        
        stretcher_render_size:      float; // width in render units
        stretcher_collision_size:   Vec2f;
        stretcher_collision_offset: Vec2f;
        
        ambulance_render_size:      float; // width in render units
        ambulance_collision_size:   Vec2f;
        ambulance_collision_offset: Vec2f;
        
        // positions are in terms of tile units
        // by our current defaults, the gameplay viewport is 16 units wide by 9 units tall
        stretcher_init_position:    Vec2f;
        ambulance_init_position:    Vec2f;
        
        window_positions:           [3]float;
        floor_height:               float;
        
        game_over_display_time:     float; // seconds
        game_ready_display_time:    float; // seconds
        
        stretcher_speed:            float;
        
        guy_templates:              Enumerated_Array(Guy_Type, Guy_Template);
        
        
        // debug
        debug_rendering_flags: enum_flags { COLLISION; }; 
    }
    
    using assets: struct {
        // TODO: maybe break this out in to separate types. also consider how many frames we actually need for each animation state
        guy_animations: Enumerated_Array( Guy_Type, Enumerated_Array( Guy_State, Simple_Animation(8) ) );
        
        guy_noises: Enumerated_Array(Guy_Type, struct {
            yell:       [] Noise;
            bounce:     [] Noise;
            dead:       [] Noise;
            safe:       [] Noise;
        });
        
        // TODO: stretcher stuff, also textures
        
        using textures: struct {
            cloud_texture:      Simp.Texture;
            fire_texture:       Simp.Texture;
            guy_texture:        Simp.Texture;
            stretcher_texture:  Simp.Texture;
            ambulance_texture:  Simp.Texture;
            
            bg_sky:             Simp.Texture;
            bg_city:            Simp.Texture;
            bg_clouds:          Simp.Texture;
            bg_building_back:   Simp.Texture;
            bg_building_front:  Simp.Texture;
        }
    }
    
    controller: Enumerated_Array(Controller_Keys, Input_Key);
    
    viewport: Rectf;
    
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
        foreground_particles: Slot_Array(Particle, 256);
        background_particles: Slot_Array(Particle, 256);
        // Particle_Emitter smoke_emitter;
        // Particle_Emitter fire_emitter;
        
        // scene_transition: Scene_Transition;
        
        
        // frame timing info
        ms_per_update:          s64;
        last_update_time:       Apollo_Time;
        
        last_render_time:       Apollo_Time;
        render_delta_time:      float;  // delta_time used for variable-step update
        
        // TODO: need to actually update this value per update/render
        ticks_since_start:      u64;    // game update ticks, not milliseconds
        time_since_start:       float;
    }
    
    
    // shorthand for debugging, scoped inside game to prevent using elsewhere
    draw_rect :: (rect: Rectf, color := COLORS.WHITE) {
        r := rect * tile_render_unit;
        r.position += Game.viewport.position;
        render_draw_rect(r, color = color);
    }
}

// TODO: in future will need to consider position of camera
world_to_screen :: (point: Vec2f) -> Vec2f {
    vp := to_Rectf(render_get_viewport());
    return point * vp.size / Game.constants.tile_unit_basis;
}

world_to_screen :: (rect: Rectf) -> Rectf {
    vp := to_Rectf(render_get_viewport());
    scalar := vp.size / Game.constants.tile_unit_basis;
    return .{
        x = rect.x * scalar.x,
        y = rect.y * scalar.y,
        w = rect.w * scalar.x,
        h = rect.h * scalar.y
    };
}

init_game :: () {
    using Game;
    
    // TODO: load textures in LSD (or at least define the source paths there)
    Simp.texture_load_from_file(*Game.cloud_texture,      "data/cloud.png");
    Simp.texture_load_from_file(*Game.fire_texture,       "data/fire.png");
    Simp.texture_load_from_file(*Game.guy_texture,        "data/guy.png");
    Simp.texture_load_from_file(*Game.stretcher_texture,  "data/stretcher.png");
    Simp.texture_load_from_file(*Game.ambulance_texture,  "data/ambulance.png");
    
    Simp.texture_load_from_file(*Game.bg_sky,            "data/bg/bg_sky.png");
    Simp.texture_load_from_file(*Game.bg_city,           "data/bg/bg_city.png");
    Simp.texture_load_from_file(*Game.bg_clouds,         "data/bg/bg_clouds.png");
    Simp.texture_load_from_file(*Game.bg_building_back,  "data/bg/bg_building_back.png");
    Simp.texture_load_from_file(*Game.bg_building_front, "data/bg/bg_building_front.png");
    
    
    ok := LSD.load_and_parse_file("data/game_data.lsd", #code {
        LSD.add_data_binding_to_dom(*parser, constants,  "constants");
        LSD.add_data_binding_to_dom(*parser, assets,     "assets");
        LSD.add_data_binding_to_dom(*parser, controller, "controller");
    });
    if !ok  exit(1);
    
    // post-processing on physics values
    for *guy_templates {
        using it;
        
        gravity             = gravity   / (updates_per_second * updates_per_second);
        max_speed           = max_speed / updates_per_second;
        bounce_min          = compute_jump_force(bounce_min,  gravity);
    }
}

// TODO: use comptime foreach struct member to handle deinitialization of assets
deinit_game :: () {
    
    // TODO: unload audio
    
    Simp.texture_destroy(*Game.cloud_texture);
    Simp.texture_destroy(*Game.fire_texture);
    Simp.texture_destroy(*Game.guy_texture);
    Simp.texture_destroy(*Game.stretcher_texture);
    Simp.texture_destroy(*Game.ambulance_texture);
    
    Simp.texture_destroy(*Game.bg_sky);
    Simp.texture_destroy(*Game.bg_city);
    Simp.texture_destroy(*Game.bg_clouds);
    Simp.texture_destroy(*Game.bg_building_back);
    Simp.texture_destroy(*Game.bg_building_front);
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
    
    // animator:   Simple_Animator(Player_State);
    // TODO: maybe should have some way of computing velocity that is more cumulative rather than instantaneous
}

// not sure how exactly to handle player animations yet, since we probabyl want to animate the firemen and the stretcher somewhat independently?
// really just depends on what we decide from and art perspective...
// Player_State :: enum {
//     WALK;
// }

Guy :: struct {
    position:   Vec2f;
    velocity:   Vec2f;
    rotation:   float;
    
    animator:   Simple_Animator(Guy_State);
    type:       Guy_Type;
    state:      Guy_State;
}

Guy_Type :: enum {
    LIGHT;
    MEDIUM;
    HEAVY;
}

Guy_State :: enum {
    FALLING;
    SAFE;
    DEAD;
}

Guy_Template :: struct {
    // animations should probably just go in here as well ? 
    collision_offset:       Vec2f;
    collision_size:         Vec2f;
    render_size:            float;
    
    // physics
    gravity:                float;  // units per second per second
    max_speed:              Vec2f;  // units per second
    bounce_min:             float;  // = 0.4;
    bounce_low:             float;  // = 0.85;
    bounce_high:            float;  // = 1.15;
    bounce_deflection:      float;  // = 0.1;
    rotation_speed:         float;  // = 12.0; // degrees per unit of speed
}

// Scene_Type :: enum {
//     TITLE_SCREEN;
//     GAME;
// }

// Scene_Transition :: struct {
//     src_scene:  Scene_Type;
//     dst_scene:  Scene_Type;
//     // out_style:  Scene_Transition_Style;
//     // in\_style:  Scene_Transition_Style;
//     clock:      int;
//     fading_in:  bool;
    
//     TRANSITION_FADE_TIME :: 0.75;
// };

update_game :: () {
    using Game;
    
    did_update := false;
    current_time := current_time_monotonic();
    defer if did_update then last_update_time = current_time;
    
    ms_since_last_update := max(to_milliseconds(current_time - last_update_time), 0);
    ms_per_update = (1000.0 / updates_per_second.(float)).(s64);
    
    update_iteration := 0;
    should_update := ifx do_manual_timing then ms_since_last_update >= ms_per_update else true;
    
    while update_loop := should_update {
        if update_iteration >= 2 then break;
        
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
        // update_gamepad();
        
        // for scene transition, we will just completely skip the update for the current scene
        // we will only update the logic for the transition itself 
        // if event_flags & .SCENE_TRANSITION {
        //     handle_scene_transition();
        //     continue update_loop;
        // }
        
        time_since_start = ticks_since_start.(float) * ms_per_update.(float) / 1000.0;
        defer if should_update_time  ticks_since_start += 1;
        
        inline __update_game();
    }
}

__update_game :: () {
    using Game;
    
    if controller.RELOAD_ASSETS.state == .PRESSED {
        init_game();
        return;
    }
    
    context.mouse = *global_mouse;
    mouse := context.mouse;
    
    // maybe change game mode, based on current mode and timer
    time_since_last_mode_change := time_since_start - time_of_last_mode_change;
    
    if time_since_start >= next_jump_time {
        spawn_new_guy();
        next_jump_time = time_since_start + random_get_within_range(1, 4);
        
        // Mix_Chunk* sound_to_play = bounce_sounds[random_get() % bounce_sounds.size()];
        // Mix_PlayChannel(-1, sound_to_play, 0);
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
            
            
        ambulance_collision_rect: Rectf;
        ambulance_collision_rect.position = ambulance_init_position + ambulance_collision_offset;
        ambulance_collision_rect.size     = ambulance_collision_size;
        
        high_bounce_held := controller.BOUNCE_HIGH.state & .PRESSED;
        
        for *guy: guys {
            using template := *guy_templates[guy.type];
            
            if guy.state == {
              case .FALLING;
                guy.velocity.y += gravity;
                
                guy_rect := get_guy_collision_rect(guy);
                guy_move := guy.velocity;
                
                player_rect := get_player_collision_rect(player);
                player_move := player.position - player.position_prev;
                
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
                        
                        // Mix_PlayChannel(-1, poof_sound, 0);
                        
                        // Mix_Chunk* sound_to_play = bounce_sounds[random_get() % bounce_sounds.size()];
                        // Mix_PlayChannel(-1, sound_to_play, 0);
                        
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
                            // p.texture = cloud_texture;
                            // p.texture_clip = Rect { 0, 0, cloud_texture.width, cloud_texture.height };
                        }
                    }
                    
                    // play bloop sound when bouncing off player
                    // Mix_Chunk *sound_to_play = player_i ? sound_bloop_1 : sound_bloop_2;
                        // Mix_PlayChannel(-1, sound_to_play, 0);
                }
                
                guy.position += guy_move;
                guy.rotation += guy.velocity.x * rotation_speed;
                
                if guy.position.y > floor_height {
                    log("guy is dead");
                    guy.velocity = .{};
                    guy.state = .DEAD;
                    lives -= 1;
                    
                    // Mix_Chunk* sound_to_play = dead_sounds[random_get() % dead_sounds.size()];
                    // Mix_PlayChannel(-1, sound_to_play, 0);
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
                    log("guy is safe");
                    guy.state = .SAFE;
                    score += 1;
                    
                    // TODO: spawn some cloud particles or something
                    // Mix_Chunk* sound_to_play = safe_sounds[random_get() % safe_sounds.size()];
                    // Mix_PlayChannel(-1, sound_to_play, 0);
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
    
    // set game viewport
    window_viewport := to_Rectf(render_get_viewport());
    aspect_rect     := Rectf.{ w = constants.desired_aspect_ratio, h = 1 };
    Game.viewport    = center_and_scale_rect_within_container(aspect_rect, window_viewport, .MAJOR);
    render_set_viewport(*to_Rect(Game.viewport));
    render_clear(*(Color4.{0,0,0,1}));
    
    render_begin_batch();
    
    // TODO: draw some grid overlay to help with aligning visual elements
            // also add some code to print mouse coordinates on click
    
    // TODO: only need to recompute tile render unit on window or game viewport resizes
    tile_render_unit = Game.viewport.w / tile_unit_basis;
    
    // actual game rendering here
    
    global_time := seconds_since_init().(float);
    
    // TODO: render backgrounds
    render_draw_quad(
        position = Game.viewport.position,
        size     = Game.viewport.size,
        texture  = *bg_sky,
    );
    
    cloud_cycle_lerp := fmod_cycling(global_time, 30) / 30;
    render_draw_quad(
        position = Game.viewport.position + .{ Game.viewport.w * cloud_cycle_lerp, 0 },
        size     = Game.viewport.size,
        texture  = *bg_clouds,
    );
    render_draw_quad(
        position = Game.viewport.position + .{ Game.viewport.w * (cloud_cycle_lerp - 1), 0 },
        size     = Game.viewport.size,
        texture  = *bg_clouds,
    );
    
    {
        bg_rect := center_and_scale_rect_within_container(.{}, Game.viewport);
        render_draw_quad(
            position = bg_rect.position,
            size     = bg_rect.size,
            texture  = *bg_clouds,
        );
    }
    
    // TODO: render ambulance
    
    // TODO: render player
    
    draw_rect(get_player_collision_rect(player), color = COLORS.GREEN);
    
    ambulance_collision_rect: Rectf;
    ambulance_collision_rect.position = ambulance_init_position + ambulance_collision_offset;
    ambulance_collision_rect.size     = ambulance_collision_size;
    
    draw_rect(ambulance_collision_rect, color = COLORS.BLUE);
    
    for *guys  render_guy(it);
    
    
    render_grid(
        dst_rect    = Game.viewport,
        tile_size   = to_Vec2f(tile_render_unit), 
        tile_offset = Game.viewport.position,
        color       = .{1,1,1,0.25}
    );
    
    render_end_batch();
    render_flush();
}

render_grid :: (
    dst_rect:       Rectf,
    tile_size:      Vector2, 
    tile_offset:    Vector2  = .{ 0, 0 }, 
    color:          Color4   = .{ 1, 1, 1, 1 },
    thickness:      float    = 1
) {
    x_pos := dst_rect.x + fmod_cycling(dst_rect.x - tile_offset.x, tile_size.x);
    while x_pos < dst_rect.x + dst_rect.w {
        render_draw_line(.{ x_pos, dst_rect.y }, .{ x_pos, dst_rect.y + dst_rect.h }, color, thickness);
        x_pos += tile_size.x;
    }
    y_pos := dst_rect.y + fmod_cycling(dst_rect.y - tile_offset.y, tile_size.y);
    while y_pos < dst_rect.y + dst_rect.h {
        render_draw_line(.{ dst_rect.x, y_pos }, .{ dst_rect.x + dst_rect.w, y_pos }, color, thickness);
        y_pos += tile_size.y;
    }
}

render_player :: (player: *Player) {
    // TODO
}

render_guy :: (guy: *Guy) {
    using Game;
    
    template   := *guy_templates[guy.type];
    animations := guy_animations[guy.type].data;
    
    step_animator(*guy.animator, animations, render_delta_time);
    current_frame := get_current_frame(guy.animator, animations);
    
    // TODO: are we going to use animation frame offset in this game?
    
    render_position := guy.position - to_Vec2f(template.render_size / 2);
    render_size     := to_Vec2f(template.render_size); // TODO: scale .h by clip aspect ratio, probably
    
    render_position *= tile_render_unit;
    render_size     *= tile_render_unit;
    render_position += Game.viewport.position;
    
    render_draw_quad(
        position = render_position,
        size     = render_size,
        texture  = *guy_texture,
        clip     = *to_Rectf(current_frame.clip),
        rotate   = guy.rotation,
    );
    
    if debug_rendering_flags & .COLLISION {
        guy_collision_rect := get_guy_collision_rect(guy);
        draw_rect(guy_collision_rect, color = COLORS.GREEN);
    }
}

// handle_scene_transition :: () {
//     using Game.scene_transition;
    
//     if clock <= 0 {
//         if fading_in {
//             Game.event_flags &= ~.SCENE_TRANSITION;
//             return;
//         } else {
//             if dst_scene == {
//               case .LEVEL;
//                 if Game.event_flags & .WARP {
//                     Game.event_flags &= ~.WARP;
//                     begin_area_with_warp(Game.warp_event.locator);
//                 }
//             }
//             fading_in = true;
//             clock = (TRANSITION_FADE_TIME * updates_per_second).(int);
//         }
//     }
//     clock -= 1;
// }



get_player_collision_rect :: (player: Player) -> Rectf {
    return .{
        position = player.position + Game.constants.stretcher_collision_offset,
        size     = Game.constants.stretcher_collision_size,
    };
}

get_player_render_rect :: (player: Player) -> Rectf {
    return .{
        position = player.position - to_Vec2f(Game.constants.stretcher_render_size / 2),
        size     = to_Vec2f(Game.constants.stretcher_render_size), // TODO: scale .h by clip aspect ratio
    };
}

// TODO: use simple_animator here
get_player_render_clip :: (player: Player) -> Rectf {
    // index := (player.position.x * 100.0).(int) % 6;
    // return *stretcher_clips[index];
    return .{ 0, 0, 0, 0 };
}

get_guy_collision_rect :: (guy: Guy) -> Rectf {
    template := *Game.guy_templates[guy.type];
    return .{
        position = guy.position + template.collision_offset,
        size     = template.collision_size,
    };
}

// TODO: use simple_animator here
get_guy_render_clip :: (guy: Guy) -> Rectf {
    // float current_time = get_seconds_since_init();
    // float frame_time = 0.1;
    // float index_f = current_time/frame_time;
    // int index = (int)index_f % 7;
    // return guy_clips[index];
    return .{ 0, 0, 0, 0 };
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
            position = .{ 0, window_positions[random_get() % 3] },
            velocity = .{ random_get_within_range(1, 3), random_get_within_range(-4, -1) } / updates_per_second,
        };
        log("spawned new guy:");
        print_vars(new_guy.*);
    }
}


#import "Print_Vars";