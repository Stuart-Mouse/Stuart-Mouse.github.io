
// TODO: figure out what to do about residual editor stuff that we still need to compile everything else

copy_editor_level_to_active_level :: () {
    active_level := get_active_level();
    
    #if EDITOR_ENABLED {
        clone_level(active_level, Editor.level);
    } else {
        if !load_level(active_level, default_level_path) {
            deinit_level(active_level);
            init_empty_level(*active_level);
        }
    }
    
    script_path := to_string(*active_level.script_path[0]);
    load_level_script(active_level, script_path);
    
    music_path := to_string(*active_level.music_path[0]);
    if music_path  load_and_play_music(music_path);
    
    prep_level(active_level);
    
    Game.active_level.id = Editor.level_id;
    Game.active_level.info_index = -1;
    Game.active_level.map_index  = Worldmap.INVALID_MAP_INDEX;
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
    TOOL_SELECT;
    
    MODE_TILE_SELECTOR;
    MODE_ENTITY_SELECTOR;
    
    RELOAD_SCRIPT;
    
    SHOW_IPROF;
    
    SAVE_LEVEL;
    PLAY_EDITOR_LEVEL; // warps player to whatever level is currently open in the editor
    
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

Editor_Tool :: enum { GRAB; BRUSH; SELECT; };

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
        entity:             Entity;
    };
    
    selection: struct {
        first:      Vector2;
        second:     Vector2;
        active:     bool;
        
        clipboard: struct {
            data:   [] Tile;
            size:   Vec2i;
        }
    };
    
    timeline: struct {
        start: float = 0;
        end:   float = 30;
    }
    
    level_id:   Level_ID;
    level:      *Level_Layout;
    
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
    in_autotile_ruleset:    bool;
    show_auto_tile_ruleset: bool;
    
    unsaved_level_id_counter: int;
    
    tile_unit := 32.0;
};

edit_level_with_id :: (id: string) -> bool {
    found, source_layout := table_find_new(*Game.loaded_level_layouts, id);
    if !found {
        log("level % not found, loading now...", id);
        source_layout = New(Level_Layout);
        if !load_level(source_layout, id)  return false;
        table_add(*Game.loaded_level_layouts, copy_string(id), source_layout);
    }
    
    // NOTE: Important! Editor level will point directly at level layout data in the loaded_level_layouts.
    // TODO: we will need some way to reset the loaded level layouts in case player makes changes they don't want to save to some layout
    Editor.level = source_layout;
    copy_from_string(*Editor.level_id, id);
    return true;
}

save_current_editor_level :: () {
    using Editor;
    
    if level_id[0] == "*" {
        // TODO: figure out how to prompt user with some save file dialog or something...
        log("Error: Unable to save editor level: %", to_string(*level_id));
        return;
    }
    
    save_level(level, to_string(*level_id));
}

make_new_empty_editor_level :: (id := "") {
    Editor.level = New(Level_Layout);
    init_empty_level(Editor.level);
    
    _id := ifx id else tprint("*unsaved_level_%", Editor.unsaved_level_id_counter);
    table_add(*Game.loaded_level_layouts, copy_string(_id), Editor.level);
    copy_from_string(*Editor.level_id, _id);
}

