
Item :: struct  {
    using #as base : Entity;
    
    item_type:  Item_Type;
    flags:      Item_Flags;
    animator:   Item_Animator;
    walk_dir:   Direction;
}

Item_Type :: enum {
    COIN;
    SUPER_MUSHROOM;
    FIRE_FLOWER;
    // ONE_UP_MUSHROOM;
    
    _COUNT;
}

Item_Flags :: enum_flags {
    ON_GROUND;
    PROGRESSIVE; // e.g., will spawn a fire flower as mushroom if player has no item yet
    WINGED;
};

item_palettes: Enumerated_Array(Item_Type, int);

Item_Animator :: Simple_Animator(Item_Type);

// for now, only one animation per item type
item_animations: Enumerated_Array(Item_Type, Simple_Animation(0));

init_item_animations :: () {
    { using item_animations;
        COIN.flags |= .LOOP;
        array_add(*COIN.frames, .{
            offset   = .{ -0.25, -0.5 },
            clip     = .{ 112, 0, 8, 16 },
            duration = 5.0/60.0,
        }, .{
            offset   = .{ -0.25, -0.5 },
            clip     = .{ 120, 0, 8, 16 },
            duration = 5.0/60.0,
        }, .{
            offset   = .{ -0.25, -0.5 },
            clip     = .{ 128, 0, 8, 16 },
            duration = 5.0/60.0,
        }, .{
            offset   = .{ -0.25, -0.5 },
            clip     = .{ 136, 0, 8, 16 },
            duration = 5.0/60.0,
        });
        
        array_add(*SUPER_MUSHROOM.frames, .{
            offset   = .{ -0.5, -0.5 },
            clip     = .{ 32, 0, 16, 16 },
        });
        
        array_add(*FIRE_FLOWER.frames, .{
            offset   = .{ -0.5, -0.5 },
            clip     = .{  0, 80, 16, 16 },
        });
    }
    { using item_palettes;
        COIN           = get_palette_index("item coin");
        SUPER_MUSHROOM = get_palette_index("item mushroom");
        FIRE_FLOWER    = get_palette_index("item flower");
    }
}

init_item :: (item: *Item, item_type: Item_Type, walk_dir: Direction = .L) {
    item.* = .{};
    item.entity_type = .ITEM;
    item.item_type   = item_type;
    item.palette     = item_palettes[item_type];
    set_animation(*item.animator, item.item_type);
    
    if item_type == {
        case .COIN;  item.size = .{ 0.5, 1.0 };
        case;        item.size = .{ 1.0, 1.0 };
    }
}

spawn_item :: (item: *Item) {
    if item.item_type == {
      case .FIRE_FLOWER;
        // if .PROGRESSIVE & item.flags && get_active_level().player.powerup == .NONE {
        //     item.item_type = .SUPER_MUSHROOM;
        // }
    }
}

update_item :: (using item: *Item) {
    level := context.current_level;
    player := *level.player;
    
    if position.y > level.bounds.y + level.bounds.h + 2 {
        entity_flags |= .REMOVE_ME;
        return;
    }
    
    if item_type == .SUPER_MUSHROOM {
        if walk_dir == {
            case .L; position.x -= 0.03;
            case .R; position.x += 0.03;
            
            // if walk dir is not valid, pick direction to walk based on current velocity
            // this behaviour is used intentionally when items/enemies pop out of item blocks
            case; if (.ON_GROUND & flags)  walk_dir = ifx velocity.x > 0 then .R else .L;
        }
    }
    
    friction: float = ifx (.ON_GROUND & flags) then 0.9 else 1.0;
    velocity.x *= friction;
    
    applied_gravity := default_enemy_physics.gravity;
    velocity.y = min(default_enemy_physics.max_fall_speed, velocity.y + applied_gravity);
    
    position += velocity;
    
    flags &= ~.ON_GROUND;
    
    
    collision_data.bounce_factor       = .{ 1, 1 };
    collision_data.broad_phase_margin  = 4;
    // collision_data.can_stand_on_slopes = true;
    
    // collide tilemap
    for *tilemap, tilemap_index: level.tilemaps {
        collision_data.center_point       = item.position;
        collision_data.velocity           = item.velocity;
        collision_data.collision_points   = get_collision_points(item);
        
        if get_tilemap_collision_data(tilemap, *collision_data) {
            handle_collision_response(tilemap, *collision_data, item);
            
            // handle getting hit from below by a bumped tile
            for dir: Direction.[ .D, .DL, .DR ] {
                point := collision_data.collision_points[dir];
                if point.had_collision && tile_is_bumping(point.tile_ptr) {
                    if item_type == {
                      case .COIN;
                        award_coins(player, 1);
                        spawn_coin_particle(position);
                        entity_flags |= .REMOVE_ME;
                        return;
                        
                      case;
                        velocity.y -= 0.15 / UPDATES_PER_FRAME;
                        // entity_flags |= .THROWN;
                        break;
                    }
                    break;
                }
            }
        }
    }
    
    
    // collide player
    p_rect := get_collision_rect(player);
    e_rect := get_collision_rect(item);
    if aabb_frect(p_rect, e_rect) {
        if item_type == {
            case .COIN;
                award_coins(player, 1);
                spawn_coin_particle(position);
                entity_flags |= .REMOVE_ME;
                return;
                
            case .SUPER_MUSHROOM;
                // change_plumber_powerup_state(player, .SUPER);
                // plumber_add_points(player, 5, position);
                entity_flags |= .REMOVE_ME;
                return;
                
            case .FIRE_FLOWER;
                // change_plumber_powerup_state(player, .FIRE);
                // plumber_add_points(player, 5, position);
                entity_flags |= .REMOVE_ME;
                return;
        }
    }
    
    return;
}

