#import "stb_image";
#import "String";
#import "Math";
#import "File";
#import "Basic"()();
#import "Random";
#import "Sort";
#import "System";
// #import "Gamepad";
using,except(next_power_of_two) Hash_Table :: #import "Hash_Table";

Simp :: #import "Simp";
#import "Window_Creation";
#import "GL";

// Sound_Player :: #import "Sound_Player";
Input :: #import "Input";

#import "Enumerated_Array";

#import "Utils";
LSD         :: #import "LSD";
Data_Packer :: #import "Data_Packer";
LS          :: #import "Lead_Sheets"()(DEBUG=false, USING_DYNCALL=false);


// #load "imgui_sdl_gl_docking.jai";
// imgui :: ImGui;

#load "globals.jai";
#load "game.jai";
#load "rect.jai";
#load "directions.jai";
#load "vector.jai";
#load "input.jai";

#load "utility.jai";

#load "render.jai";
#load "color.jai";
#load "texture.jai";
#load "colormap.jai";

#load "sound.jai";

#load "editor_ui.jai";
#load "event.jai";
#load "slot_array.jai";
#load "simple_animator.jai";
#load "collision.jai";
#load "tilemap.jai";
#load "level.jai";
#load "worldmap.jai";
#load "player.jai";
#load "editor.jai";

#load "entity.jai";
#load "enemy.jai";
#load "fire_bar.jai";
#load "warp.jai";
#load "item.jai";

#load "particles.jai";

ImGui :: #import "ImGui";
imgui :: ImGui;
#load "imgui_impl_opengl3.jai";
#load "imgui_impl_modules_input.jai";
// #load "imgui_impl_win32.jai";
#load "imgui_extras.jai";

USING_IPROF :: false;

report_time_since :: inline (name: string, start: Apollo_Time) {
    end  := current_time_monotonic();
    time := end-start;
    print("'%' took % microseconds (% seconds)\n", name, to_microseconds(time), to_float64_seconds(time));
}

live_entities: int;
frame_time_us: int;

window: Window_Type;

quit := false;

average_frame_time: int;
previous_frame_times: [PREVIOUS_FRAME_TIMES_COUNT] int;
PREVIOUS_FRAME_TIMES_COUNT :: 32;
previous_frame_times_index: int;

do_manual_timing := true;

