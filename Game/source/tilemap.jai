#import "Random";

/*
    TODO: tile uuids
    
    when loading tileset, if tile info does not already have an assigned uuid, generate one automatically and save it back ?
    
    
    when loading a level
        iterate over all tilemaps and remap tile id to use uuid instead
        we will have to save a copy of the tileset uuid list in the level file
        
    
*/

block_noises: Entity_Sounds;

Tile_Collision :: struct {
    type:   Tile_Collision_Type;
    flags:  Tile_Collision_Flags;
    // mask:   Direction_Set; // used for semisolids to know which directions will push player out
};

Tile_Collision_Type :: enum {
    NONE;
    BLOCK;
    COIN;
    SPIKES;
};

Tile_Collision_Flags :: enum_flags {
    SOLID;
    BREAKABLE;
    BUMPABLE;
    CRUMBLE;
    SEMISOLID;
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

TILE_BUMP_TIME     :: 0.2; // TODO: we should put this in terms of seconds
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
    persistent_id:  Tile_ID;
    name:           string;
    collision:      Tile_Collision;
    palette:        Palette_ID;
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

Tileset :: [..] Tile_Info;

tile_info_lookup: Tileset;

remap_tile_ids_for_storage :: (tilemap: *Tilemap) {
    unmapped_ids: [..] Tile_ID;
    unmapped_ids.allocator = temp;
    
    for *tile: tilemap.data {
        if tile.id == 0 then continue tile;
        if tile.id < 0 || tile.id >= tile_info_lookup.count {
            array_add_if_unique(*unmapped_ids, tile.id);
            tile.id = 0; // default to zero if tile id is out of bounds
        }
        tile.id = tile_info_lookup[tile.id].persistent_id;
    }
    
    if unmapped_ids {
        // NOTE: this really should never happen, but I guess if it does, I'd like to be notified...
        log("Error: Unable to remap the following tile ids for storage, because they were out of bounds: %", unmapped_ids);
    }
}

remap_tile_ids_for_runtime :: (tilemap: *Tilemap) {
    unmapped_ids: [..] Tile_ID;
    unmapped_ids.allocator = temp;
    
    for *tile: tilemap.data {
        if tile.id == 0 then continue tile;
        for info, info_index: tile_info_lookup {
            if tile.id == info.persistent_id {
                // if tile.id != 0  log("% -> %", tile.id, info_index);
                tile.id = xx info_index;
                continue tile;
            }
        }
        array_add_if_unique(*unmapped_ids, tile.id);
        tile.id = 0; // default to zero if we cannot match the persistent id
    }
    
    if unmapped_ids {
        log("Error: Unable to remap the following tile ids for runtime: %", unmapped_ids);
    }
}

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
    palette:        Palette_ID;
};

get_tile_render_info :: (tile: Tile) -> Tile_Render_Info {
    using tri : Tile_Render_Info;
    color_mod = ifx tile.id == 0 then Color4.{} else .{ 1, 1, 1, 1 };

    ti := get_tile_info(tile);
    if ti == null {
        print("Error: unable to retreive tile info.\n");
        return tri;
    }

    tri.texture = *textures.TILES;
    tri.palette = ti.palette;
    
    if ti.animator.current < ti.animation.frames.count {
        clip = rect_to_frect(ti.animation.frames[ti.animator.current].clip);
    }
    
    #if EDITOR_ENABLED {
        if Editor.in_autotile_ruleset && (.AUTO_TILE & tile.flags) {
            tri.color_mod.a = 8.0/16.0;
        }
    }
    
    return tri;
}

// is_side_solid :: (tile: Tile, direction: Direction) -> bool {
//     info := get_tile_info(tile);
//     if info.collision.type != .BLOCK     return false;
//     if !(info.collision.flags & .SOLID)  return false;
    
//     return !(info.collision.flags & .SEMISOLID);// || (info.collision.mask & xx (1 << direction));
// }

// the area of the tilemap which actually contains tiles
get_content_region :: (tilemap: *Tilemap) -> Rect {
    if tilemap.max_index.x < tilemap.min_index.x
    || tilemap.max_index.y < tilemap.min_index.y {
        return .{};
    }
    return .{
        position = tilemap.min_index, 
        size     = tilemap.max_index - tilemap.min_index + .{ 1, 1 }
    };
}

