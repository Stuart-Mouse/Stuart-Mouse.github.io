
Fire_Bar :: struct {
    using #as base: Entity;
    
    ball_count:     int;
    ball_scale:     int;
    ball_spread:    float;
    rotation_speed: float;
    
    // rotation : float;
    
    BALL_BASE_SIZE :: 6.0 / 16.0;
    
    // script_source : [..] u8;
    // script        : Script;
}

fire_bar_animator  : Simple_Animator(void);
fire_bar_animation : Simple_Animation;

init_fire_bar_animation :: () {
    fire_bar_animation.flags = .LOOP;
    array_add(*fire_bar_animation.frames, .{
        offset   = .{ -0.25, -0.25 },
        clip     = .{ 48, 0, 8, 8 },
        duration = 5.0/60.0,
    }, .{
        offset   = .{ -0.25, -0.25 },
        clip     = .{ 56, 0, 8, 8 },
        duration = 5.0/60.0,
    }, .{
        offset   = .{ -0.25, -0.25 },
        clip     = .{ 48, 8, 8, 8 },
        duration = 5.0/60.0,
    }, .{
        offset   = .{ -0.25, -0.25 },
        clip     = .{ 56, 8, 8, 8 },
        duration = 5.0/60.0,
    });
}

init_fire_bar :: (fire_bar: *Fire_Bar) {
    fire_bar.entity_type     = .FIRE_BAR;
    fire_bar.ball_count      = 10;
    fire_bar.ball_scale      = 1;
    fire_bar.ball_spread     = 0.75;
    // fire_bar.first_ball_dist = 0;
    fire_bar.rotation_speed  = 0.025;
    fire_bar.palette = get_palette_index("fireball");
}

deinit_fire_bar :: (fire_bar: *Fire_Bar) {
    // free lead sheet data
    // array_free(fire_bar.script_source);
    // free_script(*fire_bar.script);
}

do_fire_bar_ui_handles :: (fire_bar: *Fire_Bar) {
    ball_position := get_fire_bar_last_ball_position(fire_bar);
    for fire_handle: UI_Handle.{
        id              = "position", 
        offset          = *ball_position,
        thickness       = 2,
        want_focus_held = .L | .R,
        flags           = .POSITION_ABSOLUTE,
        texture         = *ui_elements_texture,
        clip            = *ui_texture_clip_rotation,
    } {
        using fire_handle;
        if focus_held == {
          case .L;
            if global_mouse.velocity != .{} {
                fire_bar.rotation = angle_between_points(fire_bar.position, Editor.mouse_tile_position);
                // If user is holding CTRL, then length of fire bar will not change.
                if !(key_modifier_state & .CTRL) {
                    fire_bar.ball_count = xx (1.5 + distance(Editor.mouse_tile_position, fire_bar.position) / fire_bar.ball_spread);
                    fire_bar.ball_count = clamp(fire_bar.ball_count, 2, 25);
                }
            }
        }
    }
}

iterate_fire_bar_balls :: (using fire_bar: *Fire_Bar, code: Code) #expand {
    // rn we do ball positions iteratively, but when we use lead sheets we will have to do it discretely anyhow, so...
    ball_size := BALL_BASE_SIZE * ball_scale;
    half_size := ball_size / 2;
    
    unit_vector := unit_vector_given_angle(rotation);

    `ball_center          := position/* + unit_vector * first_ball_dist*/;
    ball_center_increment := unit_vector * ball_spread;
    
    for 0..ball_count-1 {
        // if script.compiled {
            
        // }
    
        `ball_rect := Rectf.{
            x = ball_center.x - half_size,
            y = ball_center.y - half_size,
            w = ball_size,
            h = ball_size,
        };
        
        #insert code;
        
        ball_center += ball_center_increment;
    }
}

get_fire_bar_ball_collision_rect :: (using fire_bar: *Fire_Bar, ball_index: int) -> Rectf {
    ball_size := BALL_BASE_SIZE * ball_scale;
    half_size := ball_size / 2;
    
    unit_vector := unit_vector_given_angle(rotation);
    ball_center := position + unit_vector * ball_spread * cast(float) ball_index;
    
    return .{
        x = ball_center.x - half_size,
        y = ball_center.y - half_size,
        w = ball_size,
        h = ball_size
    };
}

update_fire_bar :: (using fire_bar: *Fire_Bar) {
    // update is incredibly simple
    rotation += rotation_speed;
    
    player := *get_active_level().player;
    player_rect := get_collision_rect(player);
    
    iterate_fire_bar_balls(fire_bar, #code {
        if aabb_frect(player_rect, ball_rect) {
            // plumber_take_damage(player);
        }
    });
}

render_fire_bar :: (using fire_bar: *Fire_Bar, render_unit: float, offset: Vector2, alpha_mod: float = 1) {
    current_frame := fire_bar_animation.frames[fire_bar_animator.current];
    
    iterate_fire_bar_balls(fire_bar, #code {
        render_position := Vector2.{
            x = ((ball_center.x + (current_frame.offset.x * cast(float)ball_scale) + offset.x) * render_unit),
            y = ((ball_center.y + (current_frame.offset.y * cast(float)ball_scale) + offset.y) * render_unit),
        };
        
        render_size := Vector2.{
            x = ((cast(float) current_frame.clip.w * ball_scale) / 16.0 * render_unit),
            y = ((cast(float) current_frame.clip.h * ball_scale) / 16.0 * render_unit),
        };
        
        render_draw_quad(
            texture  = *entities_texture,
            color    = .{ 1, 1, 1, alpha_mod },
            position = render_position,
            size     = render_size,
            clip     = *rect_to_frect(current_frame.clip),
            flip     = current_frame.flip,
            palette  = fire_bar.palette,
        );
    });
}

get_collision_rect :: (using fire_bar: *Fire_Bar) -> Rectf {
    return .{ position.x - 0.5, position.y - 0.5, 1, 1, };
}

get_fire_bar_last_ball_position :: (using fire_bar: *Fire_Bar) -> Vector2 {
    ball_size   := BALL_BASE_SIZE * ball_scale;
    half_size   := ball_size / 2;
    
    ball_index  := ball_count-1;
    unit_vector := unit_vector_given_angle(rotation);
    return position + unit_vector * ball_spread * ball_index.(float);
}

get_fire_bar_last_ball_rect :: (using fire_bar: *Fire_Bar) -> Rectf {
    ball_size   := BALL_BASE_SIZE * ball_scale;
    half_size   := ball_size / 2;
    
    ball_index  := ball_count-1;
    unit_vector := unit_vector_given_angle(rotation);
    ball_center := position + unit_vector * ball_spread * ball_index.(float);
    
    return .{
        x = ball_center.x - half_size,
        y = ball_center.y - half_size,
        w = ball_size,
        h = ball_size
    };
}