render_item :: (using item: *Item, render_unit: float, offset: Vector2, alpha_mod: float = 1) {
    step_animator(*animator, item_animations.data, Game.render_delta_time);

    current_animation := *item_animations[animator.state];
    current_frame     := *current_animation.frames[animator.current];
    
    flip := current_frame.flip;
    clip := current_frame.clip;
    rect := Rect.{
        x = cast(s32) ((position.x + current_frame.offset.x + offset.x) * render_unit),
        y = cast(s32) ((position.y + current_frame.offset.y + offset.y) * render_unit),
        w = cast(s32) ((cast(float) clip.w) / 16.0 * render_unit),
        h = cast(s32) ((cast(float) clip.h) / 16.0 * render_unit),
    };
    
    render_draw_quad(
        texture  = *entities_texture,
        color    = .{ 1, 1, 1, alpha_mod },
        position = .{ (position.x + current_frame.offset.x + offset.x) * render_unit, (position.y + current_frame.offset.y + offset.y) * render_unit },
        size     = .{ ((cast(float) clip.w) / 16.0 * render_unit), ((cast(float) clip.h) / 16.0 * render_unit) },
        clip     = *rect_to_frect(current_frame.clip),
        flip     = flip,
        palette  = palette,
    );
}

get_item_icon_clip :: (type: Item_Type, crop_x: int, crop_y: int) -> Rect {
    if type >= item_animations.count  return .{};
    animation := item_animations[type];
    if animation.frames.count == 0  return .{};
    clip := animation.frames[0].clip;
    clip.w = cast(s32) min(clip.w, xx crop_x);
    clip.h = cast(s32) min(clip.h, xx crop_y);
    return clip;
}

spawn_coin_particle :: (spawn_position: Vector2) {   
    frames_each    := item_animations.COIN.frames[0].duration * FRAMES_PER_SECOND;
    loops          := 2.0;
    _lifetime      := 0.5 * UPDATES_PER_SECOND;
    _velocity      := Vec2f.{ 0, -20 / UPDATES_PER_SECOND };
    _acceleration  := (2.0 * -_velocity) / _lifetime;
    
    using context.current_level;
    slot := get_next_slot(*particles.front);
    slot.occupied = true;
    
    slot.palette = get_palette_index("item coin");
    slot.texture = *entities_texture;
    
    slot.particle_type = .DYNAMIC;
    slot.dynamic = .{
        position     = spawn_position,
        velocity     = _velocity,
        acceleration = _acceleration,
        scale        = .{ 1, 1 },
        lifetime     = _lifetime.(s32),
        alpha        = 1,
    };
    
    anim := *slot.animation;
    anim.flags = item_animations.COIN.flags;
    anim.frame_count = item_animations.COIN.frames.count;
    for item_animations.COIN.frames {
        anim.frames[it_index] = it;
    }
}

handle_item_collision :: (item: *Item, other: *Entity, collision_type: Entity_Collision_Type) -> bool {
    level := context.current_level;
    if collision_type == {
      case .SHELL;
        if item.item_type == {
          case .COIN;    
            award_coins(*level.player, 1);
            spawn_coin_particle(item.position);
            item.entity_flags |= .REMOVE_ME;
          case;
            item.velocity.y -= 0.25;
        }
    }
    return false;
}

