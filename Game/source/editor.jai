
// TODO: figure out what to do about residual editor stuff that we still need to compile everything else

copy_editor_level_to_active_level :: () {
    active_level := get_active_level();
    
    #if EDITOR_ENABLED {
        clone_level(active_level, *Editor.level);
    } else {
        if !load_level(active_level, default_level_path) {
            // if default level failed to load, then just make a blank level
            
            active_level.bounds = .{ 0, 0, 20*12, 15 };
            array_add(*active_level.tilemaps, .{});
            init_tilemap(*active_level.tilemaps[0]);
            
            {
                active_level.tilemaps[0].root_offset = .{ 0, 13 };
                coord := Vec2i.{ 0, 0 };
                for 0..31 {
                    coord = place_tile(*active_level.tilemaps[0], Tile.{ id = 1 }, coord);
                    coord += .{  0,  1 };
                    coord = place_tile(*active_level.tilemaps[0], Tile.{ id = 1 }, coord);
                    coord += .{  1, -1 };
                }
            }
            active_level.player.position = .{ SCREEN_TILE_WIDTH / 2, SCREEN_TILE_HEIGHT - 3 };
            active_level.player.gravity_angle = 90;
        }
    }
    
    script_path := to_string(*active_level.script_path[0]);
    load_level_script(active_level, script_path);
    
    music_path := to_string(*active_level.music_path[0]);
    if music_path  load_and_play_music(music_path);
    
    prep_level(active_level);
    
    // TODO: set to proper values once we integrate worldmap stuff into editor
    Game.worldmap.active_level = -1;
    Game.worldmap.active_area  = -1;
}

Editor_Input_Keys :: enum {
    UP;
    DOWN;
    LEFT;
    RIGHT;
    CAMERA_DRAG;
    SET_PLAYER_START;
    COPY_SELECTION;
    PASTE_SELECTION;
    
    TOOL_BRUSH;
    TOOL_GRAB;
    
    MODE_TILE_SELECTOR;
    MODE_ENTITY_SELECTOR;
    
    RELOAD_SCRIPT;
    
    SHOW_IPROF;
    
    
    // NOTE: below values moved from Program_Controller
    SET_STATE_GAME;
    SET_STATE_EDITOR;
    
    GAME_RESET_LEVEL;
    TOGGLE_SHOW_DEMO_WINDOW;
    TOGGLE_SHOW_DEBUG_WINDOW;
    RELOAD_ASSETS;
    
    _COUNT;
};

Editor_Controller :: Enumerated_Array(Editor_Input_Keys, Input_Key); 
editor_controller: Editor_Controller;

#if EDITOR_ENABLED {

Editor_Tool :: enum { GRAB; BRUSH; };

Editor_Mode :: enum { EDIT; TILE_SELECTOR; ENTITY_SELECTOR; };

Editor: struct {
    mode: Editor_Mode = .EDIT;
    tool: Editor_Tool = .GRAB;
    
    selected_tilemap:     int;
    
    mouse:                Mouse;
    mouse_tile_position:  Vector2;
    mouse_tile_index:     int;
    
    grab: struct {
        entity_index:   int;
        offset:         Vector2; // position of mouse relative to origin of grabbed element, at time when grab begins
    };
    
    brush: struct {
        type:               Type = Tile;
        tile:               Tile;
        tile_modifier:      Tile_Modifier = xx 1;
        tile_modifier_dir:  Direction;
        entity:             Entity_Union;
    };
    
    selection: struct {
        first:  Vector2;
        second: Vector2;
        active: bool;
        
        clipboard: Tilemap;
    };
    
    timeline: struct {
        start: float = 0;
        end:   float = 30;
    }
    
    level: Level_Layout;
    
    details_panel_subject: Any;
    
    grid_color: Color4 = .{ 0.85, 0.85, 0.85, 0.75 };
    
    tile_selector:   Grid_View;
    entity_selector: Grid_View;
    
    should_recalculate_timeline_points: bool;
    
    autotile_ruleset:   Tilemap;
    autotile_viewport:  Rectf;
    autotile_camera:    Vec2f;
    autotile_tileunit:  float = 32;
    autotile_mouse:     Vec2f;
    
    do_auto_tile:       bool;
    
    // used as context flag  
    in_autotile_ruleset:  bool;
};

init_editor :: () {
    using Editor;
    
    if !load_level(*level, default_level_path) {
        // if default level failed to load, then just make a blank level
        
        level.bounds = .{ 0, 0, 20*12, 15 };
        array_add(*level.tilemaps, .{});
        init_tilemap(*level.tilemaps[0]);
        
        {
            level.tilemaps[0].root_offset = .{ 0, 13 };
            coord := Vec2i.{ 0, 0 };
            for 0..31 {
                coord = place_tile(*level.tilemaps[0], Tile.{ id = 1 }, coord);
                coord += .{  0,  1 };
                coord = place_tile(*level.tilemaps[0], Tile.{ id = 1 }, coord);
                coord += .{  1, -1 };
            }
        }
        level.player.position = .{ SCREEN_TILE_WIDTH / 2, SCREEN_TILE_HEIGHT - 3 };
        level.player.gravity_angle = 90;
    }
    
    script_path := to_string(*level.script_path[0]);
    if script_path  load_level_script(*level, script_path);
    
    tile_selector = .{
        tile_size    = .{ 32, 32 },
        tile_padding = .{ 4, 4 },
        render_immediate = false,
        
        bg_color      = .{ 0, 0, 0, 0.8 },
        outline_color = .{ 0.6, 0.6, 0.6, 1 },
    };
    
    entity_selector = .{
        tile_size    = .{ 32, 32 },
        tile_padding = .{ 4, 4 },
        render_immediate = false,
        
        bg_color      = .{ 0, 0, 0, 0.8 },
        outline_color = .{ 0.6, 0.6, 0.6, 1 },
    };
    
    should_recalculate_timeline_points = true;
    
    if !load_autotile_ruleset() {
        init_tilemap(*autotile_ruleset);
    }
}

reset_editor_selection :: () {
    using Editor;
    selection.first  = .{};
    selection.second = .{};
    selection.active = false;
}

get_editor_selection_rect :: () -> Rectf {
    using Editor;
    top_left     := Vector2.{
        x = min(selection.first.x, selection.second.x),
        y = min(selection.first.y, selection.second.y),
    };
    bottom_right := Vector2.{
        x = max(selection.first.x, selection.second.x),
        y = max(selection.first.y, selection.second.y),
    };
    return .{
        top_left.x, 
        top_left.y,
        bottom_right.x - top_left.x, 
        bottom_right.y - top_left.y,
    };
}