init_editor :: () {
    using Editor;
    
    if !edit_level_with_id(default_level_path) {
        make_new_empty_editor_level();
    }
    
    script_path := to_string(*level.script_path[0]);
    if script_path  load_level_script(level, script_path);
    
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

get_editor_selection_rect_for_tilemap :: () -> Rectf {
    using Editor;
    
    tilemap := *level.tilemaps[selected_tilemap];
    
    first  := get_position_in_tilemap(tilemap, selection.first);
    second := get_position_in_tilemap(tilemap, selection.second);
    
    top_left     := floor(min(first, second));
    bottom_right :=  ceil(max(first, second));
    
    return .{ position = top_left + tilemap.offset - tilemap.anchor_point, size = bottom_right - top_left };
}

copy_selection_data :: () {
    using Editor;
    
    tilemap := *level.tilemaps[selected_tilemap];
    
    first  := get_position_in_tilemap(tilemap, selection.first);
    second := get_position_in_tilemap(tilemap, selection.second);
    
    top_left     := to_Vec2i(floor(min(first, second)));
    bottom_right := to_Vec2i( ceil(max(first, second))) - .{1,1};
    
    x_start := max(top_left.x, 0);
    x_end   := min(bottom_right.x, tilemap.size.x-1);
    
    y_start := max(top_left.y, 0);
    y_end   := min(bottom_right.y, tilemap.size.y-1);
    
    selection.clipboard.size = .{ x_end - x_start + 1, y_end - y_start + 1};
    
    data_tile_count := selection.clipboard.size.x * selection.clipboard.size.y;
    if data_tile_count > selection.clipboard.data.count {
        array_resize(*selection.clipboard.data, data_tile_count);
    }
    
    src: int = y_start * tilemap.capacity.x + x_start;
    dst: int = 0;
    for y_start..y_end {
        memcpy(*selection.clipboard.data[dst], *tilemap.data[src], selection.clipboard.size.x * size_of(Tile));
        src += tilemap.capacity.x;
        dst += selection.clipboard.size.x;
    }
}

paste_selection_data :: () {
    using Editor;
    
    if !selection.clipboard.data  return;

    // TODO: add some mechanism to expand tilemap we are pasting into such that it will fit the pasted data
    //       currently, we just cannot paste outside the tilemap's currently allocated bounds
    
    tilemap := *level.tilemaps[selected_tilemap];
    mouse_position_in_tilemap := get_position_in_tilemap(tilemap, mouse_tile_position);
    
    x_start := clamp(mouse_position_in_tilemap.x.(s32), 0, tilemap.capacity.x-1);
    x_end   := clamp(x_start + selection.clipboard.size.x - 1, 0, tilemap.capacity.x-1);
    
    y_start := clamp(mouse_position_in_tilemap.y.(s32), 0, tilemap.capacity.y-1);
    y_end   := clamp(y_start + selection.clipboard.size.y - 1, 0, tilemap.capacity.y-1);
    
    dst_size := Vec2i.{ x_end - x_start + 1, y_end - y_start + 1 };
    
    dst: int = y_start * tilemap.capacity.x + x_start;
    src: int = 0;
    for y_start..y_end {
        memcpy(*tilemap.data[dst], *selection.clipboard.data[src], dst_size.x * size_of(Tile));
        dst += tilemap.capacity.x;
        src += selection.clipboard.size.x;
    }
}

clear_tilemap_selection_state :: () {
    for *Editor.level.tilemaps 
        it.flags &= ~.SELECTED_IN_EDITOR;
}

editor_update_tilemaps :: (show_imgui := false) {
    using Editor;
    if level.script.flags & .TYPECHECKED {
        set_script_variables(level);
        for *level.tilemaps {
            update_tilemap_prescript(it);
            it.offset_next   = it.root_offset;
        }
        execute_level_script(level, show_imgui);
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

update_editor :: () {
    using Editor;
    using Editor_Input_Keys;
    
    if level == null  make_new_empty_editor_level();
    context.current_level = Editor.level;
    
    Input.update_window_events();
    imgui_handle_input_events(Input.events_this_frame);
    process_input_events();
    update_input_controller(editor_controller.data);
    
    // only update the Editor-local mouse if imgui is not capturing mouse
    if !ImGui.GetIO().WantCaptureMouse {
        update_mouse(*mouse);
    } else {
        mouse.velocity = .{};
    }
    push_mouse(*Editor.mouse);
    
    editor_update_tilemaps(show_imgui = true);
    
    for *level.entities {
        if it.flags & .REMOVE_ME {
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
        if editor_controller.TOGGLE_SHOW_DEBUG_WINDOW.state == .PRESSED {
            show_debug_window = !show_debug_window;
        }
        if editor_controller.SAVE_LEVEL.state == .PRESSED {
            save_current_editor_level();
        }
        if editor_controller.PLAY_EDITOR_LEVEL.state == .PRESSED {
            begin_level_with_id(to_string(*Editor.level_id));
            play_music();
            Program_State = .GAME;
        }
    }
    
    // get mouse position in the game world
    mouse_tile_position = pixel_to_internal_units(
        pixel_position  = mouse_position(), 
        internal_unit   = tile_unit, 
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
        tile_unit = clamp(tile_unit + mouse_wheel().y.(float), 8, 64);
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
            for entity_templates {
                clicked, hovered := do_element(.{
                    texture  = *entities_texture, 
                    clip     = rect_to_frect(get_entity_template_icon_clip(it, 16, 16)),
                    palette  = it.palette,
                });
                if clicked {
                    Editor.brush.type = Entity;
                    init_entity(*Editor.brush.entity, xx it_index);
                    Editor.tool = .BRUSH;
                    Editor.mode = .EDIT;
                    ignore_left_mouse_button_until_released(*mouse);
                }
            }
        }
        
      case .EDIT;
        if !ImGui.GetIO().WantCaptureKeyboard {
            if editor_controller.TOOL_BRUSH.state == .PRESSED {
                tool = .BRUSH;
                // brush.type = Tile;
            }
            if editor_controller.TOOL_GRAB.state == .PRESSED {
                tool = .GRAB;
            }
            if editor_controller.TOOL_SELECT.state == .PRESSED {
                tool = .SELECT;
            }
            if editor_controller.RELOAD_SCRIPT.state & .PRESSED {
                if load_level_script(level, to_string(level.script_path.data)) {
                } else {
                    log("Error: failed to load script '%' for level '%'.", level.script_path, level.name);
                }
            }
            if editor_controller.SET_PLAYER_START.state & .PRESSED {
                level.player_debug_spawn = .{
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
                    internal_unit   = tile_unit, 
                );
                level.camera -= mouse_tile_velocity;
            }
        }
        
        
        if tool == {
          case .SELECT;
            if mouse_left() == {
              case .PRESSED;
                reset_editor_selection();
                selection.active = true;
                selection.first  = mouse_tile_position;
                #through;
              case .DOWN;
                selection.second = mouse_tile_position;
              case;
                selection.active = false;
            }
            
            if !ImGui.GetIO().WantCaptureKeyboard {
                if selection.first != selection.second && editor_controller.COPY_SELECTION.state == .PRESSED {
                    copy_selection_data();
                    reset_editor_selection();
                }
                if editor_controller.PASTE_SELECTION.state == .PRESSED {
                    paste_selection_data();
                }
            }
            
          case .GRAB;
            inline do_level_bounds_handles();
            inline do_entity_handles();
            inline do_tilemap_handles();
            
          case .BRUSH;
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
    
    
    { // IMGUI section
        using ImGui;
        
        if Begin("Editor Details") {
            SeparatorText("Level Details");
            Text("level id: %", to_string(*Editor.level_id));
            InputText("level name",               level.name);
            InputText("level script source path", level.script_path);
            InputText("level music path",         level.music_path);
            ColorEdit4("bg color", (*level.bg_color).(*[4]float));
            
            InputFloat4("level bounds", xx *level.bounds);
            
            ComboEnum("wrap_up",    *level.screen_wrap_up);
            ComboEnum("wrap_down",  *level.screen_wrap_down);
            ComboEnum("wrap_left",  *level.screen_wrap_left);
            ComboEnum("wrap_right", *level.screen_wrap_right);
            
            SeparatorText("Timeline");
            // SameLine();
            should_recalculate_timeline_points |= InputFloat("start", *timeline.start);
            should_recalculate_timeline_points |= InputFloat("end", *timeline.end);
            SliderFloat("time", *level.time_since_start, timeline.start, timeline.end);
            
            
            // TODO: should probably set the entity slot here instead of the entity itself, so that we dont have to do the wonky pointer cast
            if details_panel_subject.type == {
              case type_info(Slot(Entity));
                SeparatorText("Entity Details");
                
                slot   := details_panel_subject.value_pointer.(*Slot(Entity));
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
        
        if show_auto_tile_ruleset {
            // if Begin("Auto-Tile Ruleset", *show_auto_tile_ruleset) {
            //     view_min    := GetWindowContentRegionMin();
            //     view_max    := GetWindowContentRegionMax();
            //     view_offset := GetWindowPos();
                
            //     autotile_viewport.position = view_offset + view_min;
            //     autotile_viewport.size = .{ max(view_max.x - view_min.x, 0), max(view_max.y - view_min.y, 0) };
                
            //     if autotile_viewport.size.x > 0 
            //     && autotile_viewport.size.y > 0 {
            //         InvisibleButton("canvas", autotile_viewport.size, .MouseButtonLeft | .MouseButtonRight);
            //     }
            //     is_hovered := IsItemHovered();
                
            //     if is_hovered {
            //         push_mouse(*global_mouse);
            //         defer_restore(*tool);
            //         defer_restore(*selected_tilemap);
            //         defer_restore(*mouse_tile_position);
                    
            //         in_autotile_ruleset = true;
            //         defer in_autotile_ruleset = false;
                    
            //         tool = .BRUSH;
                    
            //         autotile_mouse = pixel_to_internal_units(
            //             pixel_position  = mouse_position(), 
            //             pixel_offset    = to_Vec2i(autotile_viewport.position),
            //             internal_unit   = autotile_tileunit, 
            //             internal_offset = autotile_camera, 
            //         );
                    
            //         mouse_tile_position = autotile_mouse;
                    
            //         CAMERA_MOVE_SPEED := 10.0 / updates_per_second;
                    
            //         if editor_controller.UP.state & .PRESSED {
            //             autotile_camera.y -= CAMERA_MOVE_SPEED;
            //         }
            //         if editor_controller.DOWN.state & .PRESSED {
            //             autotile_camera.y += CAMERA_MOVE_SPEED;
            //         }
            //         if editor_controller.LEFT.state & .PRESSED {
            //             autotile_camera.x -= CAMERA_MOVE_SPEED;
            //         }
            //         if editor_controller.RIGHT.state & .PRESSED {
            //             autotile_camera.x += CAMERA_MOVE_SPEED;
            //         }
                    
            //         if editor_controller.CAMERA_DRAG.state & .DOWN {
            //             mouse_tile_velocity := pixel_to_internal_units(
            //                 pixel_position  = mouse_velocity(), 
            //                 internal_unit   = tile_unit, 
            //             );
            //             autotile_camera -= mouse_tile_velocity;
            //         }
                    
            //         update_tilemap_prescript(*autotile_ruleset);
            //         autotile_ruleset.offset_next = autotile_ruleset.root_offset;
            //         update_tilemap_postscript(*autotile_ruleset);
                    
            //         edit_tilemap(*autotile_ruleset, autotile_mouse);
                    
            //         // update again after editting in case tile is placed, since this tilemap won't get updated in editor_update_tilemaps
            //         // TODO: maybe we can do something more minimal than editor_update_tilemaps when a tilemap is editted, 
            //         //       since only the one tilemap that's editted will need to be updated, 
            //         //       and only the offset really needs to be refreshed.
            //         //       although, updating the offset will require running the script, so...
            //         update_tilemap_prescript(*autotile_ruleset);
            //         autotile_ruleset.offset_next = autotile_ruleset.root_offset;
            //         update_tilemap_postscript(*autotile_ruleset);
            //     }
                
            //     draw_callback :ImDrawCallback: (parent_list: *ImDrawList, cmd: *ImDrawCmd) #c_call  {
            //         new_context: #Context;
            //         push_context new_context {
            //             using Editor;
            //             backup_gl_state();
                        
            //             in_autotile_ruleset = true;
            //             defer in_autotile_ruleset = false;
                        
            //             viewport := frect_to_rect(Editor.autotile_viewport);
                        
            //             autotile_viewport.position = .{0,0};
                        
            //             render_begin_batch();
            //             render_set_viewport(*viewport);
                        
            //             it := *autotile_ruleset;
            //             render_offset := (it.offset - autotile_camera) * autotile_tileunit;
            //             translate(*Renderer.transform, .{ xy = render_offset });
                        
            //             render_alpha: float = 1;
                        
            //             render_tilemap(it, autotile_tileunit, alpha = render_alpha);
                        
            //             // definitely skip rendering any guides if layer contains no data
            //             // EXCEPT we will actually need to render tile preview in world space
                        
            //             tilemap_has_data := it.data && it.size.x > 0 && it.size.y > 0;
                        
            //             do_render_outlines     := tilemap_has_data; // also includes anchor atm
            //             do_render_gridlines    := false;
            //             do_render_tile_preview := false;
                        
            //             // if tool == .BRUSH && brush.type == Tile {
            //                 do_render_tile_preview = true;
            //                 do_render_gridlines    = tilemap_has_data;
            //             // }
                        
            //             anchor_offset := -it.anchor_point * autotile_tileunit;
                        
            //             if do_render_gridlines {
            //                 render_grid(
            //                     tile_size = .{ autotile_tileunit, autotile_tileunit }, 
            //                     dst_rect  = .{ 
            //                         position = anchor_offset,
            //                         size     = to_Vector2(it.capacity) * autotile_tileunit,
            //                     },
            //                     tile_offset = floor(anchor_offset),
            //                     color = grid_color
            //                 );
            //             }
                        
            //             if do_render_tile_preview {
            //                 // maybe we should also render a little grid around tile too?
            //                 // and maybe that solves the case of empty tile layers
            //                 mouse_position_in_tilemap := get_position_in_tilemap(it, autotile_mouse);
                            
            //                 // determine the coordinates at which to place tile
            //                 // if the tilemap is currently empty, then the tile will be placed in the center of the layer
            //                 tile_rect := Rectf.{
            //                     position = anchor_offset + floor(mouse_position_in_tilemap) * autotile_tileunit,
            //                     size     = to_Vec2f(autotile_tileunit),
            //                 };
                            
            //                 // if shift held, render tile mod instead
            //                 if key_modifier_state & .SHIFT {
            //                 //     render_tile_modifier(brush.tile_modifier, brush.tile_modifier_dir, tile_rect);
            //                 } else {
            //                     tri := get_tile_render_info(brush.tile);
            //                     tri.color_mod.a *= 0.5;
            //                     render_draw_quad(
            //                         texture  = tri.texture,
            //                         color    = tri.color_mod,
            //                         position = .{ tile_rect.x, tile_rect.y },
            //                         size     = .{ tile_rect.w, tile_rect.h },
            //                         clip     = *tri.clip,
            //                         palette  = tri.palette, // TODO: load palette from file
            //                     );
            //                 }
            //             }
                        
            //             if do_render_outlines {
            //                 opacity := 1.0;
                            
            //                 // draw capacity outline
            //                 cap_rect := Rectf.{
            //                     position = anchor_offset,
            //                     size     = to_Vector2(it.capacity) * autotile_tileunit
            //                 };
            //                 render_draw_rect(cap_rect, color = .{ 1, 0, 0, opacity } );
                            
            //                 // draw size outline
            //                 size_rect := Rectf.{
            //                     position = anchor_offset + to_Vector2(it.min_index) * autotile_tileunit,
            //                     size     = to_Vector2(it.size) * autotile_tileunit
            //                 };
            //                 render_draw_rect(size_rect, color = .{ 0, 1, 0, opacity } );
                            
            //                 // draw root offset / anchor point
            //                 anchor_point_rect := Rectf.{
            //                     position = it.root_offset - it.offset + .{ -1, -1 },
            //                     size     = .{  3,  3 }
            //                 };
            //                 render_draw_rect(anchor_point_rect, color = .{ 0, 0, 1, opacity } );
            //             }
                        
            //             render_end_batch();
            //             render_flush();
            //         }
            //     };
                
            //     draw_list := GetWindowDrawList();
            //     draw_list.AddCallback(draw_list, draw_callback, null);
            // }
            // End();
        }
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
    
    render_set_viewport();
    render_begin_batch();
    
    // draw level bounds
    render_draw_quad(
        position = (level.bounds.position - level.camera) * tile_unit, 
        size     = level.bounds.size * tile_unit, 
        color    = level.bg_color
    );
    
    // render main grid, gets dimmer when editting a tilemap, since we will also be rendering that tilemap's local-space gridlines
    main_grid_color := grid_color;
    if selected_tilemap >= 0 {
        main_grid_color *= .{ 1, 1, 1, 0.25 };
    }
    render_grid(
        dst_rect    = .{ 0, 0, window_width.(float), window_height.(float) },
        tile_size   = .{ tile_unit, tile_unit }, 
        tile_offset = level.camera * tile_unit,
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
        
        render_offset := (it.offset - level.camera) * tile_unit;
        render_tilemap(it, tile_unit, alpha = render_alpha, offset = render_offset);
        
        // definitely skip rendering any guides if layer contains no data
        // EXCEPT we will actually need to render tile preview in world space
        
        tilemap_has_data := it.data && it.size.x > 0 && it.size.y > 0;
        
        do_render_outlines     := tilemap_has_data; // also includes anchor atm
        do_render_gridlines    := false;        
        do_render_selection    := false;
        do_render_tile_preview := false;
        
        do_render_gridlines = is_selected_tilemap && tilemap_has_data;
        
        if is_selected_tilemap {
            if tool == {
              case .BRUSH;
                do_render_tile_preview = brush.type == Tile;
              case .SELECT;
                do_render_selection = true;
            }
        }
        
        anchor_offset := (it.offset-it.anchor_point-level.camera) * tile_unit;
        
        if do_render_gridlines {
            render_grid(
                tile_size = .{ tile_unit, tile_unit }, 
                dst_rect  = .{ 
                    position = anchor_offset,
                    size     = to_Vector2(it.capacity) * tile_unit,
                },
                tile_offset = floor(anchor_offset),
                color = grid_color
            );
        }
        
        if do_render_selection {
            if selection.first != selection.second {
                rect := get_editor_selection_rect_for_tilemap();
                render_draw_quad(
                    texture       = null,
                    color         = .{ 1, 1, 0, 1.0/8.0 },
                    position      = (rect.position - level.camera) * tile_unit,
                    size          = rect.size * tile_unit,
                );
            }
            if key_modifier_state & .CTRL {
                mouse_position_in_tilemap := get_position_in_tilemap(it, mouse_tile_position);
                render_offset := anchor_offset + floor(mouse_position_in_tilemap) * tile_unit;
                dummy_tilemap := Tilemap.{ data = Editor.selection.clipboard.data, size = Editor.selection.clipboard.size, capacity = Editor.selection.clipboard.size };
                render_tilemap(*dummy_tilemap, tile_unit, alpha = 0.5, offset = render_offset);
            }
        }
        
        if do_render_tile_preview {
            // maybe we should also render a little grid around tile too?
            // and maybe that solves the case of empty tile layers
            mouse_position_in_tilemap := get_position_in_tilemap(it, mouse_tile_position);
            
            // determine the coordinates at which to place tile
            // if the tilemap is currently empty, then the tile will be placed in the center of the layer
            tile_rect := Rectf.{
                position = anchor_offset + floor(mouse_position_in_tilemap) * tile_unit,
                size     = to_Vec2f(tile_unit),
            };
            
            // if shift held, render tile mod instead
            if key_modifier_state & .SHIFT {
            //     render_tile_modifier(brush.tile_modifier, brush.tile_modifier_dir, tile_rect);
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
                size     = to_Vector2(it.capacity) * tile_unit
            };
            render_draw_rect(cap_rect, color = .{ 1, 0, 0, opacity } );
            
            // draw size outline
            size_rect := Rectf.{
                position = anchor_offset + to_Vector2(it.min_index) * tile_unit,
                size     = to_Vector2(it.size) * tile_unit
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
    for tilemaps_sorted {
        render_draw_lines(..it.editor_trail_points, .{0,0,1,1}, 2, -level.camera, tile_unit);
    }
    
    if mode == .EDIT && tool == .BRUSH {
        if brush.type == {
          case Tile;
          case Entity;
            render_position := snap_to_nearest_unit(mouse_tile_position, 0.5) - level.camera;
            render_entity(*brush.entity, tile_unit, render_position, 0.5);
        }
    }
    
    dummy_player := Player.{ position = level.player_debug_spawn };
    render_player(*dummy_player, tile_unit, -level.camera);
    
    for *level.entities {
        render_entity(it, tile_unit, -level.camera);
    }
    
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
        if (mouse_middle() & .PRESSED) && (tilemap.size.x > 0 && tilemap.size.y > 0) {
            hovered_tile := get_tile(tilemap, tile_coords);
            if hovered_tile  Editor.brush.tile = hovered_tile.*;
        }
    }
    
    // shift engages tile modifier brush
    // if keymod & .SHIFT {
    //     if (mouse_left() & .PRESSED) && Editor.brush.tile.id != 0 {
    //         if tile_hovered  set_tile_modifier(tile_hovered, Editor.brush.tile_modifier_dir, Editor.brush.tile_modifier);
    //     }
    //     if (mouse_right() & .PRESSED) && (tilemap.size.x > 0 && tilemap.size.y > 0) {
    //         if tile_hovered  set_tile_modifier(tile_hovered, Editor.brush.tile_modifier_dir, .NONE);
    //     }
        
    //     // shift + ctrl + scroll changes modifier type
    //     if keymod & .CTRL {
    //         if mouse_wheel().y {
    //             // in order to prevent .NONE being in the rotation, subtract 1 before doing modulo, then add it back afterwards
    //             Editor.brush.tile_modifier = modulo(Editor.brush.tile_modifier.(s32) - 1 + mouse_wheel().y, Tile_Modifier._COUNT.(s32)).(Tile_Modifier) + 1;
    //         }
    //     }
    //     // shift + scroll changes modifier direction
    //     else {
    //         if mouse_wheel().y {
    //             Editor.brush.tile_modifier_dir = ((Editor.brush.tile_modifier_dir.(s32) + mouse_wheel().y) & 0b11).(Direction);
    //         }
    //     }
    // }
    
    if keymod == .CTRL {
        if mouse_left() == .PRESSED {
            Editor.details_panel_subject = tile_hovered.*;
        }
    }
    
    // ALT + middle click = set tile layer anchor point
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
            if mouse_velocity() != Vec2i.{} {
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
                if mouse_velocity() != Vec2i.{} {
                    level.bounds.size = Editor.mouse_tile_position - level.bounds.position;
                    level.bounds.size = snap_to_nearest_unit(level.bounds.size, 0.5);
                }
            }
        }
    }
    
    if level.bounds.w < 1  level.bounds.w = 1;
    if level.bounds.h < 1  level.bounds.h = 1;
}


edit_entity_details :: (entity: *Entity) {
    using ImGui;
    
    // if ComboEnum("entity type", *entity.entity_type) {
    //     in_block_data := entity.in_block;
        
    //     // reinit entity for given type
    //     if #complete entity.entity_type == {
    //       case .ENEMY;    init_entity      (*entity.entity, 0);
    //       case .WARP;     init_warp_entity(*entity.warp);
            
    //       case .PLAYER;
    //         // this should actually not be allowed, since player is not in the Entity
    //         entity.entity_type = .NONE;
    //         #through;
            
    //       case .NONE;
    //         entity.* = .{ base = entity.base }; // zero-out anything not part of base entity
    //     }
        
    //     entity.flags |= .IN_BLOCK;
    //     entity.in_block = in_block_data;
    // }
    
    InputText("name", entity.name);
    
    // switch on entity type and allow individually editting all relevant attributes
    // for first version can just use treenodeany to start, I guess
    template_index := entity.template_index;
    if InputScalar("template index: ", *template_index) {
        template_index = clamp(template_index, 0, (entity_templates.count-1).(s32));
        if template_index != entity.template_index {
            init_entity(entity, template_index);
        }
    }
    template := entity_templates[entity.template_index];
    
    ComboEnum("movement direction", *entity.movement_direction, .L, .R, .U, .D);
    
    // TODO: probably change editable properties based on entity template
    
    if entity.flags & .IS_WARP {
        InputScalar("warp id", *entity.warp.local_id);
        ComboEnum("warp type", *entity.warp.warp_type);
        ComboEnum("warp form", *entity.warp.warp_form);
        
        // TODO: flags
        // CheckboxFlags("exit only", xx *warp.warp_flags, xx Warp_Flags.EXIT_ONLY);
        // TODO: button to travel to linked warp
        
        InputScalar("dst local id", *entity.warp.dst_locator.local_id);
        InputText("dst level name", entity.warp.dst_locator.level_name.data);
    }
}


do_entity_handles :: () {
    using Editor;
    for *entity, entity_index: level.entities {
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
                if mouse.velocity != Vec2i.{} {
                    tilemap.root_offset = Editor.mouse_tile_position;
                    tilemap.root_offset = snap_to_nearest_unit(tilemap.root_offset, 0.5);
                    should_recalculate_timeline_points = true;
                }
              case .R;
                if mouse.velocity != Vec2i.{} {
                    tilemap.anchor_point += to_Vec2f(mouse.velocity) / tile_unit;
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
    
    file_path           := tprint(FILE_PATH_FORMAT_STRING,           filename);
    type_info_file_path := tprint(FILE_TYPE_INFO_PATH_FORMAT_STRING, filename);
    
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
    
    file_path           := tprint(FILE_PATH_FORMAT_STRING,           filename);
    type_info_file_path := tprint(FILE_TYPE_INFO_PATH_FORMAT_STRING, filename);
    
    if !Data_Packer.pack_file_with_type_info(file_path, type_info_file_path, Editor.autotile_ruleset) {
        log("Info: failed to save autotile ruleset.");
        return false;
    }
    
    return true;
}

}