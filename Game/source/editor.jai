
// TODO: figure out what to do about residual editor stuff that we still need to compile everything else

copy_editor_level_to_active_level :: () {
    #if EDITOR_ENABLED {
        clone_level_layout(Game.active_level.layout, Editor.level.layout);
        
        Game.active_level.id         = Editor.level.id;
        Game.active_level.info_index = -1;
        Game.active_level.map_index  = Worldmap.INVALID_MAP_INDEX;
    } else {
        if !load_level(Game.active_level.layout, default_level_path) {
            deinit_level_layout(Game.active_level.layout);
            init_empty_level_layout(Game.active_level.layout);
            
            copy_from_string(*Game.active_level.id, "*empty");
            Game.active_level.info_index = -1;
            Game.active_level.map_index  = Worldmap.INVALID_MAP_INDEX;
        }
    }
    
    script_path := to_string(*Game.active_level.script_path);
    load_level_script(*Game.active_level, script_path);
    
    music_path := to_string(*Game.active_level.music_path);
    if music_path  load_and_play_music(music_path);
    
    prep_level(*Game.active_level);
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
    
    CREATE_NEW_LEVEL;
    
    TOOL_BRUSH;
    TOOL_GRAB;
    TOOL_SELECT;
    
    MODE_TILE_SELECTOR;
    MODE_ENTITY_SELECTOR;
    
    RELOAD_SCRIPT;
    
    SHOW_IPROF;
    
    SAVE_LEVEL;
    SAVE_LEVEL_AS;
    PLAY_EDITOR_LEVEL; // warps player to whatever level is currently open in the editor
    
    
    SET_STATE_GAME;
    SET_STATE_EDITOR;
    
    GAME_RESET_LEVEL;
    TOGGLE_SHOW_DEMO_WINDOW;
    TOGGLE_SHOW_DEBUG_WINDOW;
    RELOAD_ASSETS;
    
    TOGGLE_FULLSCREEN;
    
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
        entity_index:       int;
        offset:             Vector2; // position of mouse relative to origin of grabbed element, at time when grab begins
        elements_selected:  int;
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
    
    level:          Level;
    
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
    lock_tilemaps_to_root_offset:   bool;
    lock_entities_to_init_position: bool;
    hide_immediate_mode_entities:   bool;
    
    // used as context flag  
    in_autotile_ruleset:    bool;
    show_auto_tile_ruleset: bool;
    
    show_new_file_dialog:   bool;
    popup_level_name:         Level_ID;
    
    unsaved_level_id_counter: int;
    
    tile_unit := 32.0;
    
    // TODO: add some way to adjust this, save as global setting, etc
    selector_tile_unit := 32.0;
};

editor_toggle_grab_selection :: (entity: *Entity) {
    entity.flags ^= .SELECTED_IN_EDITOR;
    Editor.grab.elements_selected += ifx entity.flags & .SELECTED_IN_EDITOR then 1 else -1;
}

editor_set_grab_selection :: (entity: *Entity) {
    editor_clear_grab_selection();
    entity.flags |= .SELECTED_IN_EDITOR;
    Editor.grab.elements_selected = 1;
}

editor_clear_grab_selection :: () {
    Editor.grab.elements_selected = 0;
    
    for *Editor.level.entities {
        it.flags &= ~.SELECTED_IN_EDITOR;
    }
}

edit_level_with_id :: (id: string) -> bool {
    found, source_layout := table_find_new(*Game.loaded_level_layouts, id);
    if !found {
        source_layout = New(Level_Layout);
        if !load_level(source_layout, id)  return false;
        table_add(*Game.loaded_level_layouts, copy_string(id), source_layout);
    }
    
    Editor.level = .{ layout = source_layout };
    copy_from_string(*Editor.level.id, id);
    
    script_path := to_string(*source_layout.script_path[0]);
    if load_level_script(*Editor.level, script_path) {
        execute_level_script_init_block(*Editor.level);
    }
    Editor.should_recalculate_timeline_points = true;
    
    // NOTE: we don't prep level since that does too many things ATM, but maybe we need some kind of 'thaw level' that does things we need both before playing a level and when beginning to edit it
    
    // NOTE: Important! Editor level will point directly at level layout data in the loaded_level_layouts.
    // TODO: we will need some way to reset the loaded level layouts in case player makes changes they don't want to save to some layout
    
    return true;
}

save_current_editor_level :: () {
    using Editor;
    
    if level.id[0] == "*" {
        // TODO: figure out how to prompt user with some save file dialog or something...
        log("Error: Unable to save editor level: %", to_string(*level.id));
        return;
    }
    
    save_level(level.layout, to_string(*level.id));
    
    script_path := to_string(*level.script_path);
    if script_path && Editor.level.script.flags & .TYPECHECKED {
        builder: String_Builder;
        LS.print_script(*Editor.level.script, *builder);
        output := builder_to_string(*builder);
        
        script_output_path := join("data/scripts/", path_strip_extension(script_path), ".gls",, temp);
        write_entire_file(script_output_path, output);
    }
}

make_new_empty_editor_level :: (id := "") {
    Editor.level.layout = New(Level_Layout);
    init_empty_level_layout(Editor.level.layout);
    
    _id := ifx id else tprint("*unsaved_level_%", Editor.unsaved_level_id_counter);
    table_add(*Game.loaded_level_layouts, copy_string(_id), Editor.level.layout);
    copy_from_string(*Editor.level.id, _id);
}