get_editor_selection_rect_tiles :: () -> Rectf {
    using Editor;
    
    top_left     := Vector2.{
        x = floor(min(selection.first.x, selection.second.x)),
        y = floor(min(selection.first.y, selection.second.y)),
    };
    bottom_right := Vector2.{
        x = ceil(max(selection.first.x, selection.second.x)),
        y = ceil(max(selection.first.y, selection.second.y)),
    };
    
    return .{
        top_left.x, 
        top_left.y,
        bottom_right.x - top_left.x, 
        bottom_right.y - top_left.y,
    };
}

copy_selection_data :: () {
    using Editor;
    
    // top_left     := Vec2i.{
    //     x = xx floor(min(selection.first.x, selection.second.x)),
    //     y = xx floor(min(selection.first.y, selection.second.y)),
    // };
    // bottom_right := Vec2i.{
    //     x = xx (ceil(max(selection.first.x, selection.second.x)) - 1.0),
    //     y = xx (ceil(max(selection.first.y, selection.second.y)) - 1.0),
    // };
    
    // x_start := max(top_left.x, 0);
    // x_end   := min(bottom_right.x, level.tilemap.size.x-1);
    
    // y_start := max(top_left.y, 0);
    // y_end   := min(bottom_right.y, level.tilemap.size.y-1);
    
    // selection.clipboard.size = .{ x_end - x_start + 1, y_end - y_start + 1};
    
    // data_tile_count := selection.clipboard.size.x * selection.clipboard.size.y;
    // if data_tile_count > selection.clipboard.data.count {
    //     array_resize(*selection.clipboard.data, data_tile_count);
    // }
    
    // src: int = y_start * level.tilemap.size.x + x_start;
    // dst: int = 0;
    // for y_start..y_end {
    //     memcpy(*selection.clipboard.data[dst], *level.tilemap.data[src], selection.clipboard.size.x * size_of(Tile));
    //     src += level.tilemap.size.x;
    //     dst += selection.clipboard.size.x;
    // }
}

paste_selection_data :: () {
    using Editor;
    
    // if !selection.clipboard.data  return;
    
    // x_start := clamp(cast(s32) mouse_tile_position.x         , 0, level.tilemap.size.x-1);
    // x_end   := clamp(x_start + selection.clipboard.size.x - 1, 0, level.tilemap.size.x-1);
    
    // y_start := clamp(cast(s32) mouse_tile_position.y         , 0, level.tilemap.size.y-1);
    // y_end   := clamp(y_start + selection.clipboard.size.y - 1, 0, level.tilemap.size.y-1);
    
    // dst_size := Vec2i.{ x_end - x_start + 1, y_end - y_start + 1 };
    
    // dst: int = y_start * level.tilemap.size.x + x_start;
    // src: int = 0;
    // for y_start..y_end {
    //     memcpy(*level.tilemap.data[dst], *selection.clipboard.data[src], dst_size.x * size_of(Tile));
    //     dst += level.tilemap.size.x;
    //     src += selection.clipboard.size.x;
    // }
}

clear_tilemap_selection_state :: () {
    for *Editor.level.tilemaps 
        it.flags &= ~.SELECTED_IN_EDITOR;
}

EDITOR_TILE_UNIT: float = 32.0;

editor_update_tilemaps :: (show_imgui := false) {
    using Editor;
    if level.script.flags & .TYPECHECKED {
        set_script_variables(*level);
        for *level.tilemaps {
            update_tilemap_prescript(it);
            it.offset_next   = it.root_offset;
        }
        execute_level_script(*level, show_imgui);
        for *level.tilemaps {
            update_tilemap_postscript(it);
        }
    } else {
        for *level.tilemaps {
            update_tilemap_prescript(it);
            it.offset_next   = it.root_offset;
            update_tilemap_postscript(it);
        }
    }
}