main :: () {
    // UA :: #import "Unmapping_Allocator";
    // context.allocator = UA.get_unmapping_allocator();
    
    // defer report_memory_leaks();
    
    // TODO: this is really stupid. this is a hack to fix logic after moving exectuable into debug and release build folders
    executable_path = get_path_of_running_executable();
    _, executable_path = split_from_right(executable_path, #char "/");
    _, executable_path = split_from_right(executable_path, #char "/");
    executable_path = join(executable_path, "/");
    defer free(executable_path);
    
    log("executable_path: %\n", executable_path);
    
    // Global config is loaded before even intializing SDL, 
    // since it contains very basic constants like initial window size. 
    init_gon_io_data();
    load_global_config();
    
    
    
    // =============================
    //      INIT SDL AND OPENGL
    // =============================
    
    sdl_start := current_time_monotonic();
    
    #if OS == .WINDOWS {
        Windows :: #import "Windows";
        Windows.SetProcessDPIAware();

        // Windows is very bad at thread-switching by default unless you do this. Sad.
        Windows.timeBeginPeriod(1);
    }

    WANTED_MSAA :: 8;
    // On Linux, we need to pass the MSAA value to create_window
    window = create_window(WINDOW_WIDTH, WINDOW_HEIGHT, "A Window", wanted_msaa = WANTED_MSAA);

    // On other operating systems, the MSAA value needs to be passed to *_create_context, so we
    // need to have an extra step here if you want MSAA.
    msaa := Simp.prepare_window(window, wanted_msaa = WANTED_MSAA);
    log("Wanted MSAA: %\nChosen MSAA: %", WANTED_MSAA, msaa);

    // Actual render size in pixels can be different from the window dimensions we specified above (for example on high-resolution displays on macOS/iOS).
    WINDOW_WIDTH, WINDOW_HEIGHT = Simp.get_render_dimensions(window);

    Simp.set_render_target(window, .LEFT_HANDED);

    
    // gl_start := current_time_monotonic();
    
    // SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    // SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 2);
    // SDL_GL_SetAttribute(SDL_GL_CONTEXT_FLAGS, xx SDL_GL_CONTEXT_FORWARD_COMPATIBLE_FLAG);
    // SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, xx SDL_GL_CONTEXT_PROFILE_CORE);
    
    // gl_context := SDL_GL_CreateContext(window);
    // if !gl_context {
    //     log_error("Could not create OpenGL context: %", to_string(SDL_GetError()));
    //     exit(1);
    // }
    // defer SDL_GL_DeleteContext(gl_context);
    
    // if SDL_GL_SetSwapInterval(-1) < 0 {
    //     if SDL_GL_SetSwapInterval(1) < 0 {
    //         do_manual_timing = true;
    //     }
    // }
    
    // // TODO: figure out how to better handle fractional values of UPDATES_PER_FRAME in update routine when vsync is enabled
    // //       I think in theory it should just work because we adjust physics accordingly, but it's not working.
    // // do_manual_timing ||= UPDATES_PER_FRAME < 1.0;
    // log("swap interval: %", SDL_GL_GetSwapInterval());
    // log("manual timing: %", do_manual_timing);
    
    
    
    // gl_load(*gl, SDL_GL_GetProcAddress);

    // glEnable(GL_TEXTURE_2D);
    // glEnable(GL_SCISSOR_TEST);
    // glEnable(GL_BLEND);
    // glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    // // glEnable(GL_DEPTH_TEST);
    // glDepthFunc(GL_GEQUAL);

    // print("gl version: %\n", to_string(glGetString(GL_VERSION)));
    
    // report_time_since("sdl_start", sdl_start);
    // report_time_since("gl_start", gl_start);

    
    // ====================
    //      INIT IMGUI
    // ====================
    
    // imgui_start := current_time_monotonic();
    
    log("imgui version: %", to_string(imgui.GetVersion()));
    imgui_context := imgui.CreateContext();
    io := imgui.GetIO();

    // io.ConfigFlags_ |= .DockingEnable;
    // io.ConfigFlags_ |= .ViewportsEnable;
    io.ConfigFlags_ |= .NavEnableKeyboard;
    // io.ConfigFlags_ |= .NavEnableGamepad;

    // ImGui_ImplWin32_Init(window);
    ImGui_ImplOpenGL3_Init();
    // ImGui_ImplSdl_Init();
    imgui.StyleColorsClassic();
    
    defer {
        // ImGui_ImplSdl_Shutdown();
        imgui.DestroyContext(imgui_context);
    }
    
    show_demo_window := false;
    
    // report_time_since("imgui_start", imgui_start);
    

    // ===================================
    //      LOAD ASSETS AND GAME DATA
    // ===================================
    
    assets_start := current_time_monotonic();
    
    // load audio stuff
    // audio_start := current_time_monotonic();
    // audio_devices := Sound_Player.get_devices();
    // print("devices: %\n", audio_devices);
    
    // success := Sound_Player.sound_player_init(.{});
    // assert(success);
    
    // // NOTE: sounds will actually be loaded below when loading enemy and player templates
    // defer {
    //     Sound_Player.stop_all_sounds_abruptly(0);
    //     free_loaded_sounds();
    //     Sound_Player.sound_player_shutdown();
    //     array_reset(*loaded_sounds);
    // }
    // report_time_since("loading audio", audio_start);
    
    // load textures
    // TODO: define file paths in file. can probably go in globals
    textures_start := current_time_monotonic();
    Simp.texture_load_from_file(*tiles_texture,         "data/gfx/blocks_colormapped.png");
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    Simp.texture_load_from_file(*plumber_texture,       "data/gfx/plumber_colormapped.png");
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    Simp.texture_load_from_file(*entities_texture,      "data/gfx/entities_colormapped.png");
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    Simp.texture_load_from_file(*particles_texture,     "data/gfx/particles_colormapped.png");
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    Simp.texture_load_from_file(*small_text_texture,    "data/gfx/8x8_text_colormapped.png");
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    Simp.texture_load_from_file(*ui_elements_texture,   "data/gfx/ui_elements_colormapped.png");
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    defer {
        Simp.texture_destroy(*tiles_texture);
        Simp.texture_destroy(*plumber_texture);
        Simp.texture_destroy(*entities_texture);
        Simp.texture_destroy(*particles_texture);
        Simp.texture_destroy(*small_text_texture);
        Simp.texture_destroy(*ui_elements_texture);
    }
    report_time_since("loading textures", textures_start);
    
    load_master_palette();
    init_color_palettes();
    defer {
        free_loaded_palettes();
        array_reset(*loaded_palettes);
    }
    
    render_start := current_time_monotonic();
    render_init();
    defer render_deinit();
    // Renderer.active_shader_program = .COLORMAP;
    report_time_since("init renderer", render_start);
    
    // TODO: define fire bar animations in a file. 
    // will need some common file for defining more global entity types such as this
    init_fire_bar_animation();
    
    load_tile_info();
    load_player_templates();
    load_enemy_templates();
    init_item_animations();
    
    init_editor();
    defer {
        save_autotile_ruleset();
    }
    
    load_worldmap("data/worldmap.gon");
    
    copy_editor_level_to_active_level();
    
    defer {
        deinit_level(*Editor.level);
        deinit_level(*Game.active_layout);
    }
    
    report_time_since("assets_start", assets_start);
    
    #if USING_IPROF  init_iprof();
    
    // init_gamepad();
    
    Game.last_update_time = current_time_monotonic();
    Game.last_render_time = current_time_monotonic();
    
    // ===================
    //      MAIN LOOP
    // ===================
    
    while !quit {
        frame_start := current_time_monotonic();
        
        reset_temporary_storage();
        
        for Input.get_window_resizes() {
            Simp.update_window(it.window);  // Simp will do nothing if it doesn't care about this window.

            if it.window == window {
                // should_reinit := (it.width != WINDOW_WIDTH) || (it.height != WINDOW_HEIGHT);

                WINDOW_WIDTH  = it.width;
                WINDOW_HEIGHT = it.height;

                // if should_reinit my_init_fonts();  // Resize the font for the new window size.
            }
        }
        
        ImGui_ImplOpenGL3_NewFrame();
        imgui.NewFrame();
        
        if show_demo_window {
            imgui.SetNextWindowPos(*(Vector2.{650, 20}), imgui.Cond.FirstUseEver, *(Vector2.{0,0})); // Normally user code doesn't need/want to call this because positions are saved in .ini file anyway. Here we just want to make the demo initial state a bit more friendly!
            imgui.ShowDemoWindow(*show_demo_window);
        }
        
        render_set_viewport();
        render_clear();
        Simp.set_shader_for_color();
        
        update_mouse();
        
        update_input_controller(editor_controller.data);
        if editor_controller[Editor_Input_Keys.SET_STATE_GAME].state == .PRESSED 
        && Program_State != .GAME {
            play_music();
            Program_State = .GAME;
        }
        if editor_controller[Editor_Input_Keys.SET_STATE_EDITOR].state == .PRESSED 
        && Program_State != .EDITOR {
            pause_music();
            Program_State = .EDITOR;
        }
        if editor_controller[Editor_Input_Keys.TOGGLE_SHOW_DEMO_WINDOW].state == .PRESSED {
            // show_demo_window = !show_demo_window;
        }
        if editor_controller[Editor_Input_Keys.TOGGLE_SHOW_DEBUG_WINDOW].state == .PRESSED {
            show_debug_window = !show_debug_window;
        }
        if editor_controller[Editor_Input_Keys.RELOAD_ASSETS].state == .PRESSED {
            load_master_palette();
            init_color_palettes();
            
            load_tile_info();
            load_player_templates();
            load_enemy_templates();
            
            copy_editor_level_to_active_level();
            print("assets reloaded\n");
        }
        
        imgui_update();
        
        if Program_State == {
          case .GAME;
            if editor_controller[Editor_Input_Keys.GAME_RESET_LEVEL].state == .PRESSED {
                copy_editor_level_to_active_level();
            }
            update_game();
            render_game();

          case .EDITOR;
            update_editor();
            render_editor();
        }
        
        // ImGui.Text("live entities: %", live_entities);
        // ImGui.Text("frame time us: %", average_frame_time);
        // ImGui.Text("frames/second: %", 1000000.0 / average_frame_time.(float));
        
        imgui.Render();
        
        ImGui_ImplOpenGL3_RenderDrawData(imgui.GetDrawData());
        // ImGui_ImplSdl_RenderDrawLists(imgui.GetDrawData());
        
        #if USING_IPROF {
            if editor_controller[Editor_Input_Keys.SHOW_IPROF].state == .PRESSED {
                show_iprof = !show_iprof;
            }
            if show_iprof {
                __Iprof.set_cursor_screen_coordinates(mouse_position().x, mouse_position().y);
                __Iprof.graph_select_sample();
                __Iprof.update(true);
                
                render_begin_batch();
                render_set_viewport(null);
                __Iprof.draw(10, 20, 600, WINDOW_HEIGHT - 40.0, *iprof_config,, temp);
                __Iprof.draw_graph(620, 420, 600, 400, *iprof_config,, temp);
                render_end_batch();
                render_flush();
            }
        }
        
        {
            frame_time := current_time_monotonic() - frame_start;
            frame_time_us = to_microseconds(frame_time);
            
            previous_frame_times[previous_frame_times_index] = frame_time_us;
            previous_frame_times_index += 1;
            previous_frame_times_index %= PREVIOUS_FRAME_TIMES_COUNT;
            
            average_frame_time = 0;
            for previous_frame_times  average_frame_time += it;
            average_frame_time /= PREVIOUS_FRAME_TIMES_COUNT;
        }
        
        Simp.swap_buffers(window);
        // Sound_Player.update(); 
    }
}