// we assume that if tilemap traveled more than 1 block in a single frame, 
//   then it must have teleported or its path is otherwise discontinuous
// if this occurs, we treat the instantaneous velocity as .{ 0, 0 }
get_velocity :: (tilemap: *Tilemap) -> Vec2f {
    velocity := tilemap.offset_next - tilemap.offset;
    return ifx abs(velocity.x) <= 1.0 && abs(velocity.y) <= 1.0 then velocity else .{};
}

Tilemap :: struct {
    data:           [] Tile;
    size:           Vec2i;
    
    min_index:      Vec2i = .{ S32_MAX, S32_MAX }; // only used in level editor
    max_index:      Vec2i; // only used in level editor
    
    root_offset:    Vector2;
    
    // TODO: maybe we go back to rendering out to texture. Would probably help give more flexibility when rendering tilemaps w/ shaders and such
    // texture:        Texture;
    
    offset:         Vector2;
    offset_next:    Vector2;
    
    name:           [32] u8;
    z_index:        int;
    flags:          Flags;
    
    color_mod:      Color4 = .{ 1, 1, 1, 1 };
    
    
    // TODO: layer wrapping, these values are tentative, only here for memory of old impl
    // wrap_enabled:   Direction_Set;
    // wrap_position:  Vector2;
    // wrap_margin:    Vector2;
    // frame:          u32;
    
    // may need to increase or decrease this in the future, will just have to wait and see
    // we really just need to be smarter about how we calculate trails, considering when paths are periodic
    // but this will require some means of analyzing LS scripts quite deeply
    editor_trail_points: [128] Vector2;
    
    Flags :: enum_flags {
        DISABLE_COLLISIONS;
        
        HOVERED_IN_EDITOR;
        SELECTED_IN_EDITOR;
        HIDDEN_IN_EDITOR;
    };
    
    EDITOR_FLAGS :: Flags.HOVERED_IN_EDITOR | .SELECTED_IN_EDITOR | .HIDDEN_IN_EDITOR;
};

free_tilemap :: (tilemap: *Tilemap) {
    array_free(tilemap.data); 
}

/*
    Tilemaps have 2 update routines since we need to do some updating before level script runs, and some after it runs.
    Entities will probably end up needing something similar, unfortunately...
    
    before script:
        update tilemap position and rotation
    
    after script:
        offset_next and rotation next used to calculate next transform, since those were updated in script
        calculate velocity of platforms and update tiles
*/

update_tilemap_prescript :: (using tilemap: *Tilemap) {
    offset = offset_next;
}

update_tilemap_postscript :: (using tilemap: *Tilemap) {
    #if false {
        count := type_info(type_of(dbg_vel_prev)).array_count;
        dbg_vel_prev_index = (dbg_vel_prev_index + 1) % count;
        dbg_vel_prev[dbg_vel_prev_index] = .[ velocity, offset_next, offset ];
        
        if dbg_do_print_vel_prev && (dbg_vel_prev_index == (dbg_do_print_vel_prev_focused + count/2) % count) {
            print("previous velocities:\n");
            for 0..count {
                index := (dbg_vel_prev_index + it) % count;
                if index == dbg_do_print_vel_prev_focused {
                    print("--> ");
                } else {
                    print("    ");
                }
                print("%\n", dbg_vel_prev[index]);
            }
            print("\n");
            dbg_do_print_vel_prev = false;
        }
    }
    
    for *tile, index: tilemap.data {
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
    size  = .{ 8, 8 };
    array_resize(*data, size.x * size.y);
    
    tilemap_name := tprint("%", FormatInt.{value=random_get(),base=16});
    memcpy(*name[0], *tilemap_name[0], min(size_of(type_of(name)), tilemap_name.count));
}

// TODO: the get tile functions need to be a bit more sophisticated to account for difference in size vs size
get_tile :: (tilemap: *Tilemap, i: int) -> *Tile {
    if i < 0 || i >= tilemap.size.x * tilemap.size.y {
        return null;
    }
    return *tilemap.data[i];
}

get_tile :: (tilemap: *Tilemap, x: int, y: int) -> *Tile {
    if x < 0 || x >= tilemap.size.x ||
       y < 0 || y >= tilemap.size.y {
        return null;
    }
    return *tilemap.data[y * tilemap.size.x + x];
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
    return .{ index.(s32) % tilemap.size.x, index.(s32) / tilemap.size.x };
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
    return tilemap.offset + to_Vec2f(index_2d) + offset;
}