// TODO: if we can't get mouse capture, do we even want to update the editor at all?
update_editor :: () {
    using Editor;
    using Editor_Input_Keys;
    context.current_level = *Editor.level;
    
    
    Input.update_window_events();
    imgui_handle_input_events(Input.events_this_frame);
    process_input_events();
    update_input_controller(editor_controller.data);
    
    // NOTE: editor_controller is updated in the main loop, since we check some globally-relevant keys there
    
    // only update the Editor-local mouse if imgui is not capturing mouse
    if !ImGui.GetIO().WantCaptureMouse {
        update_mouse(*mouse);
    } else {
        mouse.velocity = .{};
    }
    push_mouse(*Editor.mouse);
    
    editor_update_tilemaps(show_imgui = true);
    
    for *level.entities {
        if it.entity_flags & .REMOVE_ME {
            print("removed entity with index %\n", it_index);
            remove;
        }
    }
    
    if !ImGui.GetIO().WantCaptureKeyboard {
        if editor_controller.SET_STATE_GAME.state == .PRESSED {
            play_music();
            Program_State = .GAME;
            return;
        }
        if editor_controller.MODE_TILE_SELECTOR.state == .PRESSED {
            mode = ifx mode != .TILE_SELECTOR then .TILE_SELECTOR else .EDIT;
        }
        if editor_controller.MODE_ENTITY_SELECTOR.state == .PRESSED {
            mode = ifx mode != .ENTITY_SELECTOR then .ENTITY_SELECTOR else .EDIT;
        }
    }
    
    // get mouse position in the game world
    mouse_tile_position = pixel_to_internal_units(
        pixel_position  = mouse_position(), 
        internal_unit   = EDITOR_TILE_UNIT, 
        internal_offset = level.camera, 
    );
    
    keymod := key_modifier_state;
    
    // handle mouse scroll
    if !keymod {
        if brush.type == Tile {
            if mouse_wheel().y {
                brush.tile = Tile.{
                    id = clamp(brush.tile.id.(s32) + mouse_wheel().y, 1, tile_info_lookup.count.(s32)-1).(Tile_ID),
                };
            }
        }
    }
    if keymod == .CTRL {
        EDITOR_TILE_UNIT = clamp(EDITOR_TILE_UNIT + mouse_wheel().y.(float), 8, 64);
    }
    
    do_auto_tile = (keymod & .ALT).(bool);
    
    if mode == {
      case .TILE_SELECTOR;
        tile_selector.position = .{ window_width.(float) / 4, window_height.(float) / 4 };
        tile_selector.size     = .{ window_width.(float) / 2, window_height.(float) / 2 };
        // tile_selector.render_offset = -tile_selector.position;
        
        for tile_selector {
            for tile_info_lookup {
                tri := get_tile_render_info(.{ id = xx it_index });
                clicked, hovered := do_element(.{
                    texture  = *tiles_texture, 
                    clip     = tri.clip, 
                    palette  = tri.palette,
                });
                if clicked {
                    Editor.brush.type = Tile;
                    Editor.brush.tile = .{ id = xx it_index };
                    Editor.tool = .BRUSH;
                    Editor.mode = .EDIT;
                    ignore_left_mouse_button_until_released(*mouse);
                }
            }
        }
        
      case .ENTITY_SELECTOR;
        entity_selector.position = .{ window_width.(float) / 4, window_height.(float) / 4 };
        entity_selector.size     = .{ window_width.(float) / 2, window_height.(float) / 2 };
        // entity_selector.render_offset = -entity_selector.position; 
        
        for entity_selector {
            for enemy_templates {
                clicked, hovered := do_element(.{
                    texture  = *entities_texture, 
                    clip     = rect_to_frect(get_enemy_template_icon_clip(it, 16, 16)),
                    palette  = it.palette,
                });
                if clicked {
                    Editor.brush.type = Entity;
                    init_enemy(*Editor.brush.entity.enemy, xx it_index);
                    Editor.tool = .BRUSH;
                    Editor.mode = .EDIT;
                    ignore_left_mouse_button_until_released(*mouse);
                }
            }
            
            clicked, hovered := do_element(.{
                texture  = *entities_texture, 
                clip     = .{ 192, 0, 16, 16 }, 
                palette  = get_color_animation_index("girders"),
            });
            if clicked {
                Editor.brush.type = Entity;
                init_warp_entity(*Editor.brush.entity.warp);
                Editor.tool = .BRUSH;
                Editor.mode = .EDIT;
            }
        }
        
      case .EDIT;
        if !ImGui.GetIO().WantCaptureKeyboard {
            if editor_controller.TOOL_BRUSH.state == .PRESSED {
                tool = .BRUSH;
                brush.type = Tile;
            }
            if editor_controller.TOOL_GRAB.state == .PRESSED {
                tool = .GRAB;
            }
            if editor_controller.RELOAD_SCRIPT.state & .PRESSED {
                if load_level_script(*level, to_string(level.script_path.data)) {
                } else {
                    log("Error: failed to load script '%' for level '%'.", level.script_path, level.name);
                }
            }
            if editor_controller.SET_PLAYER_START.state & .PRESSED {
                level.player.position = .{
                    snap_to_nearest_unit(mouse_tile_position.x, 0.5),
                    snap_to_nearest_unit(mouse_tile_position.y, 0.5),
                };
            }
            
            
            CAMERA_MOVE_SPEED := 100.0 / updates_per_second;
            if editor_controller.UP.state & .PRESSED {
                level.camera.y -= CAMERA_MOVE_SPEED;
            }
            if editor_controller.DOWN.state & .PRESSED {
                level.camera.y += CAMERA_MOVE_SPEED;
            }
            if editor_controller.LEFT.state & .PRESSED {
                level.camera.x -= CAMERA_MOVE_SPEED;
            }
            if editor_controller.RIGHT.state & .PRESSED {
                level.camera.x += CAMERA_MOVE_SPEED;
            }
            if editor_controller.CAMERA_DRAG.state & .DOWN {
                mouse_tile_velocity := pixel_to_internal_units(
                    pixel_position  = mouse_velocity(), 
                    internal_unit   = EDITOR_TILE_UNIT, 
                );
                level.camera -= mouse_tile_velocity;
            }
        }
        
        if tool == {
          case .GRAB;
            // activate rectangle select
            // if mouse.left == .PRESSED {
            //     if key_modifier_state & .SHIFT {
            //         selection.active = true;
            //     } else {
            //         reset_editor_selection();
            //     }
            // }
            
            inline do_level_bounds_handles();
            inline do_entity_handles();
            inline do_tilemap_handles();
            
          case .BRUSH;
            if selection.active {
                if mouse_left() == {
                  case .PRESSED;
                    selection.first  = mouse_tile_position;
                    #through;
                  case .DOWN;
                    selection.second = mouse_tile_position;
                  case;
                    selection.active = false;
                }
            } else {
                if brush.type == {
                  case Tile;
                    if selected_tilemap >= 0 && selected_tilemap < level.tilemaps.count {
                        edit_tilemap(*level.tilemaps[selected_tilemap], mouse_tile_position);
                    }
                    
                  case Entity;
                    if mouse_left() == .PRESSED {
                        slot := get_next_empty_slot(*level.entities);
                        if slot != null {
                            slot.occupied = true;
                            slot.data = brush.entity;
                            slot.base.position = snap_to_nearest_unit(mouse_tile_position, 0.5);
                        }
                    }
                    if mouse_middle() == .PRESSED {
                        for *level.entities {
                            if is_point_within_frect(mouse_tile_position, get_collision_rect(it)) {
                                brush.entity = it.*;
                                brush.entity.base.position = .{};
                            }
                        }
                    }
                    if mouse_right() & .PRESSED {
                        for *level.entities {
                            if is_point_within_frect(mouse_tile_position, get_collision_rect(it)) {
                                deinit_entity(it);
                                remove it;
                            }
                        }
                    }
                }
            }
        }
        
        
        // if !ImGui.GetIO().WantCaptureKeyboard {
            // if selection.first != selection.second 
            // && editor_controller.COPY_SELECTION.state == .PRESSED {
            //     copy_selection_data();
            //     reset_editor_selection();
            // }
            
            // if editor_controller.PASTE_SELECTION.state == .PRESSED {
            //     paste_selection_data();
            // }
        // }
    }
    
    
    { // IMGUI section
        using imgui;
        
        if Begin("Editor Details") {
            SeparatorText("Level Details");
            InputText("level name",               level.name);
            InputText("level script source path", level.script_path);
            InputText("level music path",         level.music_path);
            ColorEdit4("bg color", (*level.bg_color).(*[4]float));
            
            InputFloat4("level bounds", xx *level.bounds);
            
            SeparatorText("Timeline");
            // SameLine();
            should_recalculate_timeline_points |= InputFloat("start", *timeline.start);
            should_recalculate_timeline_points |= InputFloat("end", *timeline.end);
            SliderFloat("time", *level.time_since_start, timeline.start, timeline.end);
            
            
            // TODO: should probably set the entity slot here instead of the entity itself, so that we dont have to do the wonky pointer cast
            if details_panel_subject.type == {
              case type_info(Slot(Entity_Union));
                SeparatorText("Entity Details");
                
                slot   := details_panel_subject.value_pointer.(*Slot(Entity_Union));
                entity := *slot.data;
                Text("Entity Index: %", (xx entity - level.entities.slots.data).(int));
                if Button("Remove") {
                    deinit_entity(entity);
                    slot.* = .{};
                }
                
                edit_entity_details(entity);
                
                
              case type_info(Tile);
                tile := details_panel_subject.value_pointer.(*Tile);
                info := get_tile_info(tile);
                
                SeparatorText("Tile Details");
                InputScalar("id",     *tile.id);
                InputScalar("serial", *tile.serial);
                
                if info.collision.flags & .CONTAINER {
                    CheckboxFlags("release all items at once", (*tile.flags).(*u32), xx Tile_Flags.RELEASE_ALL_AT_ONCE);
                    entities_in_tile := get_entities_in_tile(*level, tile.serial, sort = true);
                    for entities_in_tile {
                        id := tprintc("[%]", it_index);
                        PushID(id);
                        if Button("x")  it.entity_flags |= .REMOVE_ME;
                        SameLine();
                        // TreeNodeAny(id, it.(*Enemy).*);
                        // TODO: create a better imgui menu for editting entity which allows changing the entity type and such
                        edit_entity_details(xx it);
                        PopID();
                    }
                    if Button("Add Entity") {
                        if !tile.serial then tile.serial = get_tile_serial();
                        
                        slot := get_next_empty_slot(*level.entities);
                        if slot != null {
                            slot.occupied = true;
                            init_enemy(*slot.data.enemy, 0);
                            slot.entity_flags |= .IN_BLOCK;
                            slot.in_block = .{ 
                                tile_serial = tile.serial,
                                sort_order  = xx entities_in_tile.count
                            };
                            print("added enemy % to tile", slot.data.enemy);
                        }
                    }
                }
            }
            
            TreeNodeAny("Editor State", Editor);
        }
        End();
        
        if Begin("Tilemaps") {
            if Button("Add Tilemap") {
                tilemap := array_add(*level.tilemaps);
                init_tilemap(tilemap);
                if level.tilemaps.count > 1 {
                    tilemap.z_index = level.tilemaps[level.tilemaps.count-2].z_index + 1;
                }
            }
            tilemaps_sorted := get_tilemaps_sorted(level.tilemaps);
            for tilemaps_sorted {
                actual_index := it - level.tilemaps.data;
                PushID(tprintc("tl%", it_index));
                if Button("edit") {
                    selected_tilemap = actual_index;
                    tool = .BRUSH;
                }
                SameLine();
                if Button("-") && it_index != 0 {
                    prev := tilemaps_sorted[it_index-1];
                    it.z_index, prev.z_index = prev.z_index, it.z_index;
                }
                SameLine();
                if Button("+") && it_index < tilemaps_sorted.count-1 {
                    next := tilemaps_sorted[it_index+1];
                    it.z_index, next.z_index = next.z_index, it.z_index;
                }
                SameLine();
                if CollapsingHeader(tprintc("%###tl%", to_string(*it.name[0]), it_index)) {
                    InputText("name", it.name);
                    CheckboxFlags("hide", (*it.flags).(*u32), xx Tilemap.Flags.HIDDEN_IN_EDITOR);
                    Text("size: %", it.size);
                    Text("capacity: %", it.capacity);
                    Text("min_index: %", it.min_index);
                    Text("max_index: %", it.max_index);
                    Text("root_offset: %", it.root_offset);
                    Text("anchor_point: %", it.anchor_point);
                    // Text("base_rotation: %", it.base_rotation);
                    // Text("scale: %", it.scale);
                    // Text("skew: %", it.skew);
                    if Button("remove") {
                        array_unordered_remove_by_index(*level.tilemaps, actual_index);
                    }
                    
                    // SliderFloat("Skew X", *it.skew.x, -45, 45);
                    // SliderFloat("Skew Y", *it.skew.y, -45, 45);
                }
                PopID();
            }
        }
        End();
        
        if Begin("Auto-Tile Ruleset") {
            view_min    := GetWindowContentRegionMin();
            view_max    := GetWindowContentRegionMax();
            view_offset := GetWindowPos();
            
            autotile_viewport.position = view_offset + view_min;
            autotile_viewport.size = .{ max(view_max.x - view_min.x, 0), max(view_max.y - view_min.y, 0) };
            
            if autotile_viewport.size.x > 0 
            && autotile_viewport.size.y > 0 {
                InvisibleButton("canvas", autotile_viewport.size, .MouseButtonLeft | .MouseButtonRight);
            }
            is_hovered := IsItemHovered();
            
            if is_hovered {
                push_mouse(*global_mouse);
                defer_restore(*tool);
                defer_restore(*selected_tilemap);
                defer_restore(*mouse_tile_position);
                
                in_autotile_ruleset = true;
                defer in_autotile_ruleset = false;
                
                tool = .BRUSH;
                
                autotile_mouse = pixel_to_internal_units(
                    pixel_position  = mouse_position(), 
                    pixel_offset    = to_Vec2i(autotile_viewport.position),
                    internal_unit   = autotile_tileunit, 
                    internal_offset = autotile_camera, 
                );
                
                mouse_tile_position = autotile_mouse;
                
                CAMERA_MOVE_SPEED := 10.0 / updates_per_second;
                
                if editor_controller.UP.state & .PRESSED {
                    autotile_camera.y -= CAMERA_MOVE_SPEED;
                }
                if editor_controller.DOWN.state & .PRESSED {
                    autotile_camera.y += CAMERA_MOVE_SPEED;
                }
                if editor_controller.LEFT.state & .PRESSED {
                    autotile_camera.x -= CAMERA_MOVE_SPEED;
                }
                if editor_controller.RIGHT.state & .PRESSED {
                    autotile_camera.x += CAMERA_MOVE_SPEED;
                }
                
                if editor_controller.CAMERA_DRAG.state & .DOWN {
                    mouse_tile_velocity := pixel_to_internal_units(
                        pixel_position  = mouse_velocity(), 
                        internal_unit   = EDITOR_TILE_UNIT, 
                    );
                    autotile_camera -= mouse_tile_velocity;
                }
                
                update_tilemap_prescript(*autotile_ruleset);
                autotile_ruleset.offset_next = autotile_ruleset.root_offset;
                update_tilemap_postscript(*autotile_ruleset);
                
                edit_tilemap(*autotile_ruleset, autotile_mouse);
                
                // update again after editting in case tile is placed, since this tilemap won't get updated in editor_update_tilemaps
                // TODO: maybe we can do something more minimal than editor_update_tilemaps when a tilemap is editted, 
                //       since only the one tilemap that's editted will need to be updated, 
                //       and only the offset really needs to be refreshed.
                //       although, updating the offset will require running the script, so...
                update_tilemap_prescript(*autotile_ruleset);
                autotile_ruleset.offset_next = autotile_ruleset.root_offset;
                update_tilemap_postscript(*autotile_ruleset);
            }
            
            draw_callback :ImDrawCallback: (parent_list: *ImDrawList, cmd: *ImDrawCmd) #c_call  {
                new_context: #Context;
                push_context new_context {
                    using Editor;
                    backup_gl_state();
                    
                    in_autotile_ruleset = true;
                    defer in_autotile_ruleset = false;
                    
                    viewport := frect_to_rect(Editor.autotile_viewport);
                    
                    autotile_viewport.position = .{0,0};
                    
                    render_begin_batch();
                    render_set_viewport(*viewport);
                    
                    it := *autotile_ruleset;
                    render_offset := (it.offset - autotile_camera) * autotile_tileunit;
                    translate(*Renderer.transform, .{ xy = render_offset });
                    
                    render_alpha: float = 1;
                    
                    render_tilemap(it, autotile_tileunit, alpha = render_alpha);
                    
                    // definitely skip rendering any guides if layer contains no data
                    // EXCEPT we will actually need to render tile preview in world space
                    
                    tilemap_has_data := it.data && it.size.x > 0 && it.size.y > 0;
                    
                    do_render_outlines     := tilemap_has_data; // also includes anchor atm
                    do_render_gridlines    := false;
                    do_render_tile_preview := false;
                    
                    // if tool == .BRUSH && brush.type == Tile {
                        do_render_tile_preview = true;
                        do_render_gridlines    = tilemap_has_data;
                    // }
                    
                    anchor_offset := -it.anchor_point * autotile_tileunit;
                    
                    if do_render_gridlines {
                        render_grid(
                            tile_size = .{ autotile_tileunit, autotile_tileunit }, 
                            dst_rect  = .{ 
                                position = anchor_offset,
                                size     = to_Vector2(it.capacity) * autotile_tileunit,
                            },
                            tile_offset = floor(anchor_offset),
                            color = grid_color
                        );
                    }
                    
                    if do_render_tile_preview {
                        // maybe we should also render a little grid around tile too?
                        // and maybe that solves the case of empty tile layers
                        mouse_position_in_tilemap := get_position_in_tilemap(it, autotile_mouse);
                        
                        // determine the coordinates at which to place tile
                        // if the tilemap is currently empty, then the tile will be placed in the center of the layer
                        tile_rect := Rectf.{
                            position = anchor_offset + floor(mouse_position_in_tilemap) * autotile_tileunit,
                            size     = to_Vec2f(autotile_tileunit),
                        };
                        
                        // if shift held, render tile mod instead
                        if key_modifier_state & .SHIFT {
                            render_tile_modifier(brush.tile_modifier, brush.tile_modifier_dir, tile_rect);
                        } else {
                            tri := get_tile_render_info(brush.tile);
                            tri.color_mod.a *= 0.5;
                            render_draw_quad(
                                texture  = tri.texture,
                                color    = tri.color_mod,
                                position = .{ tile_rect.x, tile_rect.y },
                                size     = .{ tile_rect.w, tile_rect.h },
                                clip     = *tri.clip,
                                palette  = tri.palette, // TODO: load palette from file
                            );
                        }
                    }
                    
                    if do_render_outlines {
                        opacity := 1.0;
                        
                        // draw capacity outline
                        cap_rect := Rectf.{
                            position = anchor_offset,
                            size     = to_Vector2(it.capacity) * autotile_tileunit
                        };
                        render_draw_rect(cap_rect, color = .{ 1, 0, 0, opacity } );
                        
                        // draw size outline
                        size_rect := Rectf.{
                            position = anchor_offset + to_Vector2(it.min_index) * autotile_tileunit,
                            size     = to_Vector2(it.size) * autotile_tileunit
                        };
                        render_draw_rect(size_rect, color = .{ 0, 1, 0, opacity } );
                        
                        // draw root offset / anchor point
                        anchor_point_rect := Rectf.{
                            position = it.root_offset - it.offset + .{ -1, -1 },
                            size     = .{  3,  3 }
                        };
                        render_draw_rect(anchor_point_rect, color = .{ 0, 0, 1, opacity } );
                    }
                    
                    render_end_batch();
                    render_flush();
                }
            };
            
            draw_list := GetWindowDrawList();
            draw_list.AddCallback(draw_list, draw_callback, null);
        }
        End();
        
    
    } // END IMGUI
    
    // don't even bother if there's no level script loaded
    should_recalculate_timeline_points &&= (level.script.flags & .TYPECHECKED).(bool);
    if should_recalculate_timeline_points {
        should_recalculate_timeline_points = false;
        
        // update all tilemaps twice more after restoring time_since_start
        defer for 0..1 editor_update_tilemaps();
        defer_restore(*level.time_since_start);
        
        timespan := Editor.timeline.end - Editor.timeline.start;
        
        trail_count := type_info(type_of(Tilemap.editor_trail_points)).array_count;
        for it_point: 0..trail_count-1 {
            delta_t := timespan * it_point.(float) / trail_count.(float);
            level.time_since_start = Editor.timeline.start + delta_t;
            editor_update_tilemaps();
            for *level.tilemaps {
                it.editor_trail_points[it_point] = it.offset_next;
            }
        }
    }
}

