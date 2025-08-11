#import "Random";

/*
    TODO: tile uuids
    
    when loading tileset, if tile info does not already have an assigned uuid, generate one automatically and save it back ?
    
    
    when loading a level
        iterate over all tilemaps and remap tile id to use uuid instead
        we will have to save a copy of the tileset uuid list in the level file
        
    
*/

tiles_texture: Texture;

block_noises: Entity_Sounds;

Tile_Collision :: struct {
    type:   Tile_Collision_Type;
    flags:  Tile_Collision_Flags;
    mask:   Direction_Set; // used for semisolids to know which directions will push player out
};

Tile_Collision_Type :: enum {
    BLOCK;
    COIN;
};

Tile_Collision_Flags :: enum_flags {
    SOLID;
    BREAKABLE;
    BUMPABLE;
    CRUMBLE;
    SEMISOLID;
    CONTAINER;
};

Tile_Flags :: enum_flags u16 {
    EMPTY;                  // will be set by process_block_hit_event when continer has exhausted its entities
    BROKEN;
    RELEASE_ALL_AT_ONCE;    // any entities inside block will all get thrown out simultaneously
    AUTO_TILE;
};

// right now, max value must be 15, since we are packing this into nibbles!
Tile_Modifier :: enum u8 {
    NONE                       :: 0;
    STICKY                     :: 1;
    SLIPPERY                   :: 2;
    BOUNCY                     :: 3;
    GRAVITY                    :: 4;
    CONVEYOR_CLOCKWISE         :: 5;
    CONVEYOR_COUNTER_CLOCKWISE :: 6;
    _COUNT                     :: 6; // keep this accurate!
};

get_tile_modifier :: (tile: Tile, $$dir: Direction) -> Tile_Modifier {
    if dir == {
      case .U; return ((tile.modifiers & 0x000f) >>  0).(Tile_Modifier);
      case .D; return ((tile.modifiers & 0x00f0) >>  4).(Tile_Modifier);
      case .L; return ((tile.modifiers & 0x0f00) >>  8).(Tile_Modifier);
      case .R; return ((tile.modifiers & 0xf000) >> 12).(Tile_Modifier);
    }
    return .NONE;
}

get_tile_modifiers :: (tile: Tile) -> [4] Tile_Modifier {
    return .[
        ((tile.modifiers & 0x000f) >>  0).(Tile_Modifier),  // U
        ((tile.modifiers & 0x00f0) >>  4).(Tile_Modifier),  // R
        ((tile.modifiers & 0x0f00) >>  8).(Tile_Modifier),  // D
        ((tile.modifiers & 0xf000) >> 12).(Tile_Modifier)   // L
    ];
}

set_tile_modifier :: (tile: *Tile, dir: Direction, mod: Tile_Modifier) {
    if dir == {
      case .U;
        tile.modifiers &= 0x000f;
        tile.modifiers |= mod.(u16) <<  0;
      case .R;
        tile.modifiers &= 0x00f0;
        tile.modifiers |= mod.(u16) <<  4;
      case .D;
        tile.modifiers &= 0x0f00;
        tile.modifiers |= mod.(u16) <<  8;
      case .L;
        tile.modifiers &= 0xf000;
        tile.modifiers |= mod.(u16) << 12;
    }
}

/*
    Re-implementing tile behaviours
        bumping
        breaking
        container
            will do this differentyl on this go-around
            want to have some sort of system where entities that are placed in the tile are flagged as such, use an index to lookup tile and check its state
            or maybe tile gets a uuid assigned when we place entities in it, and that uuid will be used in some event that we create on block hit
            
*/

TILE_BUMP_TIME     :: 15; // TODO: we should put this in terms of seconds
TILE_BUMP_DISTANCE :: 0.4;


// Tiles are assigned a serial number when an entity is placed "inside" the tile. 
// The entity the holds a copy of this serial number as a reference to the tile.
last_tile_serial: u32 = 0;
get_tile_serial :: () -> u32 { last_tile_serial += 1; return last_tile_serial; };

Tile_Serial :: u32;
Tile_ID     :: u32;

Tile :: struct {
    serial:         Tile_Serial; 
    id:             Tile_ID;
    
    flags:          Tile_Flags; // u16
    modifiers:      u16; // UDLR packed into 4 nibbles
    crumble_timer:  u16;
    bump_clock:     u16; // only need u8, but using u16 right now to pad Tile up to exactly 128 bits
};

Tile_Info :: struct {
    name:           string;
    serial:         u64;
    collision:      Tile_Collision;
    palette:        int;
    crumble_time:   float = 1.0;
    become_on_use:  u32;
    
    group_id:       int;
    
    animation:      Simple_Animation;
    animator:       Simple_Animator(void); // no animation state for tiles atm
    
    noises: struct {
        bumped: Noise;
        broken: Noise;
    }
};

tile_info_lookup: [..] Tile_Info;

get_tile_info :: (tile: Tile) -> *Tile_Info {
    if tile.id < 0 || tile.id >= tile_info_lookup.count {
        print("Error: tile id '%' was out of range '%'.", tile.id, tile_info_lookup.count);
        return null;
    }
    return *tile_info_lookup[tile.id];
}

update_tile_animations :: () {
    // start at one to skip the empty tile
    for i: 1..tile_info_lookup.count-1 {
        ti := *tile_info_lookup[i];
        step_animator(*ti.animator, ti.animation, Game.render_delta_time);
    }
}

reset_tile_animations :: () {
    for i: 1..tile_info_lookup.count-1 {
        ti := *tile_info_lookup[i];
        ti.animator.current = 0;
        ti.animator.clock   = 0;
    }
}

Tile_Render_Info :: struct {
    texture:        *Texture;
    clip:           Rectf;
    color_mod:      Color4;
    palette:        int;
};

get_tile_render_info :: (tile: Tile) -> Tile_Render_Info {
    using tri : Tile_Render_Info;
    color_mod = ifx tile.id == 0 then Color4.{} else .{ 1, 1, 1, 1 };

    ti := get_tile_info(tile);
    if ti == null {
        print("Error: unable to retreive tile info.\n");
        return tri;
    }

    tri.texture = *tiles_texture;
    tri.palette = ti.palette;
    
    if ti.animator.current < ti.animation.frames.count {
        clip = rect_to_frect(ti.animation.frames[ti.animator.current].clip);
    }
    
    if Editor.in_autotile_ruleset && (.AUTO_TILE & tile.flags) {
        tri.color_mod.a = 8.0/16.0;
    }
    
    return tri;
}

is_side_solid :: (tile: Tile, direction: Direction) -> bool {
    info := get_tile_info(tile);
    if info.collision.type != .BLOCK     return false;
    if !(info.collision.flags & .SOLID)  return false;
    
    return !(info.collision.flags & .SEMISOLID) || (info.collision.mask & xx (1 << direction));
}

// TODO: remove this stuff
SCREEN_TILE_WIDTH  :: 20;
SCREEN_TILE_HEIGHT :: 15;

LEVEL_TILE_WIDTH   :: SCREEN_TILE_WIDTH * 12;


Tilemap :: struct {
    data:           [] Tile;
    size:           Vec2i;
    capacity:       Vec2i;
    
    min_index:      Vec2i = .{ S32_MAX, S32_MAX }; // only used in level editor
    max_index:      Vec2i; // only used in level editor
    
    root_offset:    Vector2;
    anchor_point:   Vector2;
    
    texture:        Texture;
    
    offset:         Vector2;
    offset_next:    Vector2;
    
    base_rotation:  float;
    rotation:       float;
    rotation_next:  float;
    
    velocity:       Vector2;
    scale:          Vector2;
    skew:           Vector2;
    
    transform:          Matrix4;
    transform_inverse:  Matrix4;
    transform_next:     Matrix4;
    
    name: [32] u8;
    z_index: int;
    
    Flags :: enum_flags {
        HOVERED_IN_EDITOR;
        SELECTED_IN_EDITOR;
        HIDDEN_IN_EDITOR;
    };
    flags: Flags;
    
    EDITOR_FLAGS :: Flags.HOVERED_IN_EDITOR | .SELECTED_IN_EDITOR | .HIDDEN_IN_EDITOR;
    
    
    // TODO: layer wrapping, these values are tentative, only here for memory of old impl
    // wrap_enabled  : Directions;
    // wrap_position : Vector2;
    // wrap_margin   : Vector2;
    // frame         : u32;
    
    // movement_components: u32;
    // rotation_components: u32;
    
    // #if false {
    dbg_vel_prev: [12][3] Vector2; // velocity, offset_next, offset
    dbg_vel_prev_index: int;
    dbg_do_print_vel_prev: bool;
    dbg_do_print_vel_prev_focused: int;
    // }
    
    // may need to increase or decrease this in the future, will just have to wait and see
    // we really just need to be smarter about how we calculate trails, considering when paths are periodic
    // but this will require some means of analyzing LS scripts quite deeply
    editor_trail_points: [128] Vector2;
};