get_tile_position :: (tilemap: *Tilemap, index: Vec2i, offset := Vec2f.{}) -> Vec2f {
    return tilemap.offset + to_Vec2f(index) + offset;
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
    alpha:              float    = 1,
    offset:             Vec2f    = .{0,0}
) {
    if !tilemap.data || tilemap.size.x == 0 || tilemap.size.y == 0  return;
    
    tile := *tilemap.data[0];
    rect := Rectf.{ offset.x, offset.y, tile_render_unit, tile_render_unit };  
    
    for 0..tilemap.size.y-1 {
        defer {
            rect.x = offset.x;
            rect.y += tile_render_unit;
        }
        
        for 0..tilemap.size.x-1 {
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
                lerp := tile.bump_clock.(float) / (TILE_BUMP_TIME * updates_per_second);
                lerp = 1.0 - pow(1.0 - 2 * lerp, 2);
                dst.y -= lerp * TILE_BUMP_DISTANCE * tile_render_unit;
            }
            
            info := get_tile_info(tile);
            tri  := get_tile_render_info(tile);
            
            tri.color_mod.a *= alpha;
            
            if (info.collision.flags & .CRUMBLE) && (tile.crumble_timer != 0) {
                tri.color_mod.a *= tile.crumble_timer.(float) / (info.crumble_time * frames_per_second);
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

Tilemap_Collision_Data :: struct {
    position_in_tilemap:    Vec2f; 
    velocity_in_tilemap:    Vec2f;
    position_adjust:        Vec2f;
    velocity_adjust:        Vec2f;
    broad_phase_margin:     float;
    on_ground:              bool;
    had_collision:          bool;
}

Tilemap_Collision_Point :: struct {
    point_relative_to_origin:   Vec2f;
    direction_out:              Direction;
    
    point_in_tilemap:           Vec2f;
    had_collision:              bool;
    
    tile_index:         Vec2i; // 2d index is probably easier to convert back to 1d rather than the other way around
    tile_ptr:           *Tile; // can also get 1d index from tile_ptr
    tile_info:          *Tile_Info;
    
    // collision response stuff, will probably not be needed in future
    // may be useful for debugging though
    position_adjust:    Vec2f;
    velocity_adjust:    Vec2f;
}

reset_for_new_tilemap :: (using collision_data: *Tilemap_Collision_Data) {
    // for *points {
    //     defer_restore(*it.point_relative_to_origin);
    //     it.* = .{};
    // }
    
    // on_ground       = false;
    // // ground_angle    = 0;
    // had_collision   = false;
    // position_adjust = .{};
    // velocity_adjust = .{};
}

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
    // reset_for_new_tilemap(collision_data);
    
    // position_in_tilemap = get_position_in_tilemap(tilemap, center_point);
    // velocity_in_tilemap = velocity - tilemap.velocity;
    
    // // if !broad_phase_collision_check(tilemap, center_point_in_tilemap, broad_phase_margin)  return false;
    
    // for *points {
    //     it.point_in_tilemap = get_position_in_tilemap(tilemap, center_point + it.point_relative_to_origin);
    //     it.tile_index       = to_Vec2i_floor(it.point_in_tilemap);
    //     it.tile_ptr         = get_tile(tilemap, it.tile_index);
    //     if !it.tile_ptr  continue;
        
    //     it.tile_info = get_tile_info(it.tile_ptr);
        
    //     // TODO: broken tiles?
        
    //     if it.tile_info.collision.type == .BLOCK 
    //     && (it.tile_info.collision.flags & .SOLID) {
    //         if it.tile_info.collision.flags & .SEMISOLID {
    //             // TODO
                
                
    //         }
            
    //         it.had_collision = true;
    //         had_collision = true;
    //     }
    // }
    
    return had_collision;
}

// TODO: remove entity parameter (actually just refactor this whole procedure for enemy/ player seaprately)
handle_collision_response :: (tilemap: *Tilemap, using collision_data: *Tilemap_Collision_Data, entity: *Entity) {
    // apply_ground_velocity := false;
    
    // // TODO
    // entity_collide_tile :: (tile: *Tile, entity: *Entity) {
    //     info := get_tile_info(tile);
    //     if info.collision.flags & .CRUMBLE {
    //         if tile.crumble_timer == 0 {
    //             tile.crumble_timer = (info.crumble_time * frames_per_second).(u16);
    //         }
    //     }
    // }
    
    // get_tile_bounce :: (tile: *Tile, dir: Direction) -> float {
    //     mod := get_tile_modifier(tile, dir);
    //     return ifx mod == .BOUNCY then 1.75 else 1.0;
    // }
    
    // if points[Direction.L].had_collision {
    //     point := *points[Direction.L];
    //     position_in_tile := point.point_in_tilemap - floor(point.point_in_tilemap);
    //     entity.position.x += 1 - position_in_tile.x;
    //     if entity.velocity.x < tilemap.velocity.x {
    //         entity.velocity.x = tilemap.velocity.x;
    //     }
    // }
    
    // if points[Direction.R].had_collision {
    //     point := *points[Direction.R];
    //     position_in_tile := point.point_in_tilemap - floor(point.point_in_tilemap);
    //     entity.position.x -= position_in_tile.x;
    //     if entity.velocity.x > tilemap.velocity.x {
    //         entity.velocity.x = tilemap.velocity.x;
    //     }
    // }
    
    // BONK_PREVENTION_FUDGE_FACTOR := 0.5 / updates_per_second;
    
    // if points[Direction.U].had_collision {
    //     point := *points[Direction.U];
    //     position_in_tile := point.point_in_tilemap - floor(point.point_in_tilemap);
    //     entity.position.y += 1 - position_in_tile.y;
    //     if entity.velocity.y < tilemap.velocity.y {
    //         entity.velocity.y = tilemap.velocity.y;
    //     }
    // } else {
    //     if points[Direction.UL].had_collision {
    //         point := *points[Direction.UL];
    //         position_in_tile := point.point_in_tilemap - floor(point.point_in_tilemap);
            
    //         // determine if we push out as .U or .L
    //         // TODO: put velocity in terms of updates/second
    //         point.direction_out = ifx 1-position_in_tile.x < 1-position_in_tile.y || velocity_in_tilemap.x > BONK_PREVENTION_FUDGE_FACTOR then .L else .U;
            
    //         if point.direction_out == {
    //           case .U;
    //             entity.position.y += 1 - position_in_tile.y;
    //             if entity.velocity.y < tilemap.velocity.y {
    //                 entity.velocity.y = tilemap.velocity.y;
    //             }
    //           case .L;
    //             entity.position.x += 1 - position_in_tile.x;
    //             if entity.velocity.x < tilemap.velocity.x {
    //                 entity.velocity.x = tilemap.velocity.x;
    //             }
    //         }
    //     }
    //     if points[Direction.UR].had_collision {
    //         point := *points[Direction.UR];
    //         position_in_tile := point.point_in_tilemap - floor(point.point_in_tilemap);
            
    //         // determine if we push out as .U or .R
    //         // TODO: put velocity in terms of updates/second
    //         point.direction_out = ifx position_in_tile.x < 1-position_in_tile.y || velocity_in_tilemap.x > BONK_PREVENTION_FUDGE_FACTOR then .R else .U;
            
    //         if point.direction_out == {
    //           case .U;
    //             entity.position.y += 1 - position_in_tile.y;
    //             if entity.velocity.y < tilemap.velocity.y {
    //                 entity.velocity.y = tilemap.velocity.y;
    //             }
    //           case .R; 
    //             entity.position.x -= position_in_tile.x;
    //             if entity.velocity.x > tilemap.velocity.x {
    //                 entity.velocity.x = tilemap.velocity.x;
    //             }
    //         }
    //     }
    // }
    
    // if points[Direction.D].had_collision {
    //     point := *points[Direction.D];
    //     position_in_tile := point.point_in_tilemap - floor(point.point_in_tilemap);
    //     entity.position.y -= position_in_tile.y;
    //     if entity.velocity.y > tilemap.velocity.y {
    //         entity.velocity.y = tilemap.velocity.y;
    //     }
    //     entity_collide_tile(point.tile_ptr, entity);
    //     collision_data.on_ground = true;
    //     apply_ground_velocity = true;
    // } else {
    //     if points[Direction.DL].had_collision {
    //         point := *points[Direction.DL];
    //         position_in_tile := point.point_in_tilemap - floor(point.point_in_tilemap);
            
    //         // determine if we push out as .D or .L
    //         // TODO: put velocity in terms of updates/second
    //         point.direction_out = ifx 1-position_in_tile.x < position_in_tile.y then .L else .D;
            
    //         if point.direction_out == {
    //           case .D;
    //             entity.position.y -= position_in_tile.y;
    //             if entity.velocity.y > tilemap.velocity.y {
    //                 entity.velocity.y = tilemap.velocity.y;
    //             }
    //             entity_collide_tile(point.tile_ptr, entity);
    //             collision_data.on_ground = true;
    //             apply_ground_velocity = true;
    //           case .L;
    //             entity.position.x += 1 - position_in_tile.x;
    //             if entity.velocity.x < tilemap.velocity.x {
    //                 entity.velocity.x = tilemap.velocity.x;
    //             }
    //         }
    //     }
    //     if points[Direction.DR].had_collision {
    //         point := *points[Direction.DR];
    //         position_in_tile := point.point_in_tilemap - floor(point.point_in_tilemap);
            
    //         // determine if we push out as .D or .R
    //         // TODO: put velocity in terms of updates/second
    //         point.direction_out = ifx position_in_tile.x < position_in_tile.y then .R else .D;
            
    //         if point.direction_out == {
    //           case .D;
    //             entity.position.y -= position_in_tile.y;
    //             if entity.velocity.y > tilemap.velocity.y {
    //                 entity.velocity.y = tilemap.velocity.y;
    //             }
    //             entity_collide_tile(point.tile_ptr, entity);
    //             collision_data.on_ground = true;
    //             apply_ground_velocity = true;
    //           case .R; 
    //             entity.position.x -= position_in_tile.x;
    //             if entity.velocity.x > tilemap.velocity.x {
    //                 entity.velocity.x = tilemap.velocity.x;
    //             }
    //         }
    //     }
    // }
    
    // entity.velocity += velocity_adjust;
    // entity.last_velocity_adjust = velocity_adjust;
    
    // #if false {
    //     if abs(entity.velocity.y) > 0.05 || abs(tilemap.velocity.y) > 0.05 {
    //         print("====\n");
    //         print("entity.velocity.y  : %\n", entity.velocity.y);
    //         print("tilemap.velocity.y : %\n", tilemap.velocity.y);
    //         print("difference         : %\n", tilemap.velocity.y - entity.velocity.y);
    //         print("results            : %\n", results);
    //         print("entity velocity before       : %\n", velocity_before);
    //         print("entity velocity local before : %\n", velocity_in_tilemap_before);
    //         print("velocity_adjust : %\n", velocity_adjust);
    //         print("push out mask: "); print_directions_flags(collision_mask); print("\n");
    //         print("====\n");
    //         tilemap.dbg_do_print_vel_prev = true;
    //         tilemap.dbg_do_print_vel_prev_focused = tilemap.dbg_vel_prev_index;
    //     }
    // }
    
    // if apply_ground_velocity {
    //     entity.ground_velocity = tilemap.velocity; // + conveyor_velocity;
    // }
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
            slot.texture = *textures.PARTICLES;

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
    file, ok := read_entire_file("data/tileset.lsd");
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
    
    LS.register_procedure(*parser.script, "palette", get_color_animation_index);
    LS.register_procedure(*parser.script, "sound", load_sfx);
    
    LSD.add_data_binding_to_dom(*parser, tile_info_lookup, "tiles");
    
    if !LSD.process_data_bindings(*parser)  {
        log("failed to load tileset!"); 
        log(LSD.format_error(parser.error));
        assert(false);
        return false;
    }
    
    for tile_info_lookup for *it.animation.frames
        it.clip = .{ 
            x = (it.clip.x * tile_texture_size), 
            y = (it.clip.y * tile_texture_size), 
            w = tile_texture_size, 
            h = tile_texture_size 
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

// // returns index at which tile was actually placed, so that we can more easily place tiles procedurally
// place_tile :: (using tilemap: *Tilemap, tile: Tile, _coords: Vec2i) -> (coords: Vec2i) {
//     coords := _coords;
    
//     content_region := get_content_region(tilemap);
    
//     new_min_index := min_of_each(coords, min_index);
//     new_max_index := max_of_each(coords, max_index);
    
//     new_content_region := Rect.{
//         position = tilemap.min_index, 
//         size     = tilemap.max_index - tilemap.min_index + .{ 1, 1 }
//     };
    
//     margin  := size - new_content_region.size;
//     do_move := margin.x < 0 || margin.y < 0;
    
//     total_capacity          := tilemap.data.count;
//     total_capacity_required := new_content_region.size.x.(int) * new_content_region.size.y.(int);
    
    
//     print_vars(coords, new_min_index, new_max_index, content_region, new_content_region, size, margin, total_capacity, total_capacity_required);
    
    
//     get_halves :: (num: s32) -> s32, s32 {
//         half := num / 2;
//         return half, num - half;
//     }
    
    
//     // TODO: maybe use some heuristic for reallocating when we are really close to total size instead of moving data a bunch as we get close to the limit
    
//     new_capacity := size;
    
//     // if we have to realloc, then we always move too
//     if total_capacity_required > total_capacity {
//         // because this new implementation can basically share data the total tilemap size between the x and y axes, 
//         // we have to do a little bit of figuring to split the additional space evenly between the two axes, and on each side of the content region
//         total_capacity = next_power_of_two(total_capacity_required);        
//         array_resize(*data, total_capacity, initialize = false);
//         do_move = true;
//     }
    
//     if do_move {
//         // recalculate margin/size for new content region
//         spare_tiles := total_capacity - total_capacity_required;
        
//         // I don't think this should ever split unevenly, but just in case...
//         margin.x, margin.y = get_halves(xx spare_tiles);
//         if margin.x != margin.y  log("Info: We split it right down the middle, and someone got the bigger half!");
        
//         new_content_region.position = margin / 2;
        
//         new_capacity = new_content_region.size + margin;
        
//         print_vars(new_content_region, new_capacity, total_capacity, new_capacity.x * new_capacity.y);
//         assert(new_capacity.x * new_capacity.y == total_capacity); // make sure we did the math correctly
        
//         /*
//             TODO TODO TODO TODO TODO 
            
//             Cheating right now so I can fix other things and come back to this! 
//             To future me: DON'T JUST LEAVE IT LIKE THIS!
//         */
//         // not using temp just because this may be a very large allocation and we are just gonna free it right away anyhow...
//         temp_data := array_copy(tilemap.data);
//         defer array_free(temp_data);
        
//         memset(tilemap.data.data, 0, tilemap.data.count * size_of(Tile));
        
//         // naive rectangle copy
//         copy_width := content_region.w;
//         src_stride := size.x;
//         dst_stride := new_capacity.x;
        
//         src_ptr := temp_data.data    + (    content_region.y * src_stride +     content_region.x);
//         dst_ptr := tilemap.data.data + (new_content_region.y * dst_stride + new_content_region.x);
        
//         for 0..content_region.h-1 {
//             memcpy(dst_ptr, src_ptr, src_stride);
//             src_ptr += src_stride;
//             dst_ptr += dst_stride;
//         }
        
        
        
//         // This is gonna be tricky, so I probably won't get it first try
//         // basically, we need to perform a rectangle copy to move tilemap data either forwards or backwards, and with a variable stride on the src and dst
//         // I am not even entirey sure yet if this is doable in all cases.
        
        
//         // we need to assert every possible assumption that is made here, and there are a lot!

//         // assert(dst_rect.x > 0);
//         // assert(dst_rext.y > 0);
        
//         // assert(dst_rect.w >= src_rect.w);
//         // assert(dst_rect.h >= src_rect.h);
        
//         // assert(dst_stride >= dst_rect.w);
//         // assert(src_stride >= src_rect.w);
        
//         // // assert(dst_stride >= src_stride); // we can't assume this, because we may be borrowing width to add height
        
//         // dst_ptr := tilemap.data + ;
//         // src_ptr := tilemap.data + ;
//         // dst_stride
//         // copy_width := 
//     }
    
//     coords   += new_min_index - min_index;
//     min_index = new_min_index;
//     max_index = new_max_index;
//     size  = new_capacity;
    
//     selected_index := coords.x + coords.y * size.x;
//     if (selected_index < 0 || selected_index >= size.x * size.y) {
//         log("attempted to place tile out of bounds");
//     } else {
//         data[selected_index] = tile;
        
//         // TODO: explicitly parameterize whether or not to do auto tile stuff
//         #if EDITOR_ENABLED {
//         if Editor.do_auto_tile {
//             data[selected_index].flags |= .AUTO_TILE;
            
//             if !Editor.in_autotile_ruleset {
//                 data[selected_index].id = get_auto_tile(selected_index, tilemap, *Editor.autotile_ruleset);
//                 for get_neighboring_tiles(selected_index, tilemap) {
//                     if it.pointer && (it.pointer.flags & .AUTO_TILE) {
//                         it.pointer.id = get_auto_tile(it.index, tilemap, *Editor.autotile_ruleset);
//                     }
//                 }
//             }
//         }
//         }
//     }
    
//     return coords;
// }

remove_tile :: (tile: *Tile) {
    tile.* = .{};
}

editor_remove_tile :: (using tilemap: *Tilemap, coords: Vec2i) {
    if coords.x <  0           return;
    if coords.y <  0           return;
    if coords.x >= size.x  return;
    if coords.y >= size.y  return;
    
    selected_index := coords.x + coords.y * size.x;
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
                if data[size.x * y + x].id {
                    new_min = x;
                    break x;
                }
        min_index.x = new_min;
    }
    if coords.x == max_index.x {
        new_max: s32 = 0;
        for #v2 < x: min_index.x..max_index.x
            for y: min_index.y..max_index.y
                if data[size.x * y + x].id {
                    new_max = x;
                    break x;
                }
        max_index.x = new_max;
    }
    if coords.y == min_index.y {
        new_min: s32 = S32_MAX;
        for y: min_index.y..max_index.y
            for x: min_index.x..max_index.x
                if data[size.x * y + x].id {
                    new_min = y;
                    break y;
                }
        min_index.y = new_min;
    }
    if (coords.y == max_index.y) {
        new_max: s32 = 0;
        for #v2 < y: min_index.y..max_index.y
            for x: min_index.x..max_index.x
                if data[size.x * y + x].id {
                    new_max = y;
                    break y;
                }
        max_index.y = new_max;
    }
}


resize_tile_layer :: (using tilemap: *Tilemap, w: s32, h: s32) -> bool {
    new_size := Vec2i.{ w, h };
    if new_size.x < size.x then new_size.x = size.x;
    if new_size.y < size.y then new_size.y = size.y;
    
    old_data_size :=     size.x *     size.y;
    new_data_size := new_size.x * new_size.y;
    
    array_resize(*data, new_data_size, initialize = false);
    
    // zero out new segment of memory
    memset(*data[old_data_size], 0, (new_data_size - old_data_size) * size_of(Tile));
    
    // copy rows forward accounting for change in width
    if size.x < new_size.x {
        src_i        := size.x * (size.y - 1);
        diff_per_row := new_size.x - size.x;
        copy_width   := size.x;
        row          := size.y - 1;
        
        assert(src_i + diff_per_row * row + copy_width <= new_data_size);
        
        while row >= 0 {
            diff := diff_per_row * row;
            assert(src_i >= 0);
            assert(diff  >= 0);
            memcpy(*data.data[src_i + diff], *data.data[src_i], copy_width * size_of(Tile));
            memset(*data.data[src_i], 0, diff * size_of(Tile));
            row   -= 1;
            src_i -= size.x;
        }
    }
    
    size = new_size;
    assert(size.x * size.y == data.count);
    
    return true;
}

move_tile_layer_data :: (using tile_layer: *Tilemap, x: int, y: int) {
    total_move := (y * size.x) + x;
    data_size  := size.x * size.y;
    
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
    return point - tilemap.offset;
}

angle_difference_degrees :: (a1: float, a2: float) -> float {
    ret := fmod_cycling(a1 - a2, 360.0);
    if ret >= 180  ret -= 360;
    return ret;
}



tile_is_bumping :: (tile: Tile) -> bool {
    return tile.bump_clock > xx (TILE_BUMP_TIME * updates_per_second / 2); //&& .BROKEN not_in tile.flags
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
            tile.bump_clock = xx (TILE_BUMP_TIME * updates_per_second);
            
            if info.collision.flags & .BREAKABLE {
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
                        vel_x     = .[ -0.07 / updates_per_frame.(float),  0.07 / updates_per_frame.(float) ],
                        vel_y     = .[ -0.35 / updates_per_frame.(float), -0.30 / updates_per_frame.(float) ],
                        vel_ax    = .[ -7    / updates_per_frame.(float),  7    / updates_per_frame.(float) ],
                        vel_x_var = 0.05 / updates_per_frame.(float),
                        vel_y_var = 0.05 / updates_per_frame.(float),
                        vel_a_var = 3    / updates_per_frame.(float),
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
    // for points {
    //     had_collision := (dbg_collision_mask & xx (1 << it_index)) != .NONE;
    //     render_draw_line(offset, offset + it.point_relative_to_origin * render_unit, color = ifx had_collision then Color4.{1,0,0,1} else .{0,0,1,1});
    // }
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
    
    neighboring_tiles.U .index = tile_index - tilemap.size.x; 
    neighboring_tiles.D .index = tile_index + tilemap.size.x; 
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


// point should be the point within the tile [0 - 1)
do_spike_tile_collision :: (tile: *Tile, point: Vec2f) {
    // collision_type :: Enumerated_Array(Direction_Set, Direction_Set) = {
    //     .D = .D,
    //     .D | .L | .R = .D,

    //     .U = .U,
    //     .U | .L | .R = .U,

    //     .L = .L,
    //     .U | .D | .L = .L,

    //     .R = .R,
    //     .U | .D | .R = .R,

    //     .NONE      = .NONE,
    //     .U | .D    = .NONE,
    //     .L | .R    = .NONE,
    //     .PRIMARY   = .NONE,

    //     .U | .L = .U | .L,
    //     .U | .R = .U | .R,
    //     .D | .L = .D | .L,
    //     .D | .R = .D | .R,
    // };
    
    // spike_w := 0.65,
    // spike_h := 0.40,
    // spike_x := (1.0 - spike_w) / 2.0,
    // spike_y := (1.0 - spike_h);

    // if tile.subtype & .PRIMARY {
    //   case .U:
    //     return is_point_within_rectf(point, &(Rectf){ spike_x,       0, spike_w, spike_h });
    //   case .D:
    //     return is_point_within_rectf(point, &(Rectf){ spike_x, spike_y, spike_w, spike_h });
    //   case .L:
    //     return is_point_within_rectf(point, &(Rectf){       0, spike_x, spike_h, spike_w });
    //   case .R:
    //     return is_point_within_rectf(point, &(Rectf){ spike_y, spike_x, spike_h, spike_w });
    //   case .NONE:
    //     return is_point_within_rectf(point, &(Rectf){ spike_x, spike_x, spike_w, spike_w });
    
    // // triangular collision for inside corner tiles
    //   case .U | .R:
    //     return (point.y < point.x - 0.25);
    //   case .U | .L:
    //     return (point.y < 0.75 - point.x);
    //   case .D | .R:
    //     return (point.y > 1.25 - point.x);
    //   case .D | .L:
    //     return (point.y > point.x + 0.25);
    // }
}



// returns index at which tile was actually placed, so that we can more easily place tiles procedurally
place_tile :: (using tilemap: *Tilemap, tile: Tile, _coords: Vec2i) -> (coords: Vec2i) {
    coords := _coords;
    
    move_data: Vec2i;
    content_size := get_content_region(tilemap).size;
    new_size     := size;
    
    do_realloc, do_move := false;
    
    if (coords.x < 0) {
        content_size.x = -coords.x + max_index.x + 1;
        margin := size.x - content_size.x;
        do_move = true;
        if (margin < 0) {
            do_realloc = true;
            new_size.x = xx next_power_of_2(xx content_size.x);
            margin = new_size.x - content_size.x;
        }
        move_data.x = (margin / 2) - coords.x;
    }
    else if (coords.x >= size.x) {
        content_size.x = coords.x - min_index.x + 1;
        margin := size.x - content_size.x;
        do_move = true;
        if (margin < 0) {
            do_realloc = true;
            new_size.x = xx next_power_of_2(xx content_size.x);
            margin = new_size.x - content_size.x;
        }
        move_data.x = (margin / 2) - min_index.x;
    }
    if (coords.y < 0) {
        content_size.y = -coords.y + max_index.y + 1;
        margin := size.y - content_size.y;
        do_move = true;
        if (margin < 0) {
            do_realloc = true;
            new_size.y = xx next_power_of_2(xx content_size.y);
            margin = new_size.y - content_size.y;
        }
        move_data.y = (margin / 2) - coords.y;
    }
    else if (coords.y >= size.y) {
        content_size.y = coords.y - min_index.y + 1;
        margin := size.y - content_size.y;
        do_move = true;
        if (margin < 0) {
            do_realloc = true;
            new_size.y = xx next_power_of_2(xx content_size.y);
            margin = new_size.y - content_size.y;
        }
        move_data.y = (margin / 2) - min_index.y;
    }
    
    if do_realloc  resize_tile_layer   (tilemap, new_size.x, new_size.y);
    if do_move     move_tile_layer_data(tilemap,    move_data.x,    move_data.y);
    
    min_index    += move_data;
    max_index    += move_data;
    coords       += move_data;
    root_offset  -= to_Vector2(move_data);
    
    selected_index := coords.x + coords.y * size.x;
    if (selected_index < 0 || selected_index >= size.x * size.y) {
        log("attempted to place tile out of bounds");
    } else {
        data[selected_index] = tile;
        #if EDITOR_ENABLED {
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
    }
    
    min_index = min_of_each(coords, min_index);
    max_index = max_of_each(coords, max_index);
    
    return coords;
}

get_tilemap_offset_from_root :: (tilemap: Tilemap) -> Vec2f {
    return tilemap.offset - tilemap.root_offset;
}