init_gon_io_data :: () {
    array_add(*context.conversion_settings.get_union_type_procs, .{ Data_Packer.resolve_union_by_internal_tag, *resolve_entity_union_data });
    
    color_palette_bind_proc :: (a: Any) -> Any { 
        member, offset := get_field(xx Animated_Color_Palette, "frames");
        return Any.{ member.type, a.value_pointer + offset };
    } @NoProfile;
    
    LSD.add_io_data(Animated_Color_Palette, .{
        name_member = get_field(xx Animated_Color_Palette, "name"),
        bind_proc = color_palette_bind_proc
    });
    
    LSD.add_io_data(Player_Template, .{
        name_member = get_field(xx Player_Template, "name"),
    });
    
    LSD.add_io_data(Level_Info, .{
        name_member = get_field(xx Level_Info, "name"),
    });
    
    LSD.add_io_data(Level_Info.Area, .{
        name_member = get_field(xx Level_Info.Area, "name"),
    });
}


show_debug_window: bool;
level_path_buf: [64] u8;


// global state for script console
console_input_buffer:   [..] u8;
// IMPORTANT NOTE: right now this also serves as the owner for 'source strings' that are referenced by the script!
prev_commands:          [..] struct { statement: string; result: string; }; 
prev_commands_index:    int;


