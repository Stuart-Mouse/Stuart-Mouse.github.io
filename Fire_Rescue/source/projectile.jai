
Projectile :: struct {
    using #as base   : Entity;

    acceleration : Vector2;
    friction     : Vector2;
    vel_min      : Vector2;
    vel_max      : Vector2;
    bounce_force : Vector2;

    type         : Projectile_Type;
    flags        : Projectile_Flags;
    animator     : Projectile_Animator;
}

Projectile_Flags :: enum_flags {
    COLLIDE_TILEMAP;
    COLLIDE_PLAYER;
    COLLIDE_ENTITIES;
    
    BOUNCE_ON_FLOOR;
    BOUNCE_ON_WALLS;
    
    DIE_ON_FLOOR;
    DIE_ON_WALLS;
    
    DIE_ON_COLLIDE;
}

Projectile_Animator :: Simple_Animator(Projectile_Animation_State);

projectile_animations: [Projectile_Type._COUNT] [Projectile_Animation_State._COUNT] Simple_Animation;

Projectile_Type :: enum {
    FIREBALL;
    HAMMER;
    BOWSER_FIRE;
    SPIKE_BALL;
    
    _COUNT;
};

Projectile_Animation_State :: enum {
    ALIVE;
    DEAD;
    
    _COUNT;
};

projectile_palettes: [Projectile_Type._COUNT] Color_Palette_Enum;

