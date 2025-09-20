
EDITOR_ENABLED      :: OS == .WINDOWS;
GAMEPAD_SUPPORTED   :: OS == .WINDOWS;
USING_IPROF         :: false;

#import "stb_image";
#import "String";
#import "Math";
#import "File";
#import "File_Utilities";
using Basic :: #import "Basic"()(MEMORY_DEBUGGER=true);
#import "Random";
#import "Sort";
#import "System";
using,except(next_power_of_two) Hash_Table :: #import "Hash_Table";

#import "Thread";

#import "Print_Vars";

#if GAMEPAD_SUPPORTED { #import "Gamepad"; }

Simp :: #import "My_Simp";
#import "Window_Creation";
#import "GL";

Sound_Player :: #import "Sound_Player";
Input :: #import "Input";

#import "Enumerated_Array";

#import "Utils";
LSD         :: #import "LSD";
Data_Packer :: #import "Data_Packer";
LS          :: #import "Lead_Sheets"()(DEBUG=false, USING_DYNCALL=false);


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

// #load "event.jai";
#load "slot_array.jai";
#load "static_array.jai";
#load "simple_animator.jai";
#load "collision.jai";
#load "tilemap.jai";
#load "level.jai";
#load "worldmap.jai";
#load "player.jai";

#load "entity.jai";
#load "warp.jai";

#load "particles.jai";

#load "layout.jai";
#load "editor_ui.jai";
#load "editor.jai";
#load "imgui.jai";

#poke_name LSD Static_String;


report_time_since :: inline (name: string, start: Apollo_Time) {
    end  := current_time_monotonic();
    time := end - start;
    print("'%' took % microseconds (% seconds)\n", name, to_microseconds(time), to_float64_seconds(time));
}

live_entities: int;
frame_time_us: int;

window:             Window_Type;
saved_window_info:  Saved_Window_Info;
is_fullscreen:      bool;

toggle_fullscreen :: () {
    success, width, height := toggle_fullscreen(window, !is_fullscreen, *saved_window_info);
    if success {
        is_fullscreen = !is_fullscreen;
        Simp.update_window(window);
        context.layout_context.window_size = .{ xx width, xx height };
    }
}

quit := false;

average_frame_time: int;
previous_frame_times: [PREVIOUS_FRAME_TIMES_COUNT] int;
PREVIOUS_FRAME_TIMES_COUNT :: 32;
previous_frame_times_index: int;