render_editor :: () {
    using Editor;
    
    update_tile_animations();
    
    render_begin_batch();
    
    // draw level bounds
    render_draw_quad(
        position = (level.bounds.position - level.camera) * EDITOR_TILE_UNIT, 
        size     = level.bounds.size * EDITOR_TILE_UNIT, 
        color    = level.bg_color
    );
    
    // render main grid, gets dimmer when editting a tilemap, since we will also be rendering that tilemap's local-space gridlines
    main_grid_color := grid_color;
    if selected_tilemap >= 0 {
        main_grid_color *= .{ 1, 1, 1, 0.25 };
    }
    render_grid(
        dst_rect    = .{ 0, 0, window_width.(float), window_height.(float) },
        tile_size   = .{ EDITOR_TILE_UNIT, EDITOR_TILE_UNIT }, 
        tile_offset = level.camera * EDITOR_TILE_UNIT,
        color       = main_grid_color
    );
    
    render_end_batch();
    render_flush();
    
    tilemaps_sorted := get_tilemaps_sorted(level.tilemaps);
    for tilemaps_sorted {
        actual_index := it - level.tilemaps.data;
        is_selected_tilemap := (actual_index == selected_tilemap);
        
        render_begin_batch();
        
        render_alpha: float = 1;
        if it.flags & .HIDDEN_IN_EDITOR {
            render_alpha = 0.1;
        } else if tool == .BRUSH && brush.type == Tile && selected_tilemap >= 0 && !is_selected_tilemap {
            render_alpha = 0.5;
        }
        
        render_offset := (it.offset - level.camera) * EDITOR_TILE_UNIT;
        render_tilemap(it, EDITOR_TILE_UNIT, alpha = render_alpha, offset = render_offset);
        
        // definitely skip rendering any guides if layer contains no data
        // EXCEPT we will actually need to render tile preview in world space
        
        tilemap_has_data := it.data && it.size.x > 0 && it.size.y > 0;
        
        do_render_outlines     := tilemap_has_data; // also includes anchor atm
        do_render_gridlines    := false;
        do_render_tile_preview := false;
        
        if tool == .BRUSH && brush.type == Tile && is_selected_tilemap {
            do_render_tile_preview = true;
            do_render_gridlines    = tilemap_has_data;
        }
        
        anchor_offset := (it.offset-it.anchor_point-level.camera) * EDITOR_TILE_UNIT;
        
        if do_render_gridlines {
            render_grid(
                tile_size = .{ EDITOR_TILE_UNIT, EDITOR_TILE_UNIT }, 
                dst_rect  = .{ 
                    position = anchor_offset,
                    size     = to_Vector2(it.capacity) * EDITOR_TILE_UNIT,
                },
                tile_offset = floor(anchor_offset),
                color = grid_color
            );
        }
        
        if do_render_tile_preview {
            // maybe we should also render a little grid around tile too?
            // and maybe that solves the case of empty tile layers
            mouse_position_in_tilemap := get_position_in_tilemap(it, mouse_tile_position);
            
            // determine the coordinates at which to place tile
            // if the tilemap is currently empty, then the tile will be placed in the center of the layer
            tile_rect := Rectf.{
                position = anchor_offset + floor(mouse_position_in_tilemap) * EDITOR_TILE_UNIT,
                size     = to_Vec2f(EDITOR_TILE_UNIT),
            };
            
            // if shift held, render tile mod instead
            if key_modifier_state & .SHIFT {
                render_tile_modifier(brush.tile_modifier, brush.tile_modifier_dir, tile_rect);
            } else {
                tri := get_tile_render_info(brush.tile);
                tri.color_mod.a *= 0.5;
                render_draw_quad(
                    texture  = tri.texture,
                    color    = tri.color_mod,
                    position = .{ tile_rect.x, tile_rect.y },
                    size     = .{ tile_rect.w, tile_rect.h },
                    clip     = *tri.clip,
                    palette  = tri.palette, // TODO: load palette from file
                );
            }
        }
        
        if do_render_outlines {
            opacity := 0.2;
            if tool == {
              case .GRAB;
                if      it.flags & .SELECTED_IN_EDITOR then opacity = 1.0;
                else if it.flags &  .HOVERED_IN_EDITOR then opacity = 0.6;
                
              case .BRUSH;
                if is_selected_tilemap then opacity = 1.0;
            }
            
            // draw capacity outline
            cap_rect := Rectf.{
                position = anchor_offset,
                size     = to_Vector2(it.capacity) * EDITOR_TILE_UNIT
            };
            render_draw_rect(cap_rect, color = .{ 1, 0, 0, opacity } );
            
            // draw size outline
            size_rect := Rectf.{
                position = anchor_offset + to_Vector2(it.min_index) * EDITOR_TILE_UNIT,
                size     = to_Vector2(it.size) * EDITOR_TILE_UNIT
            };
            render_draw_rect(size_rect, color = .{ 0, 1, 0, opacity } );
            
            // draw root offset / anchor point
            anchor_point_rect := Rectf.{
                position = it.root_offset - it.offset + .{ -1, -1 },
                size     = .{  3,  3 }
            };
            render_draw_rect(anchor_point_rect, color = .{ 0, 0, 1, opacity } );
        }
        
        render_end_batch();
        render_flush();
    }
    
    render_begin_batch();
    
    // have to do this after main tilemap rendering since this needs to be in global space
    trail_count := type_info(type_of(Tilemap.editor_trail_points)).array_count;
    for tilemaps_sorted {
        render_draw_lines(..it.editor_trail_points, .{0,0,1,1}, 2, -level.camera, EDITOR_TILE_UNIT);
        // for it.editor_trail_points {
        //     render_draw_rect(.{
        //             position = it - level.camera - .{ 0.1, 0.1 },
        //             size = .{ 0.3, 0.3 }
        //         } * EDITOR_TILE_UNIT,
        //         color = lerp(Color4.{0,0,1,1}, .{1,0,0,1}, it_index.(float) / trail_count.(float))
        //     );
        // }
    }
    
    if mode == .EDIT && tool == .BRUSH {
        if brush.type == {
          case Tile;
          case Entity;
            render_position := snap_to_nearest_unit(mouse_tile_position, 0.5) - level.camera;
            render_entity(*brush.entity, EDITOR_TILE_UNIT, render_position, 0.5);
        }
    }
    
    render_player(*Editor.level.player, EDITOR_TILE_UNIT, -level.camera);
    
    for *level.entities {
        render_entity(it, EDITOR_TILE_UNIT, -level.camera);
    }
    
    // if tool == .GRAB && grab.state != .NONE && grab.type == .ENTITY {
    //     held_entity := *level.entities.slots[grab.entity_index];
    
    //     outline_color := Color4.{0.5, 1, 0.5, 0.5};
    //     if grab.state == .HELD {
    //         outline_color = .{1, 0.5, 0.5, 0.5};
    //     }
    
    //     render_rect := get_collision_rect(held_entity);
    //     render_rect.position -= level.camera;
    //     render_rect *= EDITOR_TILE_UNIT;
    //     render_draw_rect(render_rect, outline_color, 3);
    // }
    
    // TODO: reimplement selection, copy/paste
    // if selection.first != selection.second {
    //     rect := get_editor_selection_rect_tiles();
    //     render_draw_quad(
    //         texture       = null,
    //         color         = .{ 1, 1, 0, 1.0/8.0 },
    //         position      = (rect.position - level.camera) * EDITOR_TILE_UNIT,
    //         size          = rect.size * EDITOR_TILE_UNIT,
    //     );
    // }
    
    render_ui_state();
    
    for tile_selector.render_commands  exec_render_command(it);
    array_reset(*tile_selector.render_commands);
    for entity_selector.render_commands  exec_render_command(it);
    array_reset(*entity_selector.render_commands);
    
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

// TODO: probably also parameterize brush as well, reduce reliance on using some editor state directly 
edit_tilemap :: (tilemap: *Tilemap, mouse_tile_position: Vec2f) {
    mouse_position_in_tilemap := get_position_in_tilemap(tilemap.*, mouse_tile_position);
    
    tile_hovered := get_tile(tilemap, to_Vec2i(mouse_position_in_tilemap));
    
    // determine the coordinates at which to place tile
    // if the tilemap is currently empty, then the tile will be placed in the center of the layer
    tile_coords: Vec2i;
    if (tilemap.size.x == 0 || tilemap.size.y == 0) { // it should never be possible that one is zero while the other is not
        tile_coords.x         = tilemap.capacity.x / 2;
        tile_coords.y         = tilemap.capacity.y / 2;
        tilemap.root_offset.x = floor(mouse_tile_position.x);
        tilemap.root_offset.y = floor(mouse_tile_position.y);
        tilemap.anchor_point  = to_Vector2(tile_coords);
    } else {
        tile_coords.x = floor(mouse_position_in_tilemap.x).(s32);
        tile_coords.y = floor(mouse_position_in_tilemap.y).(s32);
    }
    
    keymod := key_modifier_state;
    
    if !(keymod & .CTRL) {
        if (mouse_left() & .PRESSED) && Editor.brush.tile.id != 0 {
            place_tile(tilemap, Editor.brush.tile, tile_coords);
            // NOTE: need to do this to update transform before rendering
            //       potentially wasteful, but can't think of a better way to prevent the weird tile placement bug that otherwise occurs
            editor_update_tilemaps();
        }
        if (mouse_right() & .PRESSED) && (tilemap.size.x > 0 && tilemap.size.y > 0) {
            editor_remove_tile(tilemap, tile_coords);
        }
    }
    
    // shift engages tile modifier brush
    if keymod & .SHIFT {
        if (mouse_left() & .PRESSED) && Editor.brush.tile.id != 0 {
            if tile_hovered  set_tile_modifier(tile_hovered, Editor.brush.tile_modifier_dir, Editor.brush.tile_modifier);
        }
        if (mouse_right() & .PRESSED) && (tilemap.size.x > 0 && tilemap.size.y > 0) {
            if tile_hovered  set_tile_modifier(tile_hovered, Editor.brush.tile_modifier_dir, .NONE);
        }
        
        // shift + ctrl + scroll changes modifier type
        if keymod & .CTRL {
            if mouse_wheel().y {
                // in order to prevent .NONE being in the rotation, subtract 1 before doing modulo, then add it back afterwards
                Editor.brush.tile_modifier = modulo(Editor.brush.tile_modifier.(s32) - 1 + mouse_wheel().y, Tile_Modifier._COUNT.(s32)).(Tile_Modifier) + 1;
            }
        }
        // shift + scroll changes modifier direction
        else {
            if mouse_wheel().y {
                Editor.brush.tile_modifier_dir = ((Editor.brush.tile_modifier_dir.(s32) + mouse_wheel().y) & 0b11).(Direction);
            }
        }
    }
    
    if keymod == .CTRL {
        if mouse_left() == .PRESSED {
            Editor.details_panel_subject = tile_hovered.*;
        }
    }
    
    // ALT + middle click = set tile layer rotation point
    if mouse_middle() == .PRESSED && keymod == .ALT {
        anchor_point_prev    := tilemap.anchor_point;
        tilemap.anchor_point  = snap_to_nearest_unit(mouse_position_in_tilemap, 0.5);
        
        anchor_point_move    := tilemap.anchor_point - anchor_point_prev;
        // anchor_point_move     = rotate_degrees(anchor_point_move, tilemap.rotation);
        tilemap.root_offset   = snap_to_nearest_unit(tilemap.root_offset + anchor_point_move, 0.5);
    }
    
    // tilemap scaling
    // if keymod == (.CTRL | .ALT) {
    //     tilemap.scale.x = clamp(tilemap.scale.x + cast(float) mouse.wheel.x * 0.1, 0.5, 5.0);
        
    //     tilemap.scale.x = clamp(tilemap.scale.x + cast(float) mouse.wheel.y * 0.1, 0.5, 5.0);
    //     tilemap.scale.y = clamp(tilemap.scale.y + cast(float) mouse.wheel.y * 0.1, 0.5, 5.0);
    // }
    
    // if keymod == .ALT {
    //     tilemap.base_rotation += mouse_wheel().y;
    // }
}


do_level_bounds_handles :: () {
    using Editor;
    
    begin_id(*ui_state.current, .{ Level_Layout, 0 }); // may need some better approach here for such ids
    defer end_id(*ui_state.current);
    
    // TODO: for these really simple handles, we should just have a proc to call instead of a macro
    for handle: UI_Handle.{
        id              = "bounds_position", 
        offset          = level.bounds.position, 
        size            = .{ 1, 1 },
        want_focus_held = .L | .R,
        flags           = .POSITION_ABSOLUTE,
        texture         = *ui_elements_texture,
        clip            = *ui_texture_clip_position_2d,
    } {
        using handle;
        if focus_held == {
          case .L;
            if mouse_velocity() != .{} {
                new_position := snap_to_nearest_unit(Editor.mouse_tile_position, 0.5);
                move := new_position - level.bounds.position;
                level.bounds.position = new_position;
                level.bounds.size -= move;
                update_offset(handle, level.bounds.position);
            }
        }
        
        // done inside position handle so that we get relative positioning 
        for handle: UI_Handle.{
            id              = "bounds_size", 
            offset          = level.bounds.size, 
            size            = .{ 1, 1 },
            want_focus_held = .L | .R,
            texture         = *ui_elements_texture,
            clip            = *ui_texture_clip_position_2d,
        } {
            using handle;
            if focus_held == {
              case .L;
                if mouse_velocity() != .{} {
                    level.bounds.size = Editor.mouse_tile_position - level.bounds.position;
                    level.bounds.size = snap_to_nearest_unit(level.bounds.size, 0.5);
                }
            }
        }
    }
    
    if level.bounds.w < 1  level.bounds.w = 1;
    if level.bounds.h < 1  level.bounds.h = 1;
}


edit_entity_details :: (entity: *Entity_Union) {
    using ImGui;
    
    if ComboEnum("entity type", *entity.entity_type) {
        in_block_data := entity.in_block;
        
        // reinit entity for given type
        if #complete entity.entity_type == {
          case .ENEMY;    init_enemy      (*entity.enemy, 0);
          case .WARP;     init_warp_entity(*entity.warp);
            
          case .PLAYER;
            // this should actually not be allowed, since player is not in the Entity_Union
            entity.entity_type = .NONE;
            #through;
            
          case .NONE;
            entity.* = .{ base = entity.base }; // zero-out anything not part of base entity
        }
        
        entity.entity_flags |= .IN_BLOCK;
        entity.in_block = in_block_data;
    }
    
    InputScalar("in_block.multi_entity: ", *entity.in_block.multi_entity);
    
    // switch on entity type and allow individually editting all relevant attributes
    // for first version can just use treenodeany to start, I guess
    if #complete entity.entity_type == {
      case .NONE;
      
      case .ENEMY;
        enemy := entity.(*Enemy);
        
        template_index := enemy.template_index;
        if InputScalar("template index: ", *template_index) {
            template_index = clamp(template_index, 0, (enemy_templates.count-1).(s32));
            if template_index != enemy.template_index {
                in_block_data := enemy.in_block;
                init_enemy(enemy, template_index);
                enemy.entity_flags |= .IN_BLOCK;
                enemy.in_block = in_block_data;
            }
        }
        template := enemy_templates[enemy.template_index];
        
        // CheckboxFlags("winged", (*enemy.flags).(*u32), xx Enemy_Flags.WINGED); // TODO: causing crash when anim is not present
        ComboEnum("walk direction", *enemy.walk_direction, .L, .R); // TODO: only show certain enum values, should provide values as param
        
        // TODO: probably change editable properties based on entity template
        
      case .WARP;
        warp := entity.(*Warp);
        InputScalar("warp id", *warp.local_id);
        ComboEnum("warp type", *warp.warp_type);
        ComboEnum("warp form", *warp.warp_form);
        
        // TODO: flags
        // CheckboxFlags("exit only", xx *warp.warp_flags, xx Warp_Flags.EXIT_ONLY);
        // TODO: button to travel to linked warp
        
        InputScalar("dst local id", *warp.dst_locator.local_id);
        InputText("dst level name", warp.dst_locator.level_name);
        InputText("dst area name",  warp.dst_locator.area_name);
        
      case .PLAYER;
        TreeNodeAny("PLAYER", entity.(*Player).*);
    }
}