init_editor :: () {
    using Editor;
    
    if !edit_level_with_id(default_level_path) {
        make_new_empty_editor_level();
    }
    
    tile_selector = .{
        tile_size    = .{ 32, 32 },
        tile_padding = .{ 4, 4 },
        
        bg_color      = .{ 0, 0, 0, 0.8 },
        outline_color = .{ 0.6, 0.6, 0.6, 1 },
    };
    
    entity_selector = .{
        tile_size    = .{ 32, 32 },
        tile_padding = .{ 4, 4 },
        
        bg_color      = .{ 0, 0, 0, 0.8 },
        outline_color = .{ 0.6, 0.6, 0.6, 1 },
    };
    
    should_recalculate_timeline_points = true;
    
    if !load_autotile_ruleset() {
        init_tilemap(*autotile_ruleset);
    }
    
    
    // init editor ui stuff 
    {
        using ui_state;
        
        init(*ui_state.pool);
        
        root_node = New(UI_Node,, get_pool_allocator(*ui_state.pool));
    }
}

reset_editor_selection :: inline () {
    Editor.selection.first  = .{};
    Editor.selection.second = .{};
    Editor.selection.active = false;
}

begin_editor_selection :: inline (position: Vec2f) {
    Editor.selection.first  = position;
    Editor.selection.second = position;
    Editor.selection.active = true;
}

update_editor_selection :: inline (position: Vec2f) {
    if Editor.selection.active {
        Editor.selection.second = position;
    }
}

