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

#load "sound.jai";

#load "slot_array.jai";
#load "simple_animator.jai";
#load "collision.jai";
#load "particles.jai";


window: Window_Type;
quit := false;

do_manual_timing := false;

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
    
    load_global_config();
    
    // =============================
    //      INIT SDL AND OPENGL
    // =============================
    
    #if OS == .WINDOWS {
        Windows :: #import "Windows";
        Windows.SetProcessDPIAware();

        // Windows is very bad at thread-switching by default unless you do this. Sad.
        Windows.timeBeginPeriod(1);
    }

    WANTED_MSAA :: 8;
    // On Linux, we need to pass the MSAA value to create_window
    window = create_window(window_width, window_height, "Fire", wanted_msaa = WANTED_MSAA);

    // On other operating systems, the MSAA value needs to be passed to *_create_context, so we
    // need to have an extra step here if you want MSAA.
    msaa := Simp.prepare_window(window, wanted_msaa = WANTED_MSAA);
    log("Wanted MSAA: %\nChosen MSAA: %", WANTED_MSAA, msaa);

    // Actual render size in pixels can be different from the window dimensions we specified above (for example on high-resolution displays on macOS/iOS).
    window_width, window_height = Simp.get_render_dimensions(window);

    Simp.set_render_target(window, .LEFT_HANDED);

    // ===================================
    //      LOAD ASSETS AND GAME DATA
    // ===================================
    
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
    
    Simp.texture_load_from_file(*small_text_texture, "data/8x8_text.png");
    defer {
        Simp.texture_destroy(*small_text_texture);
    }
    
    render_init();  defer render_deinit();
    
    // init_gamepad();
        
    // ===================
    //      MAIN LOOP
    // ===================
    
    init_game();
    start_game();
    
    while !quit {
        reset_temporary_storage();
        
        for Input.get_window_resizes() {
            Simp.update_window(it.window);  // Simp will do nothing if it doesn't care about this window.

            if it.window == window {
                // should_reinit := (it.width != window_width) || (it.height != window_height);

                window_width  = it.width;
                window_height = it.height;

                // if should_reinit my_init_fonts();  // Resize the font for the new window size.
            }
        }
        
        update_mouse();
        
        update_game();
        render_game();
        
        Simp.swap_buffers(window);
        // Sound_Player.update(); 
    }
}

init_gon_io_data :: () {
    
}


show_debug_window: bool;
level_path_buf: [64] u8;


// global state for script console
console_input_buffer:   [..] u8;
// IMPORTANT NOTE: right now this also serves as the owner for 'source strings' that are referenced by the script!
prev_commands:          [..] struct { statement: string; result: string; }; 
prev_commands_index:    int;