/*
    Tilemaps have 2 update routines since we need to do some updating before level script runs, and some after it runs.
    Entities will probably end up needing something similar, unfortunately...
    
    before script:
        update tilemap position and rotation
    
    after script:
        offset_next and rotation next used to calculate next transform, since those were updated in script
        calculate velocity of platforms and update tiles
*/

update_tilemap_prescript :: (t: *Tilemap) {
    t.offset   = t.offset_next;
    t.rotation = t.rotation_next;
    
    t.transform = t.transform_next;
    _, t.transform_inverse = inverse(t.transform);
}

update_tilemap_postscript :: (t: *Tilemap) {
    // set instantaneous velocity
    prospective_vel := t.offset_next - t.offset;
    
    // TODO: this was originally to prevent crazy high velocities when layers wrapped
    //       but really we could still calculate the proper velocity in those cases with fmod_cycling or something
    //       but I think this will still be relevant for cases where tilemap's path is truly discontinuous, e.g. teleporting back to start of path
    if abs(prospective_vel.x) <= 1.0 && abs(prospective_vel.y) <= 1.0 {
        t.velocity = prospective_vel;
    } else {
        // print("ignored prospective velocity: %\n", prospective_vel);
    }
    
    #if false {
        count := type_info(type_of(t.dbg_vel_prev)).array_count;
        t.dbg_vel_prev_index = (t.dbg_vel_prev_index + 1) % count;
        t.dbg_vel_prev[t.dbg_vel_prev_index] = .[ t.velocity, t.offset_next, t.offset ];
        
        if t.dbg_do_print_vel_prev && (t.dbg_vel_prev_index == (t.dbg_do_print_vel_prev_focused + count/2) % count) {
            print("previous velocities:\n");
            for 0..count {
                index := (t.dbg_vel_prev_index + it) % count;
                if index == t.dbg_do_print_vel_prev_focused {
                    print("--> ");
                } else {
                    print("    ");
                }
                print("%\n", t.dbg_vel_prev[index]);
            }
            print("\n");
            t.dbg_do_print_vel_prev = false;
        }
    }
    
    t.transform_next = Matrix4_Identity;
    translate(*t.transform_next, .{ t.offset_next.x, t.offset_next.y, 0 });
    rotate2D (*t.transform_next, -t.rotation_next * PI / 180.0);
    // scale    (*t.transform_next, .{ t.scale.x, t.scale.y, 0});
    // skew2D   (*t.transform_next, t.skew * PI / 180);
    translate(*t.transform_next, .{ -t.anchor_point.x, -t.anchor_point.y, 0 });
    
    for *tile, index: t.data {
        if tile.id == 0  continue;
        ti := get_tile_info(tile);
        
        if (ti.collision.flags & .CRUMBLE) {
            if tile.crumble_timer > 0 {
                tile.crumble_timer -= 1;
                if tile.crumble_timer == 0 then tile.id = 0;
                // TODO: crumble spread to neighbor tiles
            }
        }
        
        if (ti.collision.flags & .BUMPABLE) {
            if tile.bump_clock > 0 {
                tile.bump_clock -= 1;
                if tile.bump_clock == 0 {
                    if .BROKEN & tile.flags {
                        remove_tile(tile);
                    } else if .EMPTY & tile.flags {
                        tile.* = .{ id = ti.become_on_use };
                    }
                }
            }
        }
    }
}


// will resize a tilemap to the default level tilemap size
// temporary, eventually we will have fully resizing tilemaps like in oe
init_tilemap :: (using tilemap: *Tilemap) {
    min_index = .{ S32_MAX, S32_MAX };
    capacity  = .{ 8, 8 };
    array_resize(*data, capacity.x * capacity.y);
    
    scale     = .{ 1, 1 };
    
    tilemap_name := tprint("%", FormatInt.{value=random_get(),base=16});
    memcpy(*name[0], *tilemap_name[0], min(size_of(type_of(name)), tilemap_name.count));
}

// TODO: the get tile functions need to be a bit more sophisticated to account for difference in capacity vs size
get_tile :: (tilemap: *Tilemap, i: int) -> *Tile {
    if i < 0 || i >= tilemap.capacity.x * tilemap.capacity.y {
        return null;
    }
    return *tilemap.data[i];
}

get_tile :: (tilemap: *Tilemap, x: int, y: int) -> *Tile {
    if x < 0 || x >= tilemap.capacity.x ||
       y < 0 || y >= tilemap.capacity.y {
        return null;
    }
    return *tilemap.data[y * tilemap.capacity.x + x];
}

get_tile :: (tilemap: *Tilemap, i: Vec2i) -> *Tile {
    return get_tile(tilemap, i.x, i.y);
}

// TODO: make version that takes tile ptr, 1d index
get_neighbor :: (tilemap: *Tilemap, index: Vec2i, direction: Direction) -> *Tile {
    neighbor_index := index;
    if direction == {
        case .U; neighbor_index.y -= 1;
        case .D; neighbor_index.y += 1;
        case .L; neighbor_index.x -= 1;
        case .R; neighbor_index.x += 1;
    }
    return get_tile(tilemap, neighbor_index);
}

get_2d_index :: (tilemap: *Tilemap, index: int) -> Vec2i {
    // TODO: is there some faster divmod we can use here?
    return .{ index.(s32) % tilemap.capacity.x, index.(s32) / tilemap.capacity.x };
}

get_index :: (tilemap: *Tilemap, index_2d: Vec2i) -> int {
    return index_2d.y * tilemap.size.x + index_2d.x;
}

get_index :: (tilemap: *Tilemap, tile_ptr: *Tile) -> int {
    assert(tile_ptr >= tilemap.data.data && tile_ptr < tilemap.data.data + tilemap.data.count);
    return tile_ptr - tilemap.data.data;
}

// point returned is UL corner of tile
// you can provide an offset that will be applied in tilemap space to get different points on tile (e.g., { 1, 0.5 } would be center of right face)
get_tile_position :: (tilemap: *Tilemap, index: int, offset := Vec2f.{}) -> Vec2f {
    index_2d := get_2d_index(tilemap, index); 
    print("index_2d: %\n", index_2d);
    return transform_point(tilemap.transform, to_Vec2f(index_2d) + offset);
}

get_tile_position :: (tilemap: *Tilemap, index: Vec2i, offset := Vec2f.{}) -> Vec2f {
    return transform_point(tilemap.transform, to_Vec2f(index) + offset);
}

// set_all_tiles_on_tilemap :: (tilemap: *Tilemap, tile: Tile) {
//     for 0..(tilemap.size.x * tilemap.size.y)-1 {
//         tilemap.data[it] = tile;
//     }
// }

render_tile_modifier :: (mod: Tile_Modifier, dir: Direction, tile_rect: Rectf) {
    // NOTE: diagonals not defined, but still present so we can index properly
    modifiers_rects :: Rectf.[
        .{ 0, 0, 1, 0.125 }, // U
        .{},
        .{ 1-0.125, 0, 0.125, 1 }, // R
        .{},
        .{ 0, 1-0.125, 1, 0.125 }, // D
        .{},
        .{ 0, 0, 0.125, 1 }, // L
        .{},
    ];
    modifiers_colors: [Tile_Modifier._COUNT] Color4 : .[
        .{ 0, 0, 0, 0.8 }, // STICKY
        .{ 0, 0, 1, 0.8 }, // SLIPPERY
        .{ 0, 1, 0, 0.8 }, // BOUNCY
        .{ 1, 0, 1, 0.8 }, // GRAVITY
        .{ 1, 1, 1, 1 }, // CONVEYOR_CLOCKWISE
        .{ 1, 1, 1, 1 }, // CONVEYOR_COUNTER_CLOCKWISE
    ];
    
    if mod == .NONE then return;
    
    // scale the rect based on the dimensions of tile rect
    rect := modifiers_rects[dir];
    rect.position *= tile_rect.size;
    rect.size     *= tile_rect.size;
    render_draw_quad(
        color    = modifiers_colors[mod-1],
        position = tile_rect.position + rect.position,
        size     = rect.size,
    );
}