do_entity_handles :: () {
    using Editor;
    for *entity, entity_index: level.entities {
        if entity.entity_flags & .IN_BLOCK  continue;
    
        begin_id(*ui_state.current, .{ Entity, entity_index });
        defer end_id(*ui_state.current);
        
        for handle: UI_Handle.{
            id              = "position", 
            offset          = entity.position, 
            size            = .{1,1},
            thickness       = 2,
            want_focus_held = .L | .R,
            flags           = .POSITION_ABSOLUTE
        } {
            using handle;
            if focus_held == {
              case .L;
                if key_modifier_state & .CTRL {
                    details_panel_subject = entity.*;
                } else {
                    if mouse.velocity != .{} {
                        entity.position = Editor.mouse_tile_position;
                        entity.position = snap_to_nearest_unit(entity.position, 0.5);
                    }
                }
            }
            if active_state != .UNFOCUSED {
                if entity.entity_type == {
                }
            }
        }
    }
}

do_tilemap_handles :: () {
    using Editor;
    for *tilemap, tilemap_index: level.tilemaps {
        // tilemap.flags &= ~(.HOVERED_IN_EDITOR | .SELECTED_IN_EDITOR);
        
        begin_id(*ui_state.current, .{ Tilemap, tilemap_index });
        defer end_id(*ui_state.current);
        
        // TODO: so far these feels kinda nice. 
        // maybe such a macro is not really required, but I think I like It
        for handle: UI_Handle.{
            id              = "root_offset", 
            offset          = tilemap.root_offset, 
            size            = .{1,1},
            want_focus_held = .L | .R,
            flags           = .POSITION_ABSOLUTE,
            texture         = *ui_elements_texture,
            clip            = *ui_texture_clip_position_2d,
        } {
            using handle;
            if focus_held == {
              case .L;
                if mouse.velocity != .{} {
                    tilemap.root_offset = Editor.mouse_tile_position;
                    tilemap.root_offset = snap_to_nearest_unit(tilemap.root_offset, 0.5);
                    should_recalculate_timeline_points = true;
                }
              case .R;
                if mouse.velocity != .{} {
                    tilemap.anchor_point += to_Vec2f(mouse.velocity) / EDITOR_TILE_UNIT;
                }
                // if mouse.right == .RELEASED
                //     tilemap.anchor_point = snap_to_nearest_unit(tilemap.anchor_point, snap);
            }
            if hovered {
                // TODO: set hovered in editor flag, update rendering to auto hide the other tilemaps like we do when editting a tilemap
                // tilemap.flags |= .HOVERED_IN_EDITOR;
            }
            if active_state != .UNFOCUSED {
                // tilemap.flags |= .SELECTED_IN_EDITOR;
                // TODO: add some way for this handle to draw a line back to parent
                //       would like for this to be a dotted line as well.
                // rotation_handle("base_rotation", *tilemap.base_rotation, size = .{1,1});
            }
        }
    }
}