main :: () {
    // UA :: #import "Unmapping_Allocator";
    // context.allocator = UA.get_unmapping_allocator();
    
    defer report_memory_leaks();
    
    // Global config is loaded before even intializing our window and renderer, 
    // since it contains very basic constants like initial window size. 
    init_lsd_io_data();
    load_global_config();
    
    
    // ===================
    //      INIT SIMP
    // ===================
    
    sdl_start := current_time_monotonic();
    
    #if OS == .WINDOWS {
        Windows :: #import "Windows";
        Windows.SetProcessDPIAware();

        // Windows is very bad at thread-switching by default unless you do this. Sad.
        Windows.timeBeginPeriod(1);
    }

    WANTED_MSAA :: 8;
    // On Linux, we need to pass the MSAA value to create_window
    window = create_window(window_width, window_height, "A Window", wanted_msaa = WANTED_MSAA);

    // On other operating systems, the MSAA value needs to be passed to *_create_context, so we
    // need to have an extra step here if you want MSAA.
    msaa := Simp.prepare_window(window, wanted_msaa = WANTED_MSAA);
    log("Wanted MSAA: %\nChosen MSAA: %", WANTED_MSAA, msaa);

    // Actual render size in pixels can be different from the window dimensions we specified above (for example on high-resolution displays on macOS/iOS).
    window_width, window_height = Simp.get_render_dimensions(window);
    
    Simp.set_render_target(window, .LEFT_HANDED);
    
    #if OS == .WINDOWS  wglSwapIntervalEXT(xx vsync_enabled);
    
    
    // ====================
    //      INIT IMGUI
    // ====================
    
    #if EDITOR_ENABLED {
        // imgui_start := current_time_monotonic();
        imgui_init();
        defer imgui_deinit();
        // report_time_since("imgui_start", imgui_start);
    }
    
    // ===================================
    //      LOAD ASSETS AND GAME DATA
    // ===================================
        
    assets_start := current_time_monotonic();
    
    // load audio stuff
    audio_start := current_time_monotonic();
    audio_devices := Sound_Player.get_devices();
    print("devices: %\n", audio_devices);
    
    success := Sound_Player.sound_player_init(.{});
    assert(success);
    
    // NOTE: sounds will actually be loaded below when loading enemy and player templates
    defer {
        Sound_Player.stop_all_sounds_abruptly(0);
        free_loaded_sounds();
        Sound_Player.sound_player_shutdown();
        array_reset(*loaded_sounds);
    }
    report_time_since("loading audio", audio_start);
    
    // load textures
    // TODO: define file paths in file. can probably go in globals
    textures_start := current_time_monotonic();
    load_textures();
    defer free_textures();
    
    report_time_since("loading textures", textures_start);
    
    load_color_palette();
    defer free_color_palette();
    
    load_tileset(*Game.tileset, "data/tileset.lsd");
    load_entity_templates();
    load_player_templates();
    
    // TODO: figure out what should be the proper times/places to init player
    //       only one main init on loading save file or something and partially reinit on each level load?
    init_player(*Game.player);
    
    #if EDITOR_ENABLED {
        init_editor();
        defer {
            deinit_level(Editor.level);
            // save_autotile_ruleset();
        }
    }
    
    load_worldmap("data/worldmap.lsd");
    load_map_csv(*Game.worldmap.map_data, "data/map.csv");
    
    scan_for_level_files("data/levels");
    
    if !begin_level_with_id(default_level_path) {
        // copy_editor_level_to_active_level();
        deinit_level(*Game.active_level.layout);
        init_empty_level(*Game.active_level.layout);
    }
    
    defer {
        deinit_level(*Game.active_level.layout);
        for Game.loaded_level_layouts {
            free(it_index);
            deinit_level(it);
        }
    }
    
    report_time_since("assets_start", assets_start);
    
    #if USING_IPROF  init_iprof();
    
    #if GAMEPAD_SUPPORTED { init_gamepad(); }
    
    Game.last_update_time = current_time_monotonic();
    Game.last_render_time = current_time_monotonic();
    
    context.layout_context = .{
        base_unit   = 1,
        tile_unit   = tile_render_unit,
        window_size = .{ xx window_width, xx window_height },
    };
    
    // ===================
    //      MAIN LOOP
    // ===================
    
    while !quit {
        frame_start := current_time_monotonic();
        
        reset_temporary_storage();
        
        for Input.get_window_resizes() {
            Simp.update_window(it.window);
            if it.window == window {
                window_width  = it.width;
                window_height = it.height;
                
                context.layout_context.window_size = .{ xx window_width, xx window_height };
            }
        }
        
        #if EDITOR_ENABLED { imgui_new_frame(); }
        
        render_set_viewport();
        render_clear();
        Simp.set_shader_for_color();
        
        #if EDITOR_ENABLED { imgui_update(); }
        
        if Program_State == {
          case .GAME;
            update_game();
            render_game();

          case .EDITOR;
            #if EDITOR_ENABLED {
                update_editor();
                render_editor();
            } else {
                Program_State = .GAME;
            }
        }
        
        #if EDITOR_ENABLED { imgui_render(); }
        
        #if USING_IPROF {
            if editor_controller.SHOW_IPROF.state == .PRESSED {
                show_iprof = !show_iprof;
            }
            if show_iprof {
                __Iprof.set_cursor_screen_coordinates(mouse_position().x, mouse_position().y);
                __Iprof.graph_select_sample();
                __Iprof.update(true);
                
                render_begin_batch();
                render_set_viewport(null);
                __Iprof.draw(10, 20, 600, window_height - 40.0, *iprof_config,, temp);
                __Iprof.draw_graph(620, 420, 600, 400, *iprof_config,, temp);
                render_end_batch();
                render_flush();
            }
        }
        
        Simp.swap_buffers(window, vsync_enabled.(bool));
        Sound_Player.update();
        
        {   // measuring average frame time
            frame_time := current_time_monotonic() - frame_start;
            frame_time_us = to_microseconds(frame_time);
            
            previous_frame_times[previous_frame_times_index] = frame_time_us;
            previous_frame_times_index += 1;
            previous_frame_times_index %= PREVIOUS_FRAME_TIMES_COUNT;
            
            average_frame_time = 0;
            for previous_frame_times  average_frame_time += it;
            average_frame_time /= PREVIOUS_FRAME_TIMES_COUNT;
        }
    }
}


init_lsd_io_data :: () {
    color_palette_bind_proc :: (a: Any) -> Any { 
        member, offset := get_field(xx Color_Animation, "frames");
        return Any.{ member.type, a.value_pointer + offset };
    } @NoProfile;
    
    LSD.add_io_data(Color_Animation, .{
        name_member = get_field(xx Color_Animation, "name"),
        bind_proc = color_palette_bind_proc
    });
    
    LSD.add_io_data(Player_Template, .{
        name_member = get_field(xx Player_Template, "name"),
    });
    
    LSD.add_io_data(Entity_Template, .{
        name_member = get_field(xx Entity_Template, "name"),
    });
    
    LSD.add_io_data(Level_Info, .{
        name_member = get_field(xx Level_Info, "id"),
    });
    
    palette_id_parse_proc :: (a: Any, s: string) -> bool { 
        any_isa(Palette_ID, a).* = get_color_animation_index(s);
        return true;
    } @NoProfile;
    
    LSD.add_io_data(Palette_ID, .{
        parse_proc = palette_id_parse_proc,
    });
    
    sound_id_parse_proc :: (a: Any, s: string) -> bool { 
        any_isa(Sound_ID, a).* = load_sound(join("data/", s,, temp));
        return true;
    } @NoProfile;
    
    LSD.add_io_data(Sound_ID, .{
        parse_proc = sound_id_parse_proc,
    });
    
    static_string_parse_proc :: (a: Any, s: string) -> bool { 
        capacity     := infer_static_string_capacity_from_runtime_size(a.type.runtime_size);
        _, data_any  := get_member(a, "data" );
        _, count_any := get_member(a, "count");
        data_ptr     := data_any.value_pointer.(*u8);
        count_ptr    := count_any.value_pointer.(*int);
        
        if s.count >= capacity {
            return false;
        }
        count_ptr.* = s.count;
        memcpy(data_ptr, s.data, s.count);
        data_ptr[s.count] = 0;
        return true;
    } @NoProfile;
    
    LSD.add_io_data(type_info(Static_String(0)).polymorph_source_struct, .{
        parse_proc = static_string_parse_proc,
    });
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