render_tilemap :: (
    tilemap:            *Tilemap, 
    tile_render_unit:   float,
    alpha:              float    = 1
) {
    if !tilemap.data || tilemap.size.x == 0 || tilemap.size.y == 0  return;
    anchor_offset := -tilemap.anchor_point * tile_render_unit;
    
    tile := *tilemap.data[0];
    rect := Rectf.{ anchor_offset.x, anchor_offset.y, tile_render_unit, tile_render_unit };  
    
    for 0..tilemap.capacity.y-1 {
        defer {
            rect.x = anchor_offset.x;
            rect.y += tile_render_unit;
        }
        
        for 0..tilemap.capacity.x-1 {
            defer {
                rect.x += tile_render_unit;
                tile += 1;
            }
            
            if tile.id == 0          continue;
            if .BROKEN & tile.flags  continue;
            
            dst := rect;
            
            // add render offset for bumped tile
            // move this into get_tile_render_info?
            if tile.bump_clock != 0 {
                lerp := tile.bump_clock.(float) / TILE_BUMP_TIME;
                lerp = 1.0 - pow(1.0 - 2 * lerp, 2);
                dst.y -= lerp * TILE_BUMP_DISTANCE * tile_render_unit;
            }
            
            info := get_tile_info(tile);
            tri  := get_tile_render_info(tile);
            
            tri.color_mod.a *= alpha;
            
            if (info.collision.flags & .CRUMBLE) && (tile.crumble_timer != 0) {
                tri.color_mod.a *= tile.crumble_timer.(float) / (info.crumble_time * FRAMES_PER_SECOND);
            }
            
            render_draw_quad(
                texture  = tri.texture,
                color    = tri.color_mod,
                position = dst.position,
                size     = dst.size,
                clip     = *tri.clip,
                palette  = tri.palette,
            );
            
            modifiers := get_tile_modifiers(tile);
            for modifiers  if it != .NONE  render_tile_modifier(it, it_index.(Direction), dst);
        }
    }
}

// TODO: we should probably have some generic version that takes a callback, or some macro
cast_ray_to_first_solid_tile :: (tilemap: *Tilemap, start: Vec2f, end: Vec2f, velocity_local: Vec2f) -> (Vec2i, Vec2f, bool) {
    vec       := end - start;
    point     := start;
    index     := to_Vec2i_floor(point);
    end_index := to_Vec2i_floor(end);
    hit_tile  := false;
    
    // failsafe? probably not needed, but we have a debug log to let us know if this occurs
    iterations := 0;
    max_iterations := 100;
    
    // not a direction index, unlike dir_out
    // otherwise we would assume dir_in is .U_I on first iteration, where we actually did not enter the tile
    dir_in: Direction_Set;
    while true {
        tile := get_tile(tilemap, index);
        if tile /*&& !(tile.flags & .BROKEN)*/ {
            tile_info := get_tile_info(tile);
            if tile_info && (tile_info.collision.flags & .SOLID) {
                if tile_info.collision.flags & .SEMISOLID {
                    if tile_info.collision.mask & dir_in {
                        fudge_factor := 1.0/8.0;
                        point_within_tile := end - to_Vec2f(index);
                        moving_into_side := false;
                        if dir_in == {
                          case .U; moving_into_side ||= velocity_local.y >=   point_within_tile.y || (velocity_local.y >= 0 &&   point_within_tile.y < fudge_factor);
                          case .D; moving_into_side ||= velocity_local.y <= 1-point_within_tile.y || (velocity_local.y <= 0 && 1-point_within_tile.y < fudge_factor);
                          case .L; moving_into_side ||= velocity_local.x >=   point_within_tile.x || (velocity_local.x >= 0 &&   point_within_tile.x < fudge_factor);
                          case .R; moving_into_side ||= velocity_local.x <= 1-point_within_tile.x || (velocity_local.x <= 0 && 1-point_within_tile.x < fudge_factor);
                        }
                        
                        hit_tile = moving_into_side;
                        break;
                    }
                } else {
                    hit_tile = true;
                    break;
                }
            }
        }
        
        if index == end_index  break;
        
        move_out, dir_out := push_point_out_of_tile(point - to_Vec2f(index), vec);
        point += move_out;
        
        if dir_out == {
            case .U; index.y -= 1;
            case .D; index.y += 1;
            case .L; index.x -= 1;
            case .R; index.x += 1;
        }
        
        dir_in = xx 1 << direction_opposite[dir_out];
        
        iterations += 1;
        if iterations > max_iterations {
            log("hit max iterations...\n");
            break;
        }
    }
    
    return index, point, hit_tile;
}


push_point_out_of_tile :: (point: Tilemap_Collision_Point, vec_out: Vec2f) -> (move_out: Vec2f, dir_out: Direction) {
    position_in_tile  := point.point_in_tilemap - to_Vec2f(point.tile_index);
    move_out, dir_out := push_point_out_of_tile(position_in_tile, vec_out);
    return move_out, dir_out;
}

// the point given does not technically have to be inside the tile [0-1)
// this allows us to push a point out that is technically a raycast from player center to collision point
push_point_out_of_tile :: (position_in_tile: Vec2f, vec_out: Vec2f) -> (move_out: Vec2f, dir_out: Direction) {
    x_is_positive := vec_out.x >= 0;
    y_is_positive := vec_out.y >= 0;
    
    x_dir         := ifx x_is_positive then Direction.R else .L;
    y_dir         := ifx y_is_positive then Direction.D else .U;
    corner_point  := Vector2.{ cast(float) x_is_positive, cast(float) y_is_positive };
    
    // determine dir_out based on position in tile and slope of vec_out
    slope         := corner_point - position_in_tile;
    out_y         := abs(vec_out.y / vec_out.x) > abs(slope.y / slope.x);
    dir_out       := ifx out_y then y_dir else x_dir;
    
    move_out: Vec2f;
    if dir_out == {
        case .U; move_out += .{    - position_in_tile.y  * vec_out.x / vec_out.y,    - position_in_tile.y };
        case .D; move_out += .{ (1 - position_in_tile.y) * vec_out.x / vec_out.y, (1 - position_in_tile.y)};
        case .L; move_out += .{    - position_in_tile.x,    - position_in_tile.x  * vec_out.y / vec_out.x };
        case .R; move_out += .{  1 - position_in_tile.x, (1 - position_in_tile.x) * vec_out.y / vec_out.x };
    }
    
    return move_out, dir_out;
};


Tilemap_Collision_Data :: struct {
    // used as source of raycast for each of the collision points
    // in future we may want to have a different point here for each tilemap collision point instead of projecting all points from same origin
    center_point:               Vec2f; 
    center_point_in_tilemap:    Vec2f; 
    
    // TODO: remove when we get to collision response stuff
    can_stand_on_slopes:    bool; 
    
    // TODO: remove when we get to collision response stuff
    // used to scale vector subtracted by adjust_velocity
    // so 1.0 means cancel all velocity, 2.0 means reflect all velocity
    // over 2 means bounce with more velocity than hit surface,
    // we can probably just use manip this value in order to implement bouncy surfaces
    bounce_factor:          Vec2f;
    
    // entity velocity is required for semisolid collision check ATM. maybe we can find a way around this in the future
    velocity:               Vec2f;
    velocity_in_tilemap:    Vec2f;
    
    broad_phase_margin:     float;
    
    collision_points:   [] Tilemap_Collision_Point;
    surface_angles:     [4] float;
    
    // collision response stuff, will probably not be needed in future
    on_ground:          bool;
    ground_angle:       float;
    position_adjust:    Vector2;
    velocity_adjust:    Vector2;
    
    had_collision:      bool;
}

Tilemap_Collision_Point :: struct {
    had_collision:      bool;
    
    point_relative_to_origin:   Vec2f;
    point_in_tilemap:           Vec2f;
    
    tile_intersect:     Vec2f; // point where collision ray intersects solid tile
    tile_index:         Vec2i; // 2d index is probably easier to convert back to 1d rather than the other way around
    tile_ptr:           *Tile; // can also get 1d index from tile_ptr
    tile_info:          *Tile_Info;
    
    // collision response stuff, will probably not be needed in future
    // may be useful for debugging though
    position_adjust:    Vec2f;
    velocity_adjust:    Vec2f;
    direction_out:      Direction;
}

reset_for_new_tilemap :: (using collision_data: *Tilemap_Collision_Data) {
    for *collision_points {
        defer_restore(*it.point_relative_to_origin);
        it.* = .{};
    }
    
    on_ground       = false;
    ground_angle    = 0;
    had_collision   = false;
    position_adjust = .{};
    velocity_adjust = .{};
}

SMALL_SLOPE_ANGLE :: 15;