load_autotile_ruleset :: () -> bool {
    filename :: "autotile_ruleset";
    
    // tmd is short for 'tilemap data', I suppose
    FILE_PATH_FORMAT_STRING           :: "data/%.tmd";
    FILE_TYPE_INFO_PATH_FORMAT_STRING :: "data/%.tmdti";
    
    file_path           := tprint(LEVEL_PATH_FORMAT_STRING,           filename);
    type_info_file_path := tprint(LEVEL_TYPE_INFO_PATH_FORMAT_STRING, filename);
    
    info_file, ok := read_entire_file(type_info_file_path);
    if !ok {
        log("Info: failed to load autotile ruleset. failed to read type info file");
        return false;
    }
    defer free(info_file);
    
    info := Data_Packer.unpack_type_info_with_header(xx info_file, xx *Type_Info);
    if !info {
        log("Info: failed to load autotile ruleset. failed to unpack type info");
        return false;
    }
    
    if !Data_Packer.unpack_file_with_type_info(file_path, info, Editor.autotile_ruleset) {
        log("Info: failed to load autotile ruleset.");
        return false;
    }
    
    return true;
}

save_autotile_ruleset :: () -> bool {
    filename :: "autotile_ruleset";
    
    // tmd is short for 'tilemap data', I suppose
    FILE_PATH_FORMAT_STRING           :: "data/%.tmd";
    FILE_TYPE_INFO_PATH_FORMAT_STRING :: "data/%.tmdti";
    
    file_path           := tprint(LEVEL_PATH_FORMAT_STRING,           filename);
    type_info_file_path := tprint(LEVEL_TYPE_INFO_PATH_FORMAT_STRING, filename);
    
    if !Data_Packer.pack_file_with_type_info(file_path, type_info_file_path, Editor.autotile_ruleset) {
        log("Info: failed to save autotile ruleset.");
        return false;
    }
    
    return true;
}

}