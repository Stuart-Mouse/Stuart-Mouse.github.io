
/*
    IMGUI stuff
    
    only gets imported when we compile with editor enabled
    this file is really just so we can declutter main.jai and have all teh imgui stuff in one place
    and the basic wrapper procs make it so we can more easily change the backend out and such
    
    TODO: 
        see if we can implement rendering in terms of simp calls instead of open gl 3
*/


#if EDITOR_ENABLED {

show_debug_window: bool;
level_path_buf: [64] u8;

// global state for script console
console_script:         LS.Script;
console_input_buffer:   [..] u8;
// IMPORTANT NOTE: right now this also serves as the owner for 'source strings' that are referenced by the script!
prev_commands:          [..] struct { statement: string; result: string; }; 
prev_commands_index:    int;

imgui_context: *ImGuiContext;

imgui_init :: () {
    imgui_context := CreateContext();
    
    io := GetIO();
    io.ConfigFlags_ |= .DockingEnable;
    // io.ConfigFlags_ |= .ViewportsEnable;
    // io.ConfigFlags_ |= .NavEnableKeyboard;
    // io.ConfigFlags_ |= .NavEnableGamepad;
    io.FontGlobalScale = imgui_ui_scale;
    
    // ImGui_ImplWin32_Init(window);
    ImGui_ImplOpenGL3_Init();
    StyleColorsClassic();
    
    style := GetStyle();
    Style.ScaleAllSizes(style, imgui_ui_scale);
    
    LS.init_script(*console_script);
    
    LS.register_type(*console_script, "float",  float);
    LS.register_type(*console_script, "int",    int);
    LS.register_type(*console_script, "Vec2f",  Vec2f);
    LS.register_type(*console_script, "Vec2i",  Vec2i);
    
    LS.register_procedure(*console_script, "load", #bake_arguments begin_level_with_id(use_debug_spawn=true));
    LS.register_procedure(*console_script, "reset_level_cache", reset_level_cache);
    
    // LS.set_variable(*console_script, "Game", Game);
    // LS.set_variable(*console_script, "player", Game.player);
}

imgui_deinit :: () {
    io := GetIO();
    io.BackendRendererUserData = null;
    DestroyContext(imgui_context);
}

imgui_new_frame :: () {
    ImGui_ImplOpenGL3_NewFrame();
    NewFrame();
}

imgui_render :: () {
    Render();
    ImGui_ImplOpenGL3_RenderDrawData(GetDrawData());
}

// for main imgui windows
// others are implemented in editor.jai
imgui_update :: () {
    wvp := GetWindowViewport();
    DockSpaceOverViewport(viewport = wvp, flags = .PassthruCentralNode);
    
    level := context.current_level;
    
    if BeginMainMenuBar() {
        if BeginMenu("Window") {
            if MenuItem("Game")     Program_State = .GAME;
            if MenuItem("Editor")   Program_State = .EDITOR;
            if MenuItem("Console")  show_debug_window = !show_debug_window;
            EndMenu();
        }
        if BeginMenu("Load") {
            for level_file_paths {
                if MenuItem(temp_c_string(it)) {
                    if Program_State == {
                      case .GAME;
                        begin_level_with_id(it, use_debug_spawn = true);
                      case .EDITOR;
                        edit_level_with_id(it);
                    }
                }
            }
            EndMenu();
        }
        if Program_State == .EDITOR {
            if MenuItem("Auto-Tile Ruleset")  Editor.show_auto_tile_ruleset = !Editor.show_auto_tile_ruleset;
        }
        EndMainMenuBar();
    }
    
    if show_debug_window {
        if Begin("Debug", *show_debug_window) {
            Text("live entities: %", live_entities);
            Text("frame time us: %", average_frame_time);
            Text("frames/second: %", 1000000.0 / average_frame_time.(float));
            
            Text("count_hovered: %", ui_state.count_hovered);
            
            current_time_absolute := seconds_since_init().(float);
            average_update_timing := (current_time_absolute - level.start_time_absolute) / level.ticks_since_start.(float);
            Text("average_update_timing: %", average_update_timing);
            
            if CollapsingHeader("Level Files", .DefaultOpen) {
                for level_file_paths {
                    Text(it);
                }
            }
            
            if CollapsingHeader("Worldmap", .DefaultOpen) {
                using Game.worldmap;
                active_level_info := get_level_info(*Game.worldmap, Game.active_level.info_index);
                if active_level_info {
                    TreeNodeAny("active level info", active_level_info.*);
                }
                if TreeNodeEx("levels", .DefaultOpen) {
                    for *level, level_index: level_info {
                        if TreeNode(tprintc("%##%", level.name, level_index)) {
                            BulletText(level.name);
                            TreePop();
                        }
                    }
                    TreePop();
                }
            }
            
            if CollapsingHeader("Entity Templates") {
                for *entity_templates {
                    // Text(it.name);
                    Text(it.name);
                    // if TreeNode(to_c_string(*it.name)) {
                        // BulletText(level.name);
                        // TreePop();
                    // }
                    // TreeNodeAny(to_c_string(*it.name), it.*);
                }
            }
            
            if CollapsingHeader("Other") {
                ColorEdit4("Clear Color", (*render_clear_color).(*[4]float));
                ColorEdit4("Editor Grid Color", (*Editor.grid_color).(*[4]float));
            }
            
            if CollapsingHeader("Save / Load Level") {
                InputText("Level File Path", *level_path_buf[0], size_of(type_of(level_path_buf)));
                if Button("Save Level As") {
                    level_path := to_string(level_path_buf.data);
                    save_level(Editor.level.layout, level_path);
                    edit_level_with_id(level_path);
                }
                SameLine();
                if Button("Load Level") {
                    level_path := to_string(level_path_buf.data);
                    load_level(Editor.level.layout, level_path);
                    Editor.details_panel_subject = Any.{};
                }
            }

            // TreeNodeAny("player", Game.player);
        }
        End();
        
        if Begin("Console") {
            // Reserve enough left-over height for 1 separator + 1 input text
            footer_height_to_reserve := GetStyle().ItemSpacing.y + GetFrameHeightWithSpacing();
            if BeginChild("ScrollingRegion", ImVec2.{0, -footer_height_to_reserve}, .None, .HorizontalScrollbar) {
                // if (BeginPopupContextWindow())
                // {
                //     if (Selectable("Clear")) ClearLog();
                //     EndPopup();
                // }
    
                // Display every line as a separate entry so we can change their color or add custom widgets.
                // If you only want raw text you can use TextUnformatted(log.begin(), log.end());
                // NB- if you have thousands of entries this approach may be too inefficient and may require user-side clipping
                // to only process visible items. The clipper will automatically measure the height of your first item and then
                // "seek" to display only items in the visible area.
                // To use the clipper we can replace your standard loop:
                //      for (int i = 0; i < Items.Size; i++)
                //   With:
                //      ImGuiListClipper clipper;
                //      clipper.Begin(Items.Size);
                //      while (clipper.Step())
                //         for (int i = clipper.DisplayStart; i < clipper.DisplayEnd; i++)
                // - That your items are evenly spaced (same height)
                // - That you have cheap random access to your elements (you can access them given their index,
                //   without processing all the ones before)
                // You cannot this code as-is if a filter is active because it breaks the 'cheap random-access' property.
                // We would need random-access on the post-filtered list.
                // A typical application wanting coarse clipping and filtering may want to pre-compute an array of indices
                // or offsets of items that passed the filtering test, recomputing this array when user changes the filter,
                // and appending newly elements as they are inserted. This is left as a task to the user until we can manage
                // to improve this example code!
                // If your items are of variable height:
                // - Split them into same height items would be simpler and facilitate random-seeking into your list.
                // - Consider using manual call to IsRectVisible() and skipping extraneous decoration from your items.
                PushStyleVar(.ItemSpacing, ImVec2.{4, 1}); // Tighten spacing
                // if (copy_to_clipboard)
                //     LogToClipboard();
                // for (const char* item : Items)
                // {
                //     if (!Filter.PassFilter(item))
                //         continue;
    
                //     // Normally you would store more information in your item than just a string.
                //     // (e.g. make Items[] an array of structure, store color/type etc.)
                //     ImVec4 color;
                //     bool has_color = false;
                //     if (strstr(item, "[error]")) { color = ImVec4(1.0f, 0.4f, 0.4f, 1.0f); has_color = true; }
                //     else if (strncmp(item, "# ", 2) == 0) { color = ImVec4(1.0f, 0.8f, 0.6f, 1.0f); has_color = true; }
                //     if (has_color)
                //         PushStyleColor(ImGuiCol_Text, color);
                //     TextUnformatted(item);
                //     if (has_color)
                //         PopStyleColor();
                // }
                // if (copy_to_clipboard)
                //     LogFinish();
                
                for prev_commands {
                    Text(it.statement);
                    TextColored(.{0.5, 0.5, 0.5, 1.0}, "-> %", it.result);
                }
    
                // Keep up at the bottom of the scroll region if we were already at the bottom at the beginning of the frame.
                // Using a scrollbar or mouse-wheel will take away from the bottom edge.
                // if (ScrollToBottom || (AutoScroll && GetScrollY() >= GetScrollMaxY()))
                //     SetScrollHereY(1.0f);
                // ScrollToBottom = false;
    
                PopStyleVar();
            }
            EndChild();
            Separator();
            
            // input buffer
            SetNextItemWidth(-FLOAT32_MIN);
            do_execute := InputTextDynamic("input", *console_input_buffer, .EnterReturnsTrue);
            SetItemDefaultFocus();
            if do_execute {
                ImGui.SetKeyboardFocusHere(-1); // keep focus on text box after hitting enter
                input_string := to_string(console_input_buffer.data);
                if input_string {
                    // NOTE: string must be copied here because LS does not copy strings from source file
                    input_string = copy_string(input_string);
                    value, ok := LS.evaluate_statement(*console_script, input_string, store_global_declarations = true);
                    
                    result_string: string;
                    if !ok {
                        // log("Error: Failed to evaluate statement.");
                        // log(LS.format_error(console_script.error));
                        result_string = LS.format_error(*console_script, true, true);
                        LS.clear_error(*console_script);
                    } else {
                        if value.value_pointer then result_string = sprint("%", value);
                    }
                    
                    array_add(*prev_commands, .{ input_string, result_string });
                    array_reset_keeping_memory(*console_input_buffer);
                }
            }
        }
        End();
        
        if Begin("Declarations") {
            table_flags := TableFlags.BordersV | .BordersOuterH | .RowBg;
            if BeginTable("###Declarations", 3, table_flags) {
                TableSetupColumn("Name",  .NoHide);
                TableSetupColumn("Value", .NoHide);
                TableSetupColumn("Type",  .NoHide);
                // TODO: maybe flags to show if constant / malleable?
                TableHeadersRow();
                
                for level.script.global_declarations {
                    if !(it.flags & .MACRO)  continue;
                    decl_value := Any.{ it.value_type, it.value_pointer };
                    decl_name  := LS.get_declaration_name(*level.script, it);
                    TableTreeNodeAny(decl_name, decl_value);
                }
                
                // TODO: this is probably slow because we walk the entire ast to show the declarations instead of storing them in some array.
                //       but not really worried about that at the moment since scripts are intended to be small anyhow.
                walk_proc :: (script: *LS.Script, node: *LS.Node, data: *void) -> (bool, *LS.Node) {
                    if node.node_type == LS.Node_Declaration {
                        decl := node.(*LS.Node_Declaration);
                        if !(decl.flags & .MACRO)  return true, null;
                        
                        decl_value := Any.{ decl.value_type, decl.value_pointer };
                        decl_name  := LS.get_declaration_name(script, decl);
                        TableTreeNodeAny(decl_name, decl_value);
                    }
                    return true, null;
                }
                LS.walk_nodes(*level.script, xx *level.script.ast_root, walk_proc, null);
                
                EndTable();
            }
        }
        End();
        
        if Begin("External Variables") {
            table_flags := TableFlags.BordersV | .BordersOuterH | .RowBg;
            if BeginTable("###Variables", 3, table_flags) {
                TableSetupColumn("Name",  .NoHide);
                TableSetupColumn("Value", .NoHide);
                TableSetupColumn("Type",  .NoHide);
                TableHeadersRow();
                
                for level.script.variables {
                    TableTreeNodeAny(it.name, LS.get_value(it));
                }
                EndTable();
            }
        }
        End();
        
        if Begin("External Procedures") {
            table_flags := TableFlags.SizingStretchProp | .BordersV | .BordersOuterH | .RowBg;
            if BeginTable("###Procedures", 3, table_flags) {
                TableSetupColumn("Name",  .NoHide);
                TableSetupColumn("Address", .NoHide);
                TableSetupColumn("Type",  .NoHide);
                TableHeadersRow();
                
                for level.script.procedures {
                    TableNextRow(); TableNextColumn();
                    Text(it.name);
                    
                    TableNextColumn();
                    Text("%", it.pointer);
                    
                    TableNextColumn();
                    Text("%", as_type(it.proc_info));
                }
                EndTable();
            }
        }
        End();
    }
}


ImGui :: #import "ImGui";

#load "imgui_impl_opengl3.jai";
#load "imgui_impl_modules_input.jai";
// #load "imgui_impl_win32.jai";

#load "imgui_extras.jai";

#scope_file
using ImGui;

}