broad_phase_collision_check :: (tilemap: *Tilemap, point_local: Vec2f, margin: float) -> bool {
    // for now, we are just checking that the entity's center point is outside the tilemap bounds by at least 2x the entity's major dimension
    // this is probably a bit hacky, but just trying things out rn
    // TODO: could we use a flag on tiles to denote that none of its neighbors contain collideable tiles?
    //       then we could get a more granular broad-phase before doing raycast
    //       OR, we could just index all the tiles directly around player and check if they are collideable before bothering to do the raycast. realistically, this is only like 9 tiles
    if point_local.x < tilemap.min_index.x.(float) - margin
    || point_local.x > tilemap.max_index.x.(float) + margin + 1
    || point_local.y < tilemap.min_index.y.(float) - margin
    || point_local.y > tilemap.max_index.y.(float) + margin + 1 {
        return false;
    }
    return true;
}

get_tilemap_collision_data :: (tilemap: *Tilemap, using collision_data: *Tilemap_Collision_Data) -> bool {
    reset_for_new_tilemap(collision_data);
    
    center_point_in_tilemap = get_position_in_tilemap(tilemap, center_point);
    velocity_in_tilemap = transform_vector(tilemap.transform_inverse, velocity - tilemap.velocity);// + angular_velocity_local;
    
    if !broad_phase_collision_check(tilemap, center_point_in_tilemap, broad_phase_margin)  return false;
    
    for *collision_points {
        it.point_in_tilemap = get_position_in_tilemap(tilemap, center_point + it.point_relative_to_origin);
        it.tile_index, it.tile_intersect, it.had_collision = cast_ray_to_first_solid_tile(tilemap, center_point_in_tilemap, it.point_in_tilemap, velocity_in_tilemap);
        if it.had_collision {
            it.tile_ptr  = get_tile(tilemap, it.tile_index);
            it.tile_info = get_tile_info(it.tile_ptr);
            
            // ignore side points in collision with semisolid platforms. 
            // TODO: we should refactor all collision response handling, and how points are given to collision function
            if (it_index == xx Direction.L || it_index == xx Direction.R) 
            && (it.tile_info.collision.flags & .SEMISOLID) {
                continue;
            }
            
            // // also ignore broken tiles for all but feet points
            // if (it.tile_ptr.flags & .BROKEN) && !contains(Direction_Set.D | .DL | .DR, it_index.(Direction)) {
            //     continue;
            // }
            
            had_collision = true;
        }
    }
    
    return had_collision;
}