imgui_update :: () {
    using imgui;
    
    // wvp := GetWindowViewport();
    // DockSpaceOverViewport(wvp, .PassthruCentralNode);
    
    level := context.current_level;
    
    if 1 {
        viewport: *Viewport = GetMainViewport();
        SetNextWindowPos(viewport.Pos, .Always);
        SetNextWindowSize(viewport.Size, .Always);
        
        if Begin("Debug Window", *show_debug_window) {
            Text("live entities: %", live_entities);
            Text("frame time us: %", average_frame_time);
            Text("frames/second: %", 1000000.0 / average_frame_time.(float));
            
            
            if CollapsingHeader("Worldmap", .DefaultOpen) {
                using Game.worldmap;
                Text("active level: %", active_level);
                Text("active area:  %", active_area);
                if TreeNodeEx("levels", .DefaultOpen) {
                    for *level, level_index: levels {
                        if TreeNode(tprintc("%##%", level.name, level_index)) {
                            for *area, area_index: level.areas {
                                PushID(tprintc("%", area_index));
                                BulletText("% (%)", area.name, area.layout);
                                if IsItemClicked(.Right) {
                                    begin_area(level_index, area_index);
                                }
                                PopID();
                            }
                            TreePop();
                        }
                    }
                    TreePop();
                }
            }
            
            if CollapsingHeader("Palettes") {
                ColorEdit4("Sky Color", cast(*[4]float) *Master_Palette[0x02]);
                for palette, palette_index: loaded_palettes {
                    if TreeNode(tprintc("%", palette.name)) {
                        Text("current frame: %", palette.current);
                        for frame, frame_index: palette.frames {
                            InputFloat("duration", *frame.duration);
                            for color, color_index: frame.palette {
                                // SetNextItemWidth(100);
                                // SameLine();
                                ColorEdit4(tprintc("###% %", frame_index, color_index), (*Master_Palette[color]).(*[4]float));
                            }
                            Separator();
                        }
                        TreePop();
                    }
                }
            }
            
            if CollapsingHeader("Events") {
                for level.event_queue.events {
                    if TreeNode(tprintc("% - %", it.timestamp, it.event_type)) {
                        if it.event_type == {
                          case .BLOCK_HIT; #through;
                          case .BLOCK_DESTROYED;
                            Text("tilemap_index: %", it.tile_event.tilemap_index);
                            Text("tile_index: %",    it.tile_event.tile_index);
                            // Text("tile_serial: %",   it.tile_event.tile_serial);
                        }
                        TreePop();
                    }
                }
            }

            if CollapsingHeader("Other") {
                ColorEdit4("Clear Color", (*Renderer.clear_color).(*[4]float));
                ColorEdit4("Editor Grid Color", (*Editor.grid_color).(*[4]float));
            }

            if CollapsingHeader("Save / Load Level") {
                InputText("Level File Path", *level_path_buf[0], size_of(type_of(level_path_buf)));
                if Button("Save Level") {
                    save_level(*Editor.level, to_string(level_path_buf.data));
                }
                SameLine();
                if Button("Load Level") {
                    load_level(*Editor.level, to_string(level_path_buf.data));
                    Editor.details_panel_subject = Any.{};
                }
            }

            TreeNodeAny("player", level.player);
        }
        End();
        
        #if false {
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
                str := to_string(console_input_buffer.data);
                if str {
                    // NOTE: string must be copied here because LS uses view onto source file...
                    //       we should probably have some flag that make LS copy the strings it needs from tokens into its pool!
                    str = copy_string(str);
                    value, ok := LS.evaluate_statement(*level.script, str, store_global_declarations = true);
                    if !ok {
                        log("Error: Failed to evaluate statement.");
                        log(LS.format_error(script.error));
                        script.error = .{};
                    } else {
                        result: string;
                        if value.value_pointer then result = sprint("%", value);
                        array_add(*prev_commands, .{ str, result });
                        array_reset_keeping_memory(*console_input_buffer);
                    }
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
                    decl_value := Any.{ it.value_type, it.value_pointer };
                    TableTreeNodeAny(it.name, decl_value);
                }
                
                // TODO: this is probably slow because we walk the entire ast to show the declarations instead of storing them in some array.
                //       but not really worried about that at the moment since scripts are intended to be small anyhow.
                walk_proc :: (script: *LS.Script, node: *LS.Node, data: *void) -> (bool, *LS.Node) {
                    if node.node_type == LS.Node_Declaration {
                        decl := node.(*LS.Node_Declaration);
                        decl_value := Any.{ decl.value_type, decl.value_pointer };
                        TableTreeNodeAny(decl.name, decl_value);
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
                    TableTreeNodeAny(it.name, it.binding);
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
}


#if USING_IPROF {
    // TODO: make text size and spacing configurable
    iprof_text_size    :: 8;
    iprof_text_margin  :: 4;
    iprof_line_spacing :: iprof_text_size + iprof_text_margin;
    
    show_iprof := false;
    iprof_config: __Iprof.Config;
    
    init_iprof :: () {
        draw_text :: (x: float, y: float, str: string, color: Vector4) {
            offset := Vector2.{ iprof_text_margin/2, -(iprof_text_size + iprof_text_margin/2) };
            render_small_text(str, position = offset + .{ x, y }, color = to_Color4(color));
        }
        text_width :: (s: string) -> float {
            return (s.count).(float) * 8;
        }
        draw_rectangle :: (x0: float, y0: float, x1: float, y1: float, color: Vector4) {
            render_draw_quad(position = .{ x0, y0 }, size = .{ x1-x0, y1-y0 }, to_Color4(color));
        }
        draw_line :: (p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, color: Vector4) {
            render_draw_line((p0+p1)/2, (p2+p2)/2, to_Color4(color), 1);
        }
        graph_begin :: (x: float, y: float, width: float, height: float) { }
        graph_end :: (x: float, y: float, width: float, height: float) { }
        
        iprof_config = .{
            line_spacing          = iprof_line_spacing,
            font_character_height = iprof_text_size,
            draw_text             = draw_text,
            text_width            = text_width,
            draw_rectangle        = draw_rectangle,
            draw_line             = draw_line,
            graph_begin           = graph_begin,
            graph_end             = graph_end,
        };
    }
}