init_projectile_animations :: () {
    projectile_animations[Projectile_Type.FIREBALL][Projectile_Animation_State.ALIVE].flags |= .LOOP;
    array_add(*projectile_animations[Projectile_Type.FIREBALL][Projectile_Animation_State.ALIVE].frames, .{
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
    
    array_add(*projectile_animations[Projectile_Type.FIREBALL][Projectile_Animation_State.DEAD].frames, .{
        offset   = .{ -0.5, -0.5 },
        clip     = .{ 64, 0, 16, 16 },
        duration = 3.0/60.0,
    }, .{
        offset   = .{ -0.5, -0.5 },
        clip     = .{ 80, 0, 16, 16 },
        duration = 3.0/60.0,
    }, .{
        offset   = .{ -0.5, -0.5 },
        clip     = .{ 96, 0, 16, 16 },
        duration = 3.0/60.0,
    });
    
    
    projectile_animations[Projectile_Type.HAMMER][Projectile_Animation_State.ALIVE].flags |= .LOOP;
    array_add(*projectile_animations[Projectile_Type.HAMMER][Projectile_Animation_State.ALIVE].frames, .{
        offset   = .{ -0.25, -0.5 },
        clip     = .{ 32, 16, 8, 16 },
        duration = 5.0/60.0,
    }, .{
        offset   = .{ -0.5, -0.25 },
        clip     = .{ 40, 24, 16, 8 },
        duration = 5.0/60.0,
    }, .{
        offset   = .{ -0.25, -0.5 },
        clip     = .{ 56, 16, 8, 16 },
        duration = 5.0/60.0,
    }, .{
        offset   = .{ -0.5, -0.25 },
        clip     = .{ 40, 16, 16, 8 },
        duration = 5.0/60.0,
    });
    projectile_animations[Projectile_Type.HAMMER][Projectile_Animation_State.DEAD] = projectile_animations[Projectile_Type.HAMMER][Projectile_Animation_State.ALIVE];
    
    
    projectile_animations[Projectile_Type.SPIKE_BALL][Projectile_Animation_State.ALIVE].flags |= .LOOP;
    array_add(*projectile_animations[Projectile_Type.SPIKE_BALL][Projectile_Animation_State.ALIVE].frames, .{
        offset   = .{ -0.5, -0.5 },
        clip     = .{ 64, 16, 16, 16 },
        duration = 5.0/60.0,
    }, .{
        offset   = .{ -0.5, -0.5 },
        clip     = .{ 64, 16, 16, 16 },
        duration = 5.0/60.0,
        flip     = .VERTICAL
    });
    projectile_animations[Projectile_Type.SPIKE_BALL][Projectile_Animation_State.DEAD] = projectile_animations[Projectile_Type.SPIKE_BALL][Projectile_Animation_State.ALIVE];
    
    projectile_palettes[Projectile_Type.FIREBALL   ] = .FIREBALL;
    projectile_palettes[Projectile_Type.HAMMER     ] = .GOOMBA;
    projectile_palettes[Projectile_Type.BOWSER_FIRE] = .FIREBALL;
    projectile_palettes[Projectile_Type.SPIKE_BALL ] = .GOOMBA;
}

init_projectile :: (projectile: *Projectile, type: Projectile_Type) {
    projectile.* = .{};
    projectile.entity_type = .PROJECTILE;
    projectile.type = type;
    projectile.palette = projectile_palettes[type];
    set_animation(*projectile.animator, Projectile_Animation_State.ALIVE);
}

update_projectile :: (using projectile: *Projectile) {
    // remove projectiles that go off screen
    screen_dimensions_world := Vector2.{ cast(float) WINDOW_WIDTH, cast(float) WINDOW_HEIGHT } / TILE_UNIT;
    if position.x < get_active_level().camera.x - 2 ||
       position.x > get_active_level().camera.x + screen_dimensions_world.x + 2 ||
       position.y < -2 || position.y > SCREEN_TILE_HEIGHT + 2 {
        entity_flags |= .REMOVE_ME;
        return;
    }
    
    // using the animator state here to control gameplay code is not ideal, just a quick fix
    if animator.state == .DEAD {
        if .STOPPED & animator.flags {
            entity_flags |= .REMOVE_ME;
        }
        return;
    }

    position_prev = position; // TODO: we should probably remove prev_position from base entity....
    
    velocity += acceleration;
    velocity.x = clamp(velocity.x, vel_min.x, vel_max.x);
    velocity.y = clamp(velocity.y, vel_min.y, vel_max.y);
    
    position += velocity;

    // collide tilemap
    if .COLLIDE_TILEMAP & flags {
        tilemap := *get_active_level().tilemap;
        size, offset := get_projectile_collision_size_and_offset(projectile.*);
        using collision_result := do_tilemap_collision(tilemap, position, size, offset);
        position += position_adjust;
        if .L & push_out {
            if .DIE_ON_WALLS & flags {
                set_animation(*animator, .DEAD);
            } else if velocity.x < 0 {
                if .BOUNCE_ON_WALLS & flags {
                    velocity.x = -velocity.x;
                } else {
                    velocity.x = 0;
                }
            }
        }
        if .R & push_out {
            if .DIE_ON_WALLS & flags {
                set_animation(*animator, .DEAD);
            } else if velocity.x > 0 {
                if .BOUNCE_ON_WALLS & flags {
                    velocity.x = -velocity.x;
                } else {
                    velocity.x = 0;
                }
            }
        }
        if .U & push_out {
            if .DIE_ON_WALLS & flags {
                set_animation(*animator, .DEAD);
            } else if velocity.y < 0 {
                if .BOUNCE_ON_WALLS & flags {
                    velocity.y =  bounce_force.y;
                } else {
                    velocity.y = 0;
                }
            }
        }
        if .D & push_out {
            if .DIE_ON_FLOOR & flags {
                set_animation(*animator, .DEAD);
            } else if velocity.y > 0 {
                if .BOUNCE_ON_FLOOR & flags {
                    velocity.y = -bounce_force.y;
                } else {
                    velocity.y = 0;
                }
            }
        }
    }
    
    // collision with other entities (do this in its own update loop? maybe later)
    if .COLLIDE_ENTITIES & flags {
        for other: *get_active_level().entities {
            if cast(*void) projectile == cast(*void) other then continue;
            projectile_rect := get_projectile_collision_rect(projectile);
            other_rect      := get_entity_collision_rect(other);
            if aabb_frect(projectile_rect, other_rect) {
                if fireball_hit_entity(other) {
                    if .DIE_ON_COLLIDE & flags {
                        set_animation(*animator, Projectile_Animation_State.DEAD);
                        return;
                    }
                }
            }
        }
    }
    
    if .COLLIDE_PLAYER & flags {
        plumber := *get_active_level().plumber;
        p_rect  := get_plumber_collision_rect(plumber.*);
        e_rect  := get_projectile_collision_rect(projectile.*);
        
        if aabb_frect(p_rect, e_rect) {
            plumber_take_damage(plumber);
            if .DIE_ON_COLLIDE & flags {
                set_animation(*animator, Projectile_Animation_State.DEAD);
                return ;
            }
        }
    }
}

render_projectile :: (using projectile: *Projectile, render_unit: float, offset: Vector2, alpha_mod: float = 1) {
    step_animator(*animator, projectile_animations[type]);

    current_animation := *projectile_animations[type][animator.state];
    current_frame     := *current_animation.frames[animator.current_frame];
    
    render_position := Vector2.{
        x = ((position.x + current_frame.offset.x + offset.x) * render_unit),
        y = ((position.y + current_frame.offset.y + offset.y) * render_unit),
    };
    
    render_size := Vector2.{
        x = ((cast(float) current_frame.clip.w) / 16.0 * render_unit),
        y = ((cast(float) current_frame.clip.h) / 16.0 * render_unit),
    };
    
    // TODO: probably replace frame.clip type with Rectf
    render_draw_quad(
        texture  = *entities_texture,
        color    = .{ 1, 1, 1, alpha_mod },
        position = render_position,
        size     = render_size,
        clip     = *rect_to_frect(current_frame.clip),
        flip     = current_frame.flip,
        palette  = palette,
    );
}

get_projectile_collision_size_and_offset :: (using projectile: Projectile) -> (size: Vector2, offset: Vector2) {
    if type == {
        case .FIREBALL;
            return .{ 0.5, 0.5 }, .{ -0.25, -0.25 };
        case .HAMMER;
            return .{ 0.5, 0.5 }, .{ -0.25, -0.25 };
        case .SPIKE_BALL;
            return .{ 1.0, 1.0 }, .{ -0.5 , -0.5  };
        case .BOWSER_FIRE;
    }
    return .{}, .{};
}

get_projectile_collision_rect :: (using projectile: Projectile) -> Rectf {
    size, offset := get_projectile_collision_size_and_offset(projectile);
    return .{
        x = position.x + offset.x,
        y = position.y + offset.y,
        w = size.x,
        h = size.y,
    };
}