finalize_editor_selection :: inline (position: Vec2f) {
    if Editor.selection.active {
        Editor.selection.second = position;
        Editor.selection.active = false;
    }
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

get_selected_tile_region :: () -> Rect {
    using Editor;
    
    tilemap := *level.tilemaps[selected_tilemap];
    
    first  := get_position_in_tilemap(tilemap, selection.first);
    second := get_position_in_tilemap(tilemap, selection.second);
    
    top_left     := to_Vec2i(floor(min(first, second)));
    bottom_right := to_Vec2i( ceil(max(first, second)));
    
    return .{ position = top_left, size = bottom_right - top_left };
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
    
    src: int = y_start * tilemap.size.x + x_start;
    dst: int = 0;
    for y_start..y_end {
        memcpy(*selection.clipboard.data[dst], *tilemap.data[src], selection.clipboard.size.x * size_of(Tile));
        src += tilemap.size.x;
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
    
    x_start := clamp(mouse_position_in_tilemap.x.(s32), 0, tilemap.size.x-1);
    x_end   := clamp(x_start + selection.clipboard.size.x - 1, 0, tilemap.size.x-1);
    
    y_start := clamp(mouse_position_in_tilemap.y.(s32), 0, tilemap.size.y-1);
    y_end   := clamp(y_start + selection.clipboard.size.y - 1, 0, tilemap.size.y-1);
    
    dst_size := Vec2i.{ x_end - x_start + 1, y_end - y_start + 1 };
    
    dst: int = y_start * tilemap.size.x + x_start;
    src: int = 0;
    for y_start..y_end {
        memcpy(*tilemap.data[dst], *selection.clipboard.data[src], dst_size.x * size_of(Tile));
        dst += tilemap.size.x;
        src += selection.clipboard.size.x;
    }
}

clear_tilemap_selection_state :: () {
    for *Editor.level.tilemaps 
        it.flags &= ~.SELECTED_IN_EDITOR;
}

editor_update_level_state :: (show_imgui := false) {
    using Editor;
    
    for *level.tilemaps {
        update_tilemap_prescript(it);
    }
    
    for *level.entities {
        if it.flags & .REMOVE_ME  remove;
        it.position, it.position_prev = it.init_position;
    }
    
    // NOTE: must be reset before last time we run script so that we don't generate duplicate render commands
    array_reset(*immediate_entity_render_commands);
    
    lttro := lock_tilemaps_to_root_offset;
    
    if Editor.level.script.flags & .TYPECHECKED {
        execute_level_script(*Editor.level, show_imgui);
    } else {
        lttro = true;
    }
    
    if lttro {
        for *level.tilemaps {
            it.offset, it.offset_next = it.root_offset;
        }
    }
    
    for *level.tilemaps {
        update_tilemap_postscript(it);
        
        // NOTE: in editor, we always set offset to equal offset_next
        it.offset = it.offset_next;
    }
    
    if lock_entities_to_init_position {
        for *level.entities {
            it.position, it.position_prev = it.init_position;
        }
    }
}

update_editor :: () {
    using Editor;
    using Editor_Input_Keys;
    
    if level.layout == null  make_new_empty_editor_level();
    context.current_level = *Editor.level;
    context.layout_context.tile_unit = Editor.tile_unit;
    
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
    
    
    for *Editor.level.tilemaps {
        reset_transient_editor_flags(it);
    }
    
    ui_begin_frame();
    
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
            begin_level_with_id(to_string(*Editor.level.id), use_debug_spawn = true);
            play_music();
            Program_State = .GAME;
        }
        if editor_controller.CREATE_NEW_LEVEL.state & .PRESSED {
            ImGui.OpenPopup("Create New Level");
            popup_level_name[0] = 0;
        }
        if editor_controller.SAVE_LEVEL_AS.state & .PRESSED {
            ImGui.OpenPopup("Save Level As");
            popup_level_name[0] = 0;
        }
    }
    
    { using ImGui;
        if IsPopupOpen("Create New Level") {
            SetNextWindowSize(.{300,90});
            SetNextWindowPos(GetMainViewport().Size / 2, .Always, .{ .5, .5 });
            if BeginPopupModal("Create New Level", flags = .NoTitleBar | .NoMove | .NoCollapse | .NoResize) {
                SeparatorText("Create New Level");
                InputText("Name", *popup_level_name);
                if Button("Create") {
                    make_new_empty_editor_level(to_string(*popup_level_name));
                    CloseCurrentPopup();
                }
                SameLine();
                if Button("Cancel") {
                    CloseCurrentPopup();
                }
                EndPopup();
            }
        }
    }
    
    { using ImGui;
        if IsPopupOpen("Save Level As") {
            SetNextWindowSize(.{300,90});
            SetNextWindowPos(GetMainViewport().Size / 2, .Always, .{ .5, .5 });
            if BeginPopupModal("Save Level As", flags = .NoTitleBar | .NoMove | .NoCollapse | .NoResize) {
                SeparatorText("Save Level As");
                InputText("Name", *popup_level_name);
                if Button("Save") {
                    level_path := to_string(*popup_level_name);
                    save_level(Editor.level.layout, level_path);
                    edit_level_with_id(level_path);
                    CloseCurrentPopup();
                }
                SameLine();
                if Button("Cancel") {
                    CloseCurrentPopup();
                }
                EndPopup();
            }
        }
    }
    
    // get mouse position in the game world
    mouse_tile_position = pixel_to_internal_units(
        pixel_position  = mouse_position(), 
        internal_unit   = tile_unit, 
        internal_offset = level.camera, 
    );
    
    // handle mouse scroll
    if !key_modifier_state {
        if brush.type == Tile {
            if mouse_wheel().y {
                brush.tile = Tile.{
                    id = clamp(brush.tile.id.(s32) + mouse_wheel().y, 1, Game.tileset.count.(s32)-1).(Tile_ID),
                };
            }
        }
    }
    if key_modifier_state == .CTRL {
        tile_unit = clamp(tile_unit + mouse_wheel().y.(float), 8, 128);
        
        // adjust camera position after zoom to keep mouse in same worldspace position
        mouse_tile_position_after := pixel_to_internal_units(
            pixel_position  = mouse_position(), 
            internal_unit   = tile_unit, 
            internal_offset = level.camera, 
        );
        level.camera -= mouse_tile_position_after - mouse_tile_position;
    }
    
    do_auto_tile = (key_modifier_state & .ALT).(bool);
    
    if mode == {
      case .TILE_SELECTOR;
        tile_selector.position  = .{ window_width.(float) / 4, window_height.(float) / 4 };
        tile_selector.size      = .{ window_width.(float) / 2, window_height.(float) / 2 };
        tile_selector.tile_size = to_Vec2f(selector_tile_unit);
        
        for tile_selector {
            for Game.tileset {
                tri := get_tile_render_info(.{ id = xx it_index });
                clicked, hovered := do_element(.{
                    texture  = *textures.TILES, 
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
        entity_selector.position  = .{ window_width.(float) / 4, window_height.(float) / 4 };
        entity_selector.size      = .{ window_width.(float) / 2, window_height.(float) / 2 };
        entity_selector.tile_size = to_Vec2f(selector_tile_unit);
        // entity_selector.render_offset = -entity_selector.position; 
        
        for entity_selector {
            for entity_templates {
                clicked, hovered := do_element(.{
                    texture  = *textures.ENTITIES, 
                    clip     = rect_to_frect(get_entity_template_icon_clip(it, 16, 16)),
                    palette  = it.palette,
                });
                if clicked {
                    Editor.brush.type = Entity;
                    init_entity(*Editor.brush.entity, xx it_index, no_handle = true);
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
                script_path := to_string(*level.script_path);
                if load_level_script(*level, script_path) {
                    execute_level_script_init_block(*Editor.level);
                    // TODO: maybe run init block?
                } else {
                    log("Error: failed to load script '%' for level '%'.", script_path, level.name);
                }
                should_recalculate_timeline_points = true;
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
            
            if editor_controller.TOGGLE_FULLSCREEN.state == .PRESSED {
                toggle_fullscreen();
            }
        }
        
        
        if tool == {
          case .SELECT;
            if mouse.left == {
              case .PRESSED;  begin\  _editor_selection(mouse_tile_position);
              case .DOWN;     update\ _editor_selection(mouse_tile_position);
              case .RELEASED; finalize_editor_selection(mouse_tile_position);
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
            should_finalize_selection := false;
            
            if key_modifier_state & .SHIFT {
                if mouse.left == {
                  case .PRESSED;
                    begin_editor_selection(mouse_tile_position);
                    if !(key_modifier_state & .CTRL) {
                        editor_clear_grab_selection();
                    }
                    
                  case .DOWN;
                    update_editor_selection(mouse_tile_position);
                    
                  case .RELEASED;
                    should_finalize_selection = true;
                }
            } else {
                if selection.active {
                    should_finalize_selection = true;
                }
            }
            
            if should_finalize_selection {
                finalize_editor_selection(mouse_tile_position);
                for *level.entities {
                    if aabb_frect(get_editor_selection_rect(), get_collision_rect(it)) {
                        // it.flags |= .SELECTED_IN_EDITOR; // NOTE: only for visual effect
                        editor_toggle_grab_selection(it);
                    }
                }
                reset_editor_selection();
            }
            
            inline do_level_bounds_handles();
            
            for *Editor.level.entities {
                ui_entity_handle(it_index);
                
                // TODO: create a ui_append_to_entity or ui_append_to_tilemap proc for use in scripts
                
                // TODO: better coordination for checking whether to show child nodes?
                //       we could handle deactivation of child nodes by just having those nodes check if multi-select is active
                //       or we can prevent it at the level of the ui_push_for_children, by somehow letting the ui ask for permission before allowing the showing of child nodes
                //       maybe that will end up just being a SHOULD_SHOW_CHILD_NODES flag on node which we can flag or supress in parent
                
                //       another thought about how to handle multi-select from within the ui code itself would be to let the user set some "tool" id that determines which node types can be selected as a group by that tool
                //       other than serving as some means as communicating outer, user state to visited node about how to handle active.hot state, the tool id is totally irrelevant to ui function
                
                // if !(Editor.selection.active || Editor.grab.elements_selected > 1) && ui_push_for_children(ui_id(Entity, it_index)) {
                //     defer ui_pop();
                //     ui_rotation_handle(ui_id("rotation"), *it.rotation, 2);
                // }
            }
            for 0..Editor.level.tilemaps.count-1 {
                ui_tilemap_handle(it);
            }
            
          case .BRUSH;
            if brush.type == {
              case Tile;
                if selected_tilemap >= 0 && selected_tilemap < level.tilemaps.count {
                    edit_tilemap(*level.tilemaps[selected_tilemap], mouse_tile_position);
                }
                if editor_controller.PASTE_SELECTION.state == .PRESSED {
                    paste_selection_data();
                }
                
              case Entity;
                if mouse.left == .PRESSED {
                    slot, index := get_first_empty_slot(*level.entities, true);
                    if slot != null {
                        slot.* = brush.entity;
                        slot.handle = .{ index, random_get() };
                        
                        slot.init_position = snap_to_nearest_unit(mouse_tile_position, 0.5);
                        slot.position = slot.init_position;
                    } else {
                        log("No empty slots in entities array!");
                    }
                }
                if mouse.middle == .PRESSED {
                    for *level.entities {
                        if is_point_within_frect(mouse_tile_position, get_collision_rect(it)) {
                            brush.entity = it.*;
                            brush.entity.handle = .{};
                            brush.entity.init_position = .{};
                            brush.entity.position = .{};
                        }
                    }
                }
                if mouse.right & .PRESSED {
                    for *level.entities {
                        if is_point_within_frect(mouse_tile_position, get_collision_rect(it)) {
                            deinit_entity(it);
                            Editor.details_panel_subject = Any.{};
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
            Text("id: %", to_string(*Editor.level.id));
            InputText("name",               *level.name);
            InputText("script source path", *level.script_path);
            InputText("music path",         *level.music_path);
            ColorEdit4("bg color", (*level.bg_color).(*[4]float));
            
            InputFloat4("bounds", xx *level.bounds);
            
            SliderFloat("tempo", xx *level.tempo, 0.1, 10.0);
            
            ComboEnum("wrap_up",    *level.screen_wrap_up);
            ComboEnum("wrap_down",  *level.screen_wrap_down);
            ComboEnum("wrap_left",  *level.screen_wrap_left);
            ComboEnum("wrap_right", *level.screen_wrap_right);
            
            Text("script random seed: %", level.script.random_seed);
            if Button("randomize seed")  level.script.random_seed = random_get();
            
            if Button("Add") {
                slot, index := get_first_empty_slot(*level.entity_groups, true);
                if slot {
                    copy_from_string(*slot.id, tprint("unnamed group %", index));
                }
            }
            SameLine();
            if CollapsingHeader("Entity Groups") {
                for *group, group_index: level.entity_groups {
                    if Button(tprintc("&###&%", group_index)) {
                        Editor.tool = .GRAB;
                        editor_clear_grab_selection();
                        for *level.entities {
                            if it.group_membership[group_index] {
                                editor_toggle_grab_selection(it);
                            }
                        }
                    }
                    SameLine();
                    InputText(tprintc("###%", group_index), *group.id);
                }
            }
            
            SeparatorText("Timeline");
            Checkbox("lock tilemaps to root offset", *lock_tilemaps_to_root_offset);
            Checkbox("lock entities to init position", *lock_entities_to_init_position);
            Checkbox("hide immediate mode entities", *hide_immediate_mode_entities);
            
            // SameLine();
            should_recalculate_timeline_points |= InputFloat("start", *timeline.start);
            should_recalculate_timeline_points |= InputFloat("end", *timeline.end);
            SliderFloat("time", *level.time_since_start, timeline.start, timeline.end);
            
            // TODO: when we have multiple entity handles selected, create a dummy entity on whom we can set values that could realiztically be applied to all selected entities
            if details_panel_subject.type == {
              case type_info(Entity);
                entity := details_panel_subject.value_pointer.(*Entity);
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
            // tilemaps_sorted := get_tilemaps_sorted(level.tilemaps);
            z_index_min := -level.tilemaps.count;
            z_index_max :=  level.tilemaps.count;
            
            for *level.tilemaps {
                // actual_index := it - level.tilemaps.data;
                actual_index := it_index;
                
                PushID(tprintc("tl%", it_index));
                if Button("edit") {
                    selected_tilemap = actual_index;
                    tool = .BRUSH;
                }
                
                SameLine();
                SetNextItemWidth(30);
                DragScalar(tprintc("###zindex%", it_index), *it.z_index, 0.05, *z_index_min, *z_index_max);
                
                SameLine();
                if CollapsingHeader(tprintc("%###tl%", to_string(*it.name[0]), it_index)) {
                    InputText("name", it.name);
                    ColorEdit4("bg color", *it.color_mod.component);
                    CheckboxFlags("hide", (*it.flags).(*u32), xx Tilemap.Flags.HIDDEN_IN_EDITOR);
                    CheckboxFlags("disable collision", (*it.flags).(*u32), xx Tilemap.Flags.DISABLE_COLLISIONS);
                    
                    Text("size: %", it.size);
                    Text("min_index: %", it.min_index);
                    Text("max_index: %", it.max_index);
                    Text("root_offset: %", it.root_offset);
                    Text("anchor_point: %", it.anchor_point);
                    
                    if Button("remove") {
                        array_unordered_remove_by_index(*level.tilemaps, actual_index);
                    }
                }
                PopID();
            }
        }
        End();
    } // END IMGUI
    
    // don't even bother if there's no level script loaded
    should_recalculate_timeline_points &&= (Editor.level.script.flags & .TYPECHECKED).(bool);
    if should_recalculate_timeline_points {
        should_recalculate_timeline_points = false;
        defer_restore(*level.time_since_start);
        
        timespan := Editor.timeline.end - Editor.timeline.start;
        
        trail_count := Tilemap.editor_trail_points.count;
        for it_point: 0..trail_count-1 {
            delta_t := timespan * it_point.(float) / trail_count.(float);
            level.time_since_start = Editor.timeline.start + delta_t;
            editor_update_level_state();
            for *level.tilemaps {
                it.editor_trail_points[it_point] = it.offset_next - it.root_offset;
            }
        }
    }
    
    editor_update_level_state(show_imgui=true);
}

render_editor :: () {
    using Editor;
    
    update_tile_animations();
    
    render_set_viewport();
    render_begin_batch();
    
    // draw level background
    render_draw_quad(
        position = (level.bounds.position - level.camera) * tile_unit, 
        size     = level.bounds.size * tile_unit, 
        palette  = get_color_animation_index("background"),
        do_color_per_vertex = false,
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
        
        color_mod := COLORS.WHITE;
        if it.flags & .HIDDEN_IN_EDITOR {
            color_mod.a = 0.1;
        } else {
            if tool == {
              case .GRAB;
                if get_id_type_and_index(ui_state.active) == Tilemap {
                    if      it.flags & .SELECTED_IN_EDITOR 
                    then    color_mod = .{1,1,1,1};
                    else    color_mod.a = 0.5;
                }
                else if get_id_type_and_index(ui_state.hot) == Tilemap {
                    if      it.flags & .HOVERED_IN_EDITOR 
                    then    color_mod = .{1.5,1.5,1.5,1};
                    else    color_mod.a = 0.7;
                }
                
              case .BRUSH;
                if brush.type == Tile && selected_tilemap >= 0 && !is_selected_tilemap {
                    color_mod.a = 0.5;
                }
            }
        }
        
        
        tilemap_render_offset := (it.offset-it.anchor_point-level.camera) * tile_unit;
        render_tilemap(it, tile_unit, color_mod = color_mod, offset = tilemap_render_offset);
        
        // definitely skip rendering any guides if layer contains no data
        // EXCEPT we will actually need to render tile preview in world space
        
        content_size := get_content_region(it).size;
        
        tilemap_has_data := it.data && content_size.x > 0 && content_size.y > 0;
        
        using_tile_brush := Editor.tool == .BRUSH && Editor.brush.type == Tile;
        using_tile_selector := Editor.tool == .SELECT;
        
        do_render_outlines     := false; // also includes anchor atm
        do_render_gridlines    := false;        
        do_render_selection    := false;
        do_render_tile_preview := false;
        
        do_render_gridlines = (using_tile_brush || using_tile_selector) && is_selected_tilemap && tilemap_has_data;
        
        do_render_selection = do_render_gridlines;
        
        do_render_outlines  = do_render_gridlines || (tilemap_has_data && (it.flags & (.HOVERED_IN_EDITOR | .SELECTED_IN_EDITOR)));
        
        if is_selected_tilemap {            
            if tool == {
              case .BRUSH;
                do_render_tile_preview = brush.type == Tile;
              case .SELECT;
                do_render_gridlines = true;
            }
        }
        
        if do_render_gridlines {
            render_grid(
                tile_size = .{ tile_unit, tile_unit }, 
                dst_rect  = .{ 
                    position = tilemap_render_offset,
                    size     = to_Vector2(it.size) * tile_unit,
                },
                tile_offset = floor(tilemap_render_offset),
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
                render_offset := tilemap_render_offset + floor(mouse_position_in_tilemap) * tile_unit;
                dummy_tilemap := Tilemap.{ data = Editor.selection.clipboard.data, size = Editor.selection.clipboard.size };
                render_tilemap(*dummy_tilemap, tile_unit, color_mod = .{1,1,1,0.5}, offset = render_offset);
            }
        }
        
        if do_render_tile_preview {
            // maybe we should also render a little grid around tile too?
            // and maybe that solves the case of empty tile layers
            mouse_position_in_tilemap := get_position_in_tilemap(it, mouse_tile_position);
            
            // determine the coordinates at which to place tile
            // if the tilemap is currently empty, then the tile will be placed in the center of the layer
            tile_rect := Rectf.{
                position = tilemap_render_offset + floor(mouse_position_in_tilemap) * tile_unit,
                size     = to_Vec2f(tile_unit),
            };
            
            // if shift held, render tile mod instead
            // if key_modifier_state & .SHIFT {
            //     render_tile_modifier(brush.tile_modifier, brush.tile_modifier_dir, tile_rect);
            // }
            
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
        
        if do_render_outlines {
            opacity := 0.2;
            if tool == {
              case .GRAB;
                if      it.flags & .SELECTED_IN_EDITOR then opacity = 1.0;
                else if it.flags &  .HOVERED_IN_EDITOR then opacity = 0.6;
                
              case .SELECT; #through;
              case .BRUSH;
                if is_selected_tilemap then opacity = 1.0;
            }
            
            // draw size outline
            cap_rect := Rectf.{
                position = tilemap_render_offset,
                size     = to_Vector2(it.size) * tile_unit
            };
            render_draw_rect(cap_rect, color = .{ 1, 0, 0, opacity } );
            
            // draw content region outline
            size_rect := Rectf.{
                position = tilemap_render_offset + to_Vector2(it.min_index) * tile_unit,
                size     = to_Vector2(content_size) * tile_unit
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
        offset := (it.root_offset-level.camera);
        render_draw_lines(..it.editor_trail_points, .{0,0,1,1}, 2, offset, tile_unit);
    }
    
    if mode == .EDIT && tool == .BRUSH {
        if brush.type == {
          case Tile;
          case Entity;
            render_position := snap_to_nearest_unit(mouse_tile_position, 0.5) - level.camera;
            render_entity(*brush.entity, tile_unit, render_position, 0.5);
        }
    }
    
    for *level.entities {
        update_movement_visualizer(it);
        render_movement_visualizer(it.movement_visualizer, tile_unit, -level.camera);
        render_entity(it, tile_unit, -level.camera);
    }
    
    if !hide_immediate_mode_entities {
        for immediate_entity_render_commands  exec_render_command(it);
    }
    
    dummy_player := Player.{ position = level.player_debug_spawn };
    render_player(*dummy_player, tile_unit, -level.camera);
    
    render_ui_state();
    
    if mode == .EDIT && tool == .GRAB {
        if selection.first != selection.second {
            rect := get_editor_selection_rect();
            render_draw_quad(
                texture       = null,
                color         = .{ 1, 1, 0, 1.0/8.0 },
                position      = (rect.position - level.camera) * tile_unit,
                size          = rect.size * tile_unit,
            );
        }
    }
    
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
    mouse := get_mouse();
    
    // determine the coordinates at which to place tile
    // if the tilemap is currently empty, then the tile will be placed in the center of the layer
    tile_coords: Vec2i;
    content_size := get_content_region(tilemap).size;
    if (content_size.x == 0 || content_size.y == 0) { // it should never be possible that one is zero while the other is not
        tile_coords          = tilemap.size / 2;
        tilemap.root_offset  = floor(mouse_tile_position);// - to_Vec2f(tile_coords/2);
        tilemap.anchor_point = to_Vector2(tile_coords);
    } else {
        tile_coords = to_Vec2i_floor(mouse_position_in_tilemap);
    }
    
    hovered_tile := get_tile(tilemap, tile_coords);
    
    // TODO: use separate tool for tile modifiers
    // shift engages tile modifier brush
    // if key_modifier_state & .SHIFT {
    //     if (mouse.left & .PRESSED) && Editor.brush.tile.id != 0 {
    //         if tile_hovered  set_tile_modifier(tile_hovered, Editor.brush.tile_modifier_dir, Editor.brush.tile_modifier);
    //     }
    //     if (mouse.right & .PRESSED) && (tilemap.size.x > 0 && tilemap.size.y > 0) {
    //         if tile_hovered  set_tile_modifier(tile_hovered, Editor.brush.tile_modifier_dir, .NONE);
    //     }
        
    //     // shift + ctrl + scroll changes modifier type
    //     if key_modifier_state & .CTRL {
    //         if mouse.wheel.y {
    //             // in order to prevent .NONE being in the rotation, subtract 1 before doing modulo, then add it back afterwards
    //             Editor.brush.tile_modifier = modulo(Editor.brush.tile_modifier.(s32) - 1 + mouse.wheel.y, Tile_Modifier._COUNT.(s32)).(Tile_Modifier) + 1;
    //         }
    //     }
    //     // shift + scroll changes modifier direction
    //     else {
    //         if mouse.wheel.y {
    //             Editor.brush.tile_modifier_dir = ((Editor.brush.tile_modifier_dir.(s32) + mouse.wheel.y) & 0b11).(Direction);
    //         }
    //     }
    // }
    
    if key_modifier_state == {
      case .CTRL;
        if mouse.left == .PRESSED {
            if hovered_tile  Editor.details_panel_subject = hovered_tile.*;
        }
        
      case .SHIFT;
        if (mouse.left == .PRESSED) && Editor.brush.tile.id != 0 && hovered_tile {
            bounding_box := get_selected_tile_region();
            tile_id := hovered_tile.id;
            flood_fill(tilemap, Editor.brush.tile, tile_coords, tile_id = *tile_id, bounding_box = *bounding_box);
        }
        if (mouse.right & .PRESSED) && (tilemap.size.x > 0 && tilemap.size.y > 0) {
            bounding_box := get_selected_tile_region();
            tile_id := hovered_tile.id;
            flood_fill(tilemap, Tile.{}, tile_coords, tile_id = *tile_id, bounding_box = *bounding_box);
        }
        
      case;
        if (mouse.left & .PRESSED) && Editor.brush.tile.id != 0 {
            place_tile(tilemap, Editor.brush.tile, tile_coords);
        }
        if (mouse.right & .PRESSED) && (tilemap.size.x > 0 && tilemap.size.y > 0) {
            editor_remove_tile(tilemap, tile_coords);
        }
        if (mouse.middle & .PRESSED) && (tilemap.size.x > 0 && tilemap.size.y > 0) {
            if hovered_tile  Editor.brush.tile = hovered_tile.*;
        }
    }
}


do_level_bounds_handles :: () {
    mouse := get_mouse();
    
    {
        node := ui_push_defer_pop(ui_id("level_bounds_position"));
        
        offset := Editor.level.bounds.position;
        size := Vec2f.{1,1};
        
        // get entity handle rect
        rect := Rectf.{
            position = offset - size / 2,
            size     = size,
        };
        
        hovered := is_point_within_frect(Editor.mouse_tile_position, rect);
        update_active_hot_state(node, hovered);
        
        if node.flags & .ACTIVE {
            if mouse.left == { 
              case .DOWN;
                Editor.level.bounds.position += to_Vec2f(mouse.velocity) / Editor.tile_unit;
                
              case .RELEASED;
                Editor.level.bounds.position = snap_to_nearest_unit(Editor.level.bounds.position, 0.5);
            }
            
            if !mouse.left {
                if mouse.right == {
                  case .DOWN;
                    Editor.level.bounds.position += to_Vec2f(mouse.velocity) / Editor.tile_unit;
                    Editor.level.bounds.size     -= to_Vec2f(mouse.velocity) / Editor.tile_unit;
                    
                  case .RELEASED;
                    Editor.level.bounds.position = snap_to_nearest_unit(Editor.level.bounds.position, 0.5);
                    Editor.level.bounds.size     = snap_to_nearest_unit(Editor.level.bounds.size,     0.5);
                }
            }
        }
        
        update_node(node, offset);
        
        color := get_render_color(node, base_color, hot_color, active_color);
        
        append_render_command_quad(*ui_state.draw_list,
            texture  = *textures.UI_ELEMENTS,
            clip     = *ui_texture_clip_bound_UL,
            color    = color,
            position = (rect.position - Editor.level.camera) * Editor.tile_unit,
            size     = rect.size * Editor.tile_unit,
        );
    }
    
    // bottom-right bounds handle is child to top-left so that we get relative positioning for free
    {
        node := ui_push_defer_pop(ui_id("level_bounds_size"));
        
        offset := Editor.level.bounds.position + Editor.level.bounds.size;
        size := Vec2f.{1,1};
        
        // get entity handle rect
        rect := Rectf.{
            position = offset - size / 2,
            size     = size,
        };
        
        hovered := is_point_within_frect(Editor.mouse_tile_position, rect);
        update_active_hot_state(node, hovered);
        
        if node.flags & .ACTIVE {
            if mouse.left == {
              case .DOWN;
                Editor.level.bounds.size += to_Vec2f(mouse.velocity) / Editor.tile_unit;
                
              case .RELEASED;
                Editor.level.bounds.size = snap_to_nearest_unit(Editor.level.bounds.size, 0.5);
            }
        }
        
        offset = Editor.level.bounds.position + Editor.level.bounds.size;
        update_node(node, offset);
        
        color := get_render_color(node, base_color, hot_color, active_color);
        
        append_render_command_quad(*ui_state.draw_list,
            texture  = *textures.UI_ELEMENTS,
            clip     = *ui_texture_clip_bound_DR,
            color    = color,
            position = (rect.position - Editor.level.camera) * Editor.tile_unit,
            size     = rect.size * Editor.tile_unit,
        );
    }
    
    if Editor.level.bounds.w < 1  Editor.level.bounds.w = 1;
    if Editor.level.bounds.h < 1  Editor.level.bounds.h = 1;
}


edit_entity_details :: (entity: *Entity) {
    using ImGui;
    
    PushID("Entity Details");
    defer PopID();
    
    SeparatorText("Entity Details");
    
    Text("Entity Handle: { %, % }", entity.handle.index, entity.handle.uuid);
    if Button("Remove") {
        deinit_entity(entity);
        set_index_occupied(*Editor.level.entities, entity, false);
        Editor.details_panel_subject = Any.{};
    }
    
    InputText("name", *entity.name);
    Text("index: %", entity.handle.index);
    Text("uuid: %", entity.handle.uuid);
    
    ComboArrayOfStructs("template",
        entity_templates,
        *entity.template_index,
        "name",
    );
    
    {
        PushID("movement visualizer");
        
        ComboEnum("movement visualizer type", *entity.movement_visualizer.type);
        if entity.movement_visualizer.type == {
          case .LINE;
            color_palette_combo_box("palette", *entity.movement_visualizer.line.palette);
            ColorEdit4("color", *entity.movement_visualizer.line.color.component);
            
          case .DOTTED_LINE;
            color_palette_combo_box("palette", *entity.movement_visualizer.dotted_line.palette);
            ColorEdit4("color", *entity.movement_visualizer.dotted_line.color.component);
        }
        
        PopID();
    }
    
    ComboEnum("movement direction", *entity.movement_direction, .L, .R, .U, .D);
    
    color_palette_combo_box("palette", *entity.palette);
    
    for Editor.level.entity_groups {
        CheckboxFlags(to_c_string(*it.id), (*entity.group_membership.slots).(*u32), xx (1 << it_index));
    }
    
    if ComboEnum("attached to kind", *entity.attached_to.kind) {
        entity.attached_to.index = -1;
        entity.attached_to.uuid  = 0;
    };
    if entity.attached_to.kind == {
      case .TILEMAP;
        ComboArrayOfStructs("tilemap",
            Editor.level.tilemaps,
            *entity.attached_to.index,
            "name",
        );
        
      case .ENTITY;
        // check that current attached_to handle is value
        if !get(entity.attached_to.entity) {
            entity.attached_to.index = -1;
            entity.attached_to.uuid  = 0;
        }
        if ComboIndexOf("entity",
            Editor.level.entities,
            *entity.attached_to.index,
            e => to_string(*e.name)
        ) {
            if index_is_occupied(Editor.level.entities, entity.attached_to.index) {
                other_entity := *Editor.level.entities[entity.attached_to.index];
                entity.attached_to.uuid = other_entity.handle.uuid;
            }
        };
        
    }
    
    SliderFloat2("scale", xx *entity.scale, 0.25, 5.0);
    SliderFloat("tempo", xx *entity.tempo, 0.1, 10.0);
    
    CheckboxFlags("snap to floor on level init", (*entity.flags).(*u32), xx Entity.Flags.SNAP_TO_FLOOR_ON_LEVEL_INIT);
    
    // TODO: probably change editable properties based on entity template
    CheckboxFlags("is warp", (*entity.flags).(*u32), xx Entity.Flags.IS_WARP);
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
    
    // table_flags := TableFlags.BordersV | .BordersOuterH | .RowBg;
    // virtual_members := get_virtual_members_for_entity(*Editor.level.script, entity.handle,, temp);
    
    // if virtual_members && BeginTable("Virtual Members", 3, table_flags) {
    //     TableSetupColumn("Name",  .NoHide);
    //     TableSetupColumn("Value", .NoHide);
    //     TableSetupColumn("Type",  .NoHide);
    //     TableHeadersRow();
        
    //     for virtual_members {
    //         TableTreeNodeAny(it.name, it.value);
    //     }
    //     EndTable();
    // }
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


/*
    Flood fill takes some optional parameters so that flood fill can act based on a few different parameters.
    We can require a match on the tile id or group id, and restrict the flood fill by some bounding area (typically defined by the rectangle select tool).
*/
flood_fill :: (tilemap: *Tilemap, tile_to_place: Tile, index: Vec2i, tile_id: *Tile_ID = null, group_id: *int = null, bounding_box: *Rect = null) {
    tile_at_index := get_tile(tilemap, index);
    if !tile_at_index  return;
    
    info_at_index := get_tile_info(tile_at_index);
    if !info_at_index  return;
    
    info_to_place := get_tile_info(tile_to_place);
    if !info_to_place  return;
    
    // we don't fill the tile if the tile/group id to match does not match the current tile or the tile to be placed already matches
    if tile_id  && (tile_at_index.id       != tile_id.*  || tile_at_index.id       == tile_to_place.id      ) return;
    if group_id && (info_at_index.group_id != group_id.* || info_at_index.group_id == info_to_place.group_id) return;
    
    tile_at_index.* = tile_to_place;
    
    // if current index is outside the bounding area, we should not fill neighbors  inside the bounding area
    // if current index is inside  the bounding area, we should not fill neighbors outside the bounding area
    tile_at_index_is_inside := bounding_box && is_point_within_rect(index, bounding_box.*);
    
    for dir: Direction.[ .U, .D, .L, .R ] {
        neighbor_index := index + direction_vec2i[dir];
        
        neighbor_is_inside := bounding_box && is_point_within_rect(neighbor_index, bounding_box.*);
        if neighbor_is_inside == tile_at_index_is_inside {
            flood_fill(tilemap, tile_to_place, neighbor_index, tile_id, group_id, bounding_box);
        }
    }
}



/*
    Implementing Editor Undo
    
    For every substantive change that the user can make to a level,
    we should be able to undo that change with an undo button.
    
    But there is a lot to consider here while implementing this.
    
    The first goal will probably just be to implement a basic Undo buffer for tilemaps
    each tilemap should probably have its own undo buffer, so that we can undo changes to only specific tilemaps
    this should be a relatively simple
    
    what about redo?
    
*/
// Editor_Undo_Buffer :: struct {
    
    
    
    
//     Entry :: struct {

//     }
// }

/*
    Recording changes to a tilemap
    
    Instead of recording every single tile placed as an individial action, 
    it would make for a nicer user experience is we record edits in terms of brush strokes.
    
    so for example, on mousedown we initiate a pending tilemap edit, append all the affected tiles, and then on mouseup we commit the edit
    
*/
// Tilemap_Edit :: struct {
//     kind:                           Kind;
//     brush_tile:                     Tile;
//     affected_indices:               [] Vec2f;
//     affected_indices_prior_state:   [] Vec2f;
    
//     Kind :: enum {
//         PLACE_TILE;
//         FLOOD_FILL_TILES;
//         REMOVE_TILE;
//     }
// }

// Pending_Tilemap_Edit :: struct {
//     kind:               Tilemap_Edit.Kind;
//     affected_indices:   [..] Vec2f;
// }


// begin_tilemap_edit :: (kind: Tilemap_Edit) {
//     if pending_tilemap_edit
// }