// TODO: remove entity parameter (actually just refactor this whole procedure for enemy/ player seaprately)
handle_collision_response :: (tilemap: *Tilemap, using collision_data: *Tilemap_Collision_Data, entity: *Entity) {
    // determining local velocity is not actually as simple as just transform_vector(), since this won't actually factor in the tilemap's velocity or rotation
    angular_velocity_local: Vec2f;
    {
        delta_angle  := tilemap.rotation_next - tilemap.rotation;
        foot_point   := get_position_in_tilemap(tilemap, center_point + collision_points[Direction.D].point_relative_to_origin);
        ref_point    := foot_point - tilemap.anchor_point;
        angular_velocity_local = rotate_degrees(ref_point, -delta_angle) - ref_point;
    }
    
    velocity_in_tilemap_before := velocity_in_tilemap;
    velocity_before := velocity;
    
    
    // TODO: maybe just compute these once per frame and store in tilemap
    // TODO: maybe also do the same for surface normals
    surface_angles = get_surface_angles(tilemap);
    surface_angles_local: [4] float = .[ 270, 0, 90, 180 ];
    
    apply_ground_velocity := false;
    
    // TODO: repalce with general touch_tile proc, providing entity that touched tile and from what side.
    //       that we we can handle anything tile needs to do in response ini one place
    maybe_crumble_tile :: (tile: *Tile) {
        info := get_tile_info(tile);
        if info.collision.flags & .CRUMBLE {
            if tile.crumble_timer == 0 {
                tile.crumble_timer = (info.crumble_time * FRAMES_PER_SECOND).(u16);
            }
        }
    }
    
    get_tile_bounce :: (tile: *Tile, dir: Direction) -> float {
        mod := get_tile_modifier(tile, dir);
        return ifx mod == .BOUNCY then 1.75 else 1.0;
    }
    
    // returns the adjustment that needs to be added to the given velocity, not the adjusted velocity 
    adjust_velocity :: (v: Vec2f, a: float, bounce := Vec2f.{ 1, 1 }, damping_thresh := 0.0) -> Vector2 {
        // d is the magnitude of v along u, which is our velocity in the direction of angle a
        // max(..., 0) prevents player getting stuck to walls when d would be negative
        u := unit_vector_given_angle(a * PI / 180);
        d := max((v.x * u.x) + (v.y * u.y), 0); 
        
        b := ifx abs(d) < damping_thresh then .{ 1, 1 } else bounce;
        return -d * u * b;
        // return v - (d * u) * b;
    }
    
    // we apply the largest single adjustment in each axis
    apply_velocity_adjustment :: (velocity: *Vec2f, adjustment: Vec2f) {
        if abs(adjustment.x) > abs(velocity.x)  velocity.x = adjustment.x;
        if abs(adjustment.y) > abs(velocity.y)  velocity.y = adjustment.y;
    }
    
    gravity_vec       := unit_vector_given_angle_degrees(entity.gravity_angle);
    gravity_vec_local := transform_vector(tilemap.transform_inverse, gravity_vec);
    gravity_angle     := entity.gravity_angle;// + tilemap.rotation;
    gravity_up_angle  := fmod_cycling(gravity_angle + 180, 360);
    
    if collision_points[Direction.R].had_collision {
        point := *collision_points[Direction.R];
        point.position_adjust, point.direction_out = push_point_out_of_tile(point, center_point_in_tilemap - point.point_in_tilemap);
        position_adjust += point.position_adjust;
        
        natural_out_angle := gravity_up_angle - 90;
        angle_diff := angle_difference_degrees(surface_angles[point.direction_out], natural_out_angle);
        
        // prevent pushing player out in extreme angle cases
        if abs(angle_diff) < 60 {
            point.velocity_adjust += adjust_velocity(velocity_in_tilemap, surface_angles_local[point.direction_out] + 180, bounce_factor * get_tile_bounce(point.tile_ptr, point.direction_out));
            apply_velocity_adjustment(*velocity_adjust, point.velocity_adjust);
        }
    }
    
    if collision_points[Direction.L].had_collision {
        point := *collision_points[Direction.L];
        point.position_adjust, point.direction_out = push_point_out_of_tile(point, center_point_in_tilemap - point.point_in_tilemap);
        position_adjust += point.position_adjust;
        
        natural_out_angle := gravity_up_angle + 90;
        angle_diff := angle_difference_degrees(surface_angles[point.direction_out], natural_out_angle);
        
        // prevent pushing player out in extreme angle cases
        if abs(angle_diff) < 60 {
            point.velocity_adjust += adjust_velocity(velocity_in_tilemap, surface_angles_local[point.direction_out] + 180, bounce_factor * get_tile_bounce(point.tile_ptr, point.direction_out));
            apply_velocity_adjustment(*velocity_adjust, point.velocity_adjust);
        }
    }
    
    if collision_points[Direction.U].had_collision {
        point := *collision_points[Direction.U];
        point.position_adjust, point.direction_out = push_point_out_of_tile(point, center_point_in_tilemap - point.point_in_tilemap);
        position_adjust += point.position_adjust;
        
        point.velocity_adjust += adjust_velocity(velocity_in_tilemap, surface_angles_local[point.direction_out] + 180, bounce_factor * get_tile_bounce(point.tile_ptr, point.direction_out));
        apply_velocity_adjustment(*velocity_adjust, point.velocity_adjust);
    } else {
        if collision_points[Direction.UL].had_collision {
            point := *collision_points[Direction.UL];
            point.direction_out = Direction.UL; // used as both input and output in this case
            if velocity_in_tilemap.x > 0.01 then point.direction_out = .L; // fudge player collision a bit to push player out to side if moving right
            
            point.position_adjust, point.direction_out = push_point_out_of_tile(point, center_point_in_tilemap - collision_points[point.direction_out].point_in_tilemap);
            position_adjust += point.position_adjust;
            point.velocity_adjust += adjust_velocity(velocity_in_tilemap, surface_angles_local[point.direction_out] + 180, bounce_factor * get_tile_bounce(point.tile_ptr, point.direction_out));
            apply_velocity_adjustment(*velocity_adjust, point.velocity_adjust);
        }
        if collision_points[Direction.UR].had_collision {
            point := *collision_points[Direction.UR];
            point.direction_out = Direction.UR; // used as both input and output in this case
            if velocity_in_tilemap.x < -0.01 then point.direction_out = .R; // fudge player collision a bit to push player out to side if moving left
            
            point.position_adjust, point.direction_out = push_point_out_of_tile(point, center_point_in_tilemap - collision_points[point.direction_out].point_in_tilemap);
            position_adjust += point.position_adjust;
            point.velocity_adjust += adjust_velocity(velocity_in_tilemap, surface_angles_local[point.direction_out] + 180, bounce_factor * get_tile_bounce(point.tile_ptr, point.direction_out));
            apply_velocity_adjustment(*velocity_adjust, point.velocity_adjust);
        }
    }
    
    if collision_points[Direction.D].had_collision {
        point := *collision_points[Direction.D];
        point.position_adjust, point.direction_out = push_point_out_of_tile(point, -gravity_vec_local);
        position_adjust += point.position_adjust;
        
        // we want to smoothly interpolate the angle at which we cancel the player's velocity, based on angle diff to gravity angle
        angle_diff := angle_difference_degrees(surface_angles[point.direction_out], gravity_up_angle);
        
        cancel_velocity_scalar := 1.0;
        cancel_velocity_angle := surface_angles_local[point.direction_out] + 180;
        if can_stand_on_slopes 
        && !(entity.entity_flags & .THROWN)
        && !(entity.entity_flags & .SLIDING) { 
            // slope_lerp := clamp(delerp(SMALL_SLOPE_ANGLE, 90, abs(angle_diff)), 0, 1).(float);
            slope_lerp := clamp(delerp(SMALL_SLOPE_ANGLE, 75, abs(angle_diff)), 0, 1).(float);
            cancel_velocity_angle  = (gravity_angle - tilemap.rotation) + angle_diff * slope_lerp;
            slope_lerp = clamp(delerp(0, 60, abs(angle_diff)), 0, 1).(float);
            cancel_velocity_scalar -= (0.5 * slope_lerp);
        }
        
        point.velocity_adjust += adjust_velocity(velocity_in_tilemap, cancel_velocity_angle, bounce_factor * get_tile_bounce(point.tile_ptr, point.direction_out), damping_thresh = 0.05);
        apply_velocity_adjustment(*velocity_adjust, point.velocity_adjust * cancel_velocity_scalar);
        
        maybe_crumble_tile(point.tile_ptr);
        collision_data.on_ground = true;
        apply_ground_velocity = true;
        collision_data.ground_angle = surface_angles[point.direction_out];
    }
    else {
        if collision_points[Direction.DR].had_collision 
        && collision_points[Direction.DL].had_collision {
            dr_point := *collision_points[Direction.DR];
            dl_point := *collision_points[Direction.DL];
            
            // handle case where player is standing with both corner bottom points on ground but center bottom point is not on ground
            move_out: Vector2;
            dr_dir_out, dl_dir_out: Direction;
            
            dr_point.position_adjust, dr_point.direction_out = push_point_out_of_tile(dr_point, center_point_in_tilemap - dr_point.point_in_tilemap);
            position_adjust += move_out * .{ 1, 0.5 }; // TODO: pretty sure this way of going 0.5 on the x axis is totally wrong when rotated
            
            dl_point.position_adjust, dl_point.direction_out = push_point_out_of_tile(dl_point, center_point_in_tilemap - dl_point.point_in_tilemap);
            position_adjust += move_out * .{ 1, 0.5 };
            
            surface_angle := (surface_angles[dr_dir_out] + surface_angles[dl_dir_out]) / 2.0;
            
            maybe_crumble_tile(dl_point.tile_ptr);
            maybe_crumble_tile(dr_point.tile_ptr);
            
            // TODO: player is unable to move out of a corner and move up a slope that they would normally be able to walk up, 
            // due to canceling the velocity in the direction of the surface angle rather than the gravity angle.
            // perhaps we need some flags saying whether an entity is trying to walk left/right so that we can optionally skip cancelling vel on corresponding slope
            
            // if player not holding left
            dl_point.velocity_adjust = adjust_velocity(velocity_in_tilemap, surface_angles_local[dl_dir_out] + 180, bounce_factor * get_tile_bounce(dl_point.tile_ptr, dl_dir_out), damping_thresh = 0.05);
            
            // if player not holding right
            dr_point.velocity_adjust = adjust_velocity(velocity_in_tilemap, surface_angles_local[dr_dir_out] + 180, bounce_factor * get_tile_bounce(dr_point.tile_ptr, dr_dir_out), damping_thresh = 0.05);
            
            velocity_adjust += (dl_point.velocity_adjust + dr_point.velocity_adjust) * 0.5;
            
            collision_data.on_ground = true;
            apply_ground_velocity = true;
            collision_data.ground_angle = surface_angle;
        }
        else if collision_points[Direction.DL].had_collision {
            point := *collision_points[Direction.DL];
            
            point.position_adjust, point.direction_out = push_point_out_of_tile(point, center_point_in_tilemap - point.point_in_tilemap);
            
            position_adjust_up, direction_out_up := push_point_out_of_tile(point, -gravity_vec_local);
            if point.direction_out != direction_out_up && length(position_adjust_up) < 0.15 {
                neighbor := get_neighbor(tilemap, point.tile_index, direction_out_up);
                if !neighbor || !is_side_solid(neighbor, point.direction_out) {
                    point.position_adjust = position_adjust_up;
                    point.direction_out   = direction_out_up;
                }
            }
            
            // if the distance to resolve the corner point in direction of gravity up angle is very small
            // this allows player and enemies to step up very small corners
            angle_diff := angle_difference_degrees(surface_angles[point.direction_out], gravity_up_angle);
            if can_stand_on_slopes && abs(angle_diff) <= 45 {
                cancel_velocity_scalar := 1.0;
                cancel_velocity_angle := surface_angles_local[point.direction_out] + 180;
                if !(entity.entity_flags & (.THROWN | .SLIDING)) { 
                    // slope_lerp := clamp(delerp(SMALL_SLOPE_ANGLE, 90, abs(angle_diff)), 0, 1).(float);
                    slope_lerp := clamp(delerp(SMALL_SLOPE_ANGLE, 75, abs(angle_diff)), 0, 1).(float);
                    cancel_velocity_angle  = (gravity_angle - tilemap.rotation) + angle_diff * slope_lerp;
                    slope_lerp = clamp(delerp(0, 60, abs(angle_diff)), 0, 1).(float);
                    cancel_velocity_scalar -= (0.5 * slope_lerp);
                }
                
                point.velocity_adjust += adjust_velocity(velocity_in_tilemap, cancel_velocity_angle, bounce_factor * get_tile_bounce(point.tile_ptr, point.direction_out), damping_thresh = 0.05);
                apply_velocity_adjustment(*velocity_adjust, point.velocity_adjust * cancel_velocity_scalar);
                
                maybe_crumble_tile(point.tile_ptr);
                collision_data.on_ground = true;
                apply_ground_velocity = true;
                collision_data.ground_angle = surface_angles[point.direction_out];
            }
            else {
                cancel_velocity_angle := surface_angles_local[point.direction_out] + 180;
                point.velocity_adjust = adjust_velocity(velocity_in_tilemap, cancel_velocity_angle, bounce_factor * get_tile_bounce(point.tile_ptr, point.direction_out), damping_thresh = 0.05);
                apply_velocity_adjustment(*velocity_adjust, point.velocity_adjust);
            }
            
            position_adjust += point.position_adjust;
        }
        else if collision_points[Direction.DR].had_collision {
            point := *collision_points[Direction.DR];
            
            point.position_adjust, point.direction_out = push_point_out_of_tile(point, center_point_in_tilemap - point.point_in_tilemap);

            position_adjust_up, direction_out_up := push_point_out_of_tile(point, -gravity_vec_local);
            if point.direction_out != direction_out_up && length(position_adjust_up) < 0.1 {
                neighbor := get_neighbor(tilemap, point.tile_index, direction_out_up);
                if !neighbor || !is_side_solid(neighbor, point.direction_out) {
                    point.position_adjust = position_adjust_up;
                    point.direction_out   = direction_out_up;
                }
            }
            
            // if the distance to resolve the corner point in direction of gravity up angle is very small
            // this allows player and enemies to step up very small corners
            angle_diff := angle_difference_degrees(surface_angles[point.direction_out], gravity_up_angle);
            if can_stand_on_slopes && abs(angle_diff) <= 45 {
                cancel_velocity_scalar := 1.0;
                cancel_velocity_angle := surface_angles_local[point.direction_out] + 180;
                if !(entity.entity_flags & (.THROWN | .SLIDING)) { 
                    // slope_lerp := clamp(delerp(SMALL_SLOPE_ANGLE, 90, abs(angle_diff)), 0, 1).(float);
                    slope_lerp := clamp(delerp(SMALL_SLOPE_ANGLE, 75, abs(angle_diff)), 0, 1).(float);
                    cancel_velocity_angle  = (gravity_angle - tilemap.rotation) + angle_diff * slope_lerp;
                    slope_lerp = clamp(delerp(0, 60, abs(angle_diff)), 0, 1).(float);
                    cancel_velocity_scalar -= (0.5 * slope_lerp);
                }
                
                point.velocity_adjust += adjust_velocity(velocity_in_tilemap, cancel_velocity_angle, bounce_factor * get_tile_bounce(point.tile_ptr, point.direction_out), damping_thresh = 0.05);
                apply_velocity_adjustment(*velocity_adjust, point.velocity_adjust * cancel_velocity_scalar);
                
                maybe_crumble_tile(point.tile_ptr);
                collision_data.on_ground = true;
                apply_ground_velocity = true;
                collision_data.ground_angle = surface_angles[point.direction_out];
            } 
            else {
                cancel_velocity_angle := surface_angles_local[point.direction_out] + 180;
                point.velocity_adjust = adjust_velocity(velocity_in_tilemap, cancel_velocity_angle, bounce_factor * get_tile_bounce(point.tile_ptr, point.direction_out), damping_thresh = 0.05);
                apply_velocity_adjustment(*velocity_adjust, point.velocity_adjust);
            }
            
            position_adjust += point.position_adjust;
        }
    }
    
    velocity_adjust_local := velocity_adjust; // grab this before transforming for debug purposes
    velocity_adjust = transform_vector(tilemap.transform, velocity_adjust);
    entity.velocity += velocity_adjust;
    entity.last_velocity_adjust = velocity_adjust;
    
    #if false {
        if abs(entity.velocity.y) > 0.05 || abs(tilemap.velocity.y) > 0.05 {
            print("====\n");
            print("entity.velocity.y  : %\n", entity.velocity.y);
            print("tilemap.velocity.y : %\n", tilemap.velocity.y);
            print("difference         : %\n", tilemap.velocity.y - entity.velocity.y);
            print("results            : %\n", results);
            print("entity velocity before       : %\n", velocity_before);
            print("entity velocity local before : %\n", velocity_in_tilemap_before);
            print("velocity_adjust : %\n", velocity_adjust);
            print("push out mask: "); print_directions_flags(collision_mask); print("\n");
            print("====\n");
            tilemap.dbg_do_print_vel_prev = true;
            tilemap.dbg_do_print_vel_prev_focused = tilemap.dbg_vel_prev_index;
        }
    }
    
    position_adjust = transform_vector(tilemap.transform, position_adjust);
    entity.position += position_adjust;
    
    if apply_ground_velocity {
        entity.ground_velocity = tilemap.velocity; // + rotate_radians(conveyor_velocity, rotation_radians);
        
        delta_angle  := tilemap.rotation_next - tilemap.rotation;
        foot_point   := get_position_in_tilemap(tilemap, center_point + collision_points[Direction.D].point_relative_to_origin);
        
        ref_point := foot_point - tilemap.anchor_point;
        entity_angular_velocity := rotate_degrees(ref_point, delta_angle) - ref_point;
        entity.ground_rotation_velocity = transform_vector(tilemap.transform, entity_angular_velocity);
    }
}



create_block_break_particles :: (
    tile:       Tile, 
    position:   Vector2, // TODO: use center of block
    pieces:     Vec2i,
    vel_y:      [2] float, // min and max values
    vel_x:      [2] float,
    vel_ax:     [2] float = .[0,0],
    vel_ay:     [2] float = .[0,0],
    vel_x_var:  float     = 0,
    vel_y_var:  float     = 0,
    vel_a_var:  float     = 0,
    vel_extra:  Vector2   = .{}
) {
    // render_info := get_tile_render_info(tile);
    // later maybe we need some way to store the clip for the peice particle that's associated with a tile
    // for now, we will just use the same particle for all blocks, since only brick blocks break
    
    piece_size := Vector2.{
        1.0 / pieces.x.(float),
        1.0 / pieces.y.(float),
    };
    piece_offset := piece_size / 2;
    
    for piece_x: 0..pieces.x-1 {
        for piece_y: 0..pieces.y-1 {
            vel_lerp := Vector2.{
                x = piece_x.(float) / (pieces.x - 1).(float),
                y = piece_y.(float) / (pieces.y - 1).(float),
            };
            
            _vel_x_var := vel_x_var * (random_get_zero_to_one() - 0.5);
            _vel_y_var := vel_y_var * (random_get_zero_to_one() - 0.5);
            _vel_a_var := vel_a_var * (random_get_zero_to_one() - 0.5);

            slot := get_next_slot(*get_active_level().particles.front);
            slot.occupied = true;
            
            slot.palette = get_tile_render_info(tile).palette;
            slot.texture = *particles_texture;

            slot.particle_type = .DYNAMIC;
            slot.dynamic = .{
                scale    = .{ 1, 1 },
                position = position + piece_offset + piece_size * .{ piece_x.(float), piece_y.(float) },
                velocity = .{
                    vel_extra.x + _vel_x_var + lerp(vel_x[0], vel_x[1], vel_lerp.x),
                    vel_extra.y + _vel_y_var + lerp(vel_y[0], vel_y[1], vel_lerp.y),
                },
                acceleration     = .{ 0, player_templates[0].physics.fall_gravity },
                angular_velocity = lerp(vel_ax[0], vel_ax[1], vel_lerp.x) + lerp(vel_ay[0], vel_ay[1], vel_lerp.y) + _vel_a_var,
                lifetime         = 10000,
                alpha            = 1,
            };
            
            anim := *slot.animation;
            anim.flags = .LOOP;
            anim.frame_count = 4;
            anim.frames[0] = .{ clip = .{ 0, 80, 8, 8 }, duration = 6.0 / 60.0, flip = .NONE                   };
            anim.frames[1] = .{ clip = .{ 0, 80, 8, 8 }, duration = 6.0 / 60.0, flip = .HORIZONTAL             };
            anim.frames[2] = .{ clip = .{ 0, 80, 8, 8 }, duration = 6.0 / 60.0, flip = .HORIZONTAL | .VERTICAL };
            anim.frames[3] = .{ clip = .{ 0, 80, 8, 8 }, duration = 6.0 / 60.0, flip = .VERTICAL               };
        }
    }
}

load_tile_info :: () -> bool {
    file, ok := read_entire_file("data/tileset.gon");
    if !ok {
        log("Unable to open tile info file!");
        return false;
    }
    defer free(file);
    
    for *tile_info_lookup {
        array_reset(*it.animation.frames);
    }
    array_reset(*tile_info_lookup);
    
    {
        empty_tile_ti: Tile_Info;
        empty_tile_ti.name = copy_string("Empty Tile");
        // memcpy(*empty_tile_ti.name, empty_tile_name.data, min(empty_tile_name.count, size_of(type_of(empty_tile_ti))));
        array_add(*tile_info_lookup, empty_tile_ti);
    }
    
    parser:, ok = LSD.parse_file_to_dom(file);
    defer LSD.deinit_parser(*parser);
    if !ok return false;
    
    LS.register_procedure(*parser.script, "palette", #procedure_of_call get_palette_index(""));
    LS.register_procedure(*parser.script, "sound", load_sfx);
    
    LSD.add_data_binding_to_dom(*parser, tile_info_lookup, "tiles");
    
    if !LSD.process_data_bindings(*parser)  {
        log("failed to load tileset!"); 
        assert(false);
        return false;
    }
    
    for tile_info_lookup for *it.animation.frames
        it.clip = .{ 
            x = (it.clip.x * TILE_TEXTURE_SIZE), 
            y = (it.clip.y * TILE_TEXTURE_SIZE), 
            w = TILE_TEXTURE_SIZE, 
            h = TILE_TEXTURE_SIZE 
        };
    
    // @Hack: add 1 to all "become on use" values if non-zero to account for LSD index not matching array index, 
    //        due to the fact that we always insert the empty tile as tile zero.
    for *tile_info_lookup 
        if it.become_on_use != 0
            then it.become_on_use += 1;
    
    // for tile_info_lookup {
    //     print("%\n", it.name);
    //     print("%\n", it.become_on_use);
    //     print("%\n", it.collision);
    //     print("%\n", it.animation);
    // }
    
    return true;
}

// returns index at which tile was actually placed, so that we can more easily place tiles procedurally
place_tile :: (using tilemap: *Tilemap, tile: Tile, _coords: Vec2i) -> (coords: Vec2i) {
    coords := _coords;
    
    move_data    : Vec2i;
    new_size     := size;
    new_capacity := capacity;
    
    do_realloc, do_move := false;
    
    if (coords.x < 0) {
        new_size.x = -coords.x + max_index.x + 1;
        margin := capacity.x - new_size.x;
        do_move = true;
        if (margin < 0) {
            do_realloc = true;
            new_capacity.x = xx next_power_of_2(xx new_size.x);
            margin = new_capacity.x - new_size.x;
        }
        move_data.x = (margin / 2) - coords.x;
    }
    else if (coords.x >= capacity.x) {
        new_size.x = coords.x - min_index.x + 1;
        margin := capacity.x - new_size.x;
        do_move = true;
        if (margin < 0) {
            do_realloc = true;
            new_capacity.x = xx next_power_of_2(xx new_size.x);
            margin = new_capacity.x - new_size.x;
        }
        move_data.x = (margin / 2) - min_index.x;
    }
    if (coords.y < 0) {
        new_size.y = -coords.y + max_index.y + 1;
        margin := capacity.y - new_size.y;
        do_move = true;
        if (margin < 0) {
            do_realloc = true;
            new_capacity.y = xx next_power_of_2(xx new_size.y);
            margin = new_capacity.y - new_size.y;
        }
        move_data.y = (margin / 2) - coords.y;
    }
    else if (coords.y >= capacity.y) {
        new_size.y = coords.y - min_index.y + 1;
        margin := capacity.y - new_size.y;
        do_move = true;
        if (margin < 0) {
            do_realloc = true;
            new_capacity.y = xx next_power_of_2(xx new_size.y);
            margin = new_capacity.y - new_size.y;
        }
        move_data.y = (margin / 2) - min_index.y;
    }
    
    if do_realloc  resize_tile_layer   (tilemap, new_capacity.x, new_capacity.y);
    if do_move     move_tile_layer_data(tilemap,    move_data.x,    move_data.y);
    size = new_size;
    
    min_index    += move_data;
    max_index    += move_data;
    coords       += move_data;
    anchor_point += to_Vector2(move_data);
    
    selected_index := coords.x + coords.y * capacity.x;
    if (selected_index < 0 || selected_index >= capacity.x * capacity.y) {
        log("attempted to place tile out of bounds");
    } else {
        data[selected_index] = tile;
        if Editor.do_auto_tile {
            data[selected_index].flags |= .AUTO_TILE;
            
            if !Editor.in_autotile_ruleset {
                data[selected_index].id = get_auto_tile(selected_index, tilemap, *Editor.autotile_ruleset);
                for get_neighboring_tiles(selected_index, tilemap) {
                    if it.pointer && (it.pointer.flags & .AUTO_TILE) {
                        it.pointer.id = get_auto_tile(it.index, tilemap, *Editor.autotile_ruleset);
                    }
                }
            }
        }
    }
    
    if coords.x < min_index.x then min_index.x = coords.x;
    if coords.y < min_index.y then min_index.y = coords.y;
    if coords.x > max_index.x then max_index.x = coords.x;
    if coords.y > max_index.y then max_index.y = coords.y;
    
    size.x = max(max_index.x - min_index.x + 1, 0);
    size.y = max(max_index.y - min_index.y + 1, 0);
    
    return coords;
}

remove_tile :: (tile: *Tile) {
    level := context.current_level;
    // notify any entities who are attached to this tile that the tile has been removed
    for *level.entities {
        if it.entity_flags & .IN_BLOCK {
            if it.in_block.tile_serial == tile.serial {
                it.entity_flags |= .REMOVE_ME;
            }
        }
    }
    tile.* = .{};
}

editor_remove_tile :: (using tilemap: *Tilemap, coords: Vec2i) {
    if coords.x <  0           return;
    if coords.y <  0           return;
    if coords.x >= capacity.x  return;
    if coords.y >= capacity.y  return;
    
    selected_index := coords.x + coords.y * capacity.x;
    remove_tile(*data[selected_index]);
    for get_neighboring_tiles(selected_index, tilemap) {
        if it.pointer && (it.pointer.flags & .AUTO_TILE) {
            it.pointer.id = get_auto_tile(it.index, tilemap, *Editor.autotile_ruleset);
        }
    }
    
    if coords.x == min_index.x {
        new_min: s32 = S32_MAX;
        for x: min_index.x..max_index.x
            for y: min_index.y..max_index.y
                if data[capacity.x * y + x].id {
                    new_min = x;
                    break x;
                }
        min_index.x = new_min;
    }
    if coords.x == max_index.x {
        new_max: s32 = 0;
        for #v2 < x: min_index.x..max_index.x
            for y: min_index.y..max_index.y
                if data[capacity.x * y + x].id {
                    new_max = x;
                    break x;
                }
        max_index.x = new_max;
    }
    if coords.y == min_index.y {
        new_min: s32 = S32_MAX;
        for y: min_index.y..max_index.y
            for x: min_index.x..max_index.x
                if data[capacity.x * y + x].id {
                    new_min = y;
                    break y;
                }
        min_index.y = new_min;
    }
    if (coords.y == max_index.y) {
        new_max: s32 = 0;
        for #v2 < y: min_index.y..max_index.y
            for x: min_index.x..max_index.x
                if data[capacity.x * y + x].id {
                    new_max = y;
                    break y;
                }
        max_index.y = new_max;
    }
    
    size.x = max(max_index.x - min_index.x + 1, 0);
    size.y = max(max_index.y - min_index.y + 1, 0);
}

resize_tile_layer :: (using tilemap: *Tilemap, w: s32, h: s32) -> bool {
    new_capacity := Vec2i.{ w, h };
    if new_capacity.x < capacity.x then new_capacity.x = capacity.x;
    if new_capacity.y < capacity.y then new_capacity.y = capacity.y;
    
    old_data_size :=     capacity.x *     capacity.y;
    new_data_size := new_capacity.x * new_capacity.y;
    
    array_resize(*data, new_data_size, initialize = false);
    
    // zero out new segment of memory
    memset(*data[old_data_size], 0, (new_data_size - old_data_size) * size_of(Tile));
    
    // copy rows forward accounting for change in width
    if capacity.x < new_capacity.x {
        src_i        := capacity.x * (capacity.y - 1);
        diff_per_row := new_capacity.x - capacity.x;
        copy_width   := capacity.x;
        row          := capacity.y - 1;
        
        assert(src_i + diff_per_row * row + copy_width <= new_data_size);
        
        while row >= 0 {
            diff := diff_per_row * row;
            assert(src_i >= 0);
            assert(diff  >= 0);
            memcpy(*data.data[src_i + diff], *data.data[src_i], copy_width * size_of(Tile));
            memset(*data.data[src_i], 0, diff * size_of(Tile));
            row   -= 1;
            src_i -= capacity.x;
        }
    }
    
    capacity = new_capacity;
    assert(capacity.x * capacity.y == data.count);
    
    return true;
}

move_tile_layer_data :: (using tile_layer: *Tilemap, x: int, y: int) {
    total_move := (y * capacity.x) + x;
    data_size  := capacity.x * capacity.y;
    if total_move > 0 {
        copy_width := (data_size - total_move) * size_of(Tile);
        memcpy(*data[total_move], *data[0], copy_width);
        memset(*data[0], 0, total_move * size_of(Tile));
    }
    else if total_move < 0 {
        total_move = -total_move;
        copy_width := (data_size - total_move) * size_of(Tile);
        memcpy(*data[0], *data[total_move], copy_width);
        memset(*data[data_size - total_move], 0, total_move * size_of(Tile));
    }
}

// maps a point from world space into local tilemap coordinate space
get_position_in_tilemap :: (tilemap: Tilemap, point: Vector2) -> Vector2 {
    return transform_point(tilemap.transform_inverse, point);
}

angle_difference_degrees :: (a1: float, a2: float) -> float {
    ret := fmod_cycling(a1 - a2, 360.0);
    if ret >= 180  ret -= 360;
    return ret;
}



tile_is_bumping :: (tile: Tile) -> bool {
    return tile.bump_clock > TILE_BUMP_TIME / 2; //&& .BROKEN not_in tile.flags
}

Tile_Bump_Type :: enum {
    SMALL_PLUMBER;
    BIG_PLUMBER;
    SHELL;
};

// needs tilemap and tile indices so that we can make block_hit_event
bump_tile :: (tilemap_index: int, tile_index: Vec2i, bump_type: Tile_Bump_Type, bump_dir: Direction, entity_velocity := Vec2f.{}) {
    level   := context.current_level;
    tilemap := *level.tilemaps[tilemap_index];
    tile    := get_tile(tilemap, tile_index);
    
    if tile == null  return;
    info := get_tile_info(tile.*);
    
    sound := *info.noises.bumped;
    
    if info.collision.flags & .BUMPABLE {
        if tile.bump_clock == 0 {
            tile.bump_clock = TILE_BUMP_TIME;
            
            // if tile serial number is 0, then there are no entities 'in' the tile, so we can still treat it as breakable
            if (info.collision.flags & .CONTAINER) /* && tile.serial != 0 */ {
                print("making block hit event for tile %\n", tile);
                array_add(*level.event_queue.events, make_block_hit_event(tilemap_index, get_index(tilemap, tile), bump_dir));
            }
            else if (info.collision.flags & .BREAKABLE) {
                // TODO: should apply some offset based on which side was hit, so that entities are shot out of opposite side of block
                // needs both tilemap space and worldspace offset
                // we will probaly also need to change how the particles are spawned to use center point as reference instead of top-left
                tile_position := get_tile_position(tilemap, tile_index);
                if bump_type >= .BIG_PLUMBER {
                    tile.flags |= .BROKEN;
                    create_block_break_particles(
                        tile      = tile.*,
                        position  = tile_position,
                        pieces    = .{ 2, 2 },
                        vel_x     = .[ -0.07 / UPDATES_PER_FRAME.(float),  0.07 / UPDATES_PER_FRAME.(float) ],
                        vel_y     = .[ -0.35 / UPDATES_PER_FRAME.(float), -0.30 / UPDATES_PER_FRAME.(float) ],
                        vel_ax    = .[ -7    / UPDATES_PER_FRAME.(float),  7    / UPDATES_PER_FRAME.(float) ],
                        vel_x_var = 0.05 / UPDATES_PER_FRAME.(float),
                        vel_y_var = 0.05 / UPDATES_PER_FRAME.(float),
                        vel_a_var = 3    / UPDATES_PER_FRAME.(float),
                        vel_extra = entity_velocity * .{ 0.5, 0 },
                    );
                    
                    sound = *info.noises.broken;
                }
            }
        }
    }
    
    if sound then play(sound);
}

get_tilemaps_sorted :: (tilemaps: []Tilemap) -> [] *Tilemap {
    sorted := NewArray(tilemaps.count, *Tilemap,, temp);
    for *sorted  it.* = *tilemaps[it_index];
    quick_sort(sorted, (a, b) => a.z_index - b.z_index);
    return sorted;
}



draw_collision_points :: (using collision_results: Tilemap_Collision_Data, offset: Vector2, render_unit: float, dbg_collision_mask: Direction_Set) {
    for collision_points {
        had_collision := (dbg_collision_mask & xx (1 << it_index)) != .NONE;
        render_draw_line(offset, offset + it.point_relative_to_origin * render_unit, color = ifx had_collision then Color4.{1,0,0,1} else .{0,0,1,1});
    }
}



/*
    Auto-tiling implementation notes:
    
    Create special tilemaps that are used as a sort of lookup table
    
    need some means of grouping related tiles by some group id
    OR
    create separate tile type for auto-tiles, then convert those to static tile on level prep
    
    first version may be more versatile as in theory it can be more responsive to changes in tilemaps at runtime
    which could be good for things like attaching spikes to crumbling or breakable tiles
    
    another thing
        sometimes we will want to define autotiling rules about how a single tile group tiles within itself, but other times we will want to defin the tiling between two groups
        Should empty tile actually necessitate an empty tile, or should it be a wildcard tile?
    
    
    how to handle tile randomization
        if purely visual, should probably operate by some other mechanism...?
    
    how to handle empty / wildcard tiles
    
    how to define generic interaction between classes of tiles
        e.g., spikes should tile via same rules with respect to any solid tile type
    
    
    
    
    tile flag indicates whether an individual tile will autotile
    that way, these tiles can continue to respond reactively to changes in the tilemap
    but, the user can still disable auto-tiling in order to place any tile manually
    
    
    instead of doing input layer / output layer like Tiled, tiles will be auto-tiled by a defined tile group id
    
    if two tiles are of different collision types, then rules will just vary I suppose. 
    no need to make too generic, can just write the most straightforward code here
    
    so, for .BLOCK tiles, we will just have simple rules based only on neighboring tiles
        + empty and wildcard
    
    should we only match strictly to tiles defined in ruleset tilemap, or get the best match and use that?
        match based on quantity of neighboring tiles that match rule
        if two rules match equally well, then pick random rule with some probability?
    
    will need to create a new editor window specifically for creating the auto-tile ruleset
    
    
    
    ok, we kinda somewhat functioning
        definitely need to create better tileset for testing though and then:
            - fix up how whitespace is considered in finding best match ?
            - add a proper wildcard tile
            - maybe show some kind of visual effect on selected tile when we place an autotile down? that way we can debug autotiling a bit, visually
            
    
*/

// predefined tile groups
TILE_GROUP_EMPTY    ::  0;
TILE_GROUP_WILDCARD :: -1;

get_auto_tile :: (tile_index: int, tilemap: *Tilemap, rules_tilemap: *Tilemap) -> Tile_ID {    
    // get input tile info
    if tile_index < 0 || tile_index >= tilemap.data.count  return 0;
    tile      := *tilemap.data[tile_index];
    tile_info := get_tile_info(tile);
    
    best_match_id := tile.id;
    best_match_score: int;
    
    neighboring_tiles := get_neighboring_tiles(tile_index, tilemap);
    
    // iterate over all rule tiles, compare neighbors for best matching tile
    // NOTE: will currently just use first best match, no support for randomization yet
    for *rule_tile, rule_tile_index: rules_tilemap.data {
        rule_tile_info := get_tile_info(rule_tile);
        if rule_tile.flags & .AUTO_TILE  continue; // NOTE: auto tile flag here means that tile will not be checked as a rule
        if rule_tile_info.group_id != tile_info.group_id  continue;
        
        neighboring_rules := get_neighboring_tiles(rule_tile_index, rules_tilemap);
        
        match_score: int;
        for nt: neighboring_tiles {
            // TODO: switch on tile collision type
            nr := neighboring_rules[it_index];
            
            // if nt.info == null || nr.info == null  continue;
            nt_group := ifx nt.info then nt.info.group_id;
            nr_group := ifx nr.info then nr.info.group_id;
            
            nt_id := ifx nt.pointer then nt.pointer.id;
            nr_id := ifx nr.pointer then nr.pointer.id;
            
            if nt_group == nr_group {
                match_score += 1;
            } 
            // group_id == 0 means use tile id
            else if nr_group == 0 && nt_id == nr_id {
                match_score += 1;
            } 
            // empty rule tile does not increase match score, but will also not decrement the match score
            else if nr_id != 0 {
                match_score -= 1;
            }
        }
        
        if match_score > best_match_score {
            best_match_id = rule_tile.id;
            best_match_score = match_score;
        }
    }
    
    return best_match_id;
}

Tile_And_Info :: struct { index: int; pointer: *Tile; info: *Tile_Info; }

get_neighboring_tiles :: (tile_index: int, tilemap: *Tilemap) -> Enumerated_Array(Direction, Tile_And_Info) {
    neighboring_tiles: Enumerated_Array(Direction, Tile_And_Info);
    
    neighboring_tiles.U .index = tile_index - tilemap.capacity.x; 
    neighboring_tiles.D .index = tile_index + tilemap.capacity.x; 
    neighboring_tiles.L .index = tile_index - 1; 
    neighboring_tiles.R .index = tile_index + 1; 
    neighboring_tiles.UL.index = neighboring_tiles.U.index - 1; 
    neighboring_tiles.UR.index = neighboring_tiles.U.index + 1; 
    neighboring_tiles.DL.index = neighboring_tiles.D.index - 1; 
    neighboring_tiles.DR.index = neighboring_tiles.D.index + 1; 
    
    for *neighboring_tiles {
        if it.index < 0 || it.index >= tilemap.data.count  continue;
        it.pointer = *tilemap.data[it.index];
        it.info    = get_tile_info(it.pointer);
    }
    
    return neighboring_tiles;
}

get_surface_angles :: (tilemap: *Tilemap) -> [4] float {
    surface_angles: [4] float;
    surface_angles[Direction.U] = fmod_cycling(tilemap.rotation + tilemap.skew.y + 270, 360);
    surface_angles[Direction.R] = fmod_cycling(tilemap.rotation - tilemap.skew.x +   0, 360);
    surface_angles[Direction.D] = fmod_cycling(tilemap.rotation + tilemap.skew.y +  90, 360);
    surface_angles[Direction.L] = fmod_cycling(tilemap.rotation - tilemap.skew.x + 180, 360);
    return surface_angles;
}
