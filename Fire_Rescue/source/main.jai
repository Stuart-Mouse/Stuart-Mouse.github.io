#import "stb_image";
#import "String";
#import "Math";
#import "File";
#import "Basic"()(MEMORY_DEBUGGER=true);
#import "Random";
#import "Sort";
#import "System";
#import "Flat_Pool";
// #import "Gamepad";
#import "Print_Vars";

using,except(next_power_of_two) Hash_Table :: #import "Hash_Table";

Simp :: #import "Simp";
#import "Window_Creation";

Sound_Player :: #import "Sound_Player";
Input :: #import "Input";

#import "Enumerated_Array"; // Credit: Rezich

#import "Utils";
LS          :: #import "Lead_Sheets"()(DEBUG=false, USING_DYNCALL=false);
LSD         :: #import "LSD";
Data_Packer :: #import "Data_Packer";


#load "globals.jai";
#load "game.jai";
#load "rect.jai";
#load "directions.jai";
#load "vector.jai";
#load "input.jai";
#load "fixed_array.jai"; // TODO: create a module for this

#load "utility.jai";

#load "render.jai";
#load "color.jai";
#load "texture.jai";
#load "texture_atlas.jai";

#load "sound.jai";

#load "slot_array.jai";
#load "simple_animator.jai";  // TODO: module
#load "collision.jai";
#load "decoration.jai";
#load "particles.jai";


window: Window_Type;
quit := false;

default_font: *Simp.Dynamic_Font;

do_manual_timing := true;

VERSION :: "3";

main :: () {
    // UA :: #import "Unmapping_Allocator";
    // context.allocator = UA.get_unmapping_allocator();
    
    // defer report_memory_leaks();
    
    log("VERSION: %", VERSION);
    
    init_gon_io_data();
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
    audio_devices := Sound_Player.get_devices();
    print("devices: %\n", audio_devices);
    
    success := Sound_Player.sound_player_init(.{});
    assert(success);
    
    // NOTE: sounds will actually be loaded below when loading enemy and player templates
    defer {
        free_loaded_sounds();
        Sound_Player.sound_player_shutdown();
    }
    
    // TODO: should use a proper font instead of 8x8 text
    // load global textures
    Simp.texture_load_from_file(*small_text_texture, "data/textures/8x8_text.png");
    defer {
        Simp.texture_destroy(*small_text_texture);
    }
    
    render_init();  defer render_deinit();
    
    // init_gamepad();
    
    init_fonts();
    
    // ===================
    //      MAIN LOOP
    // ===================
    
    init_game();
    start_game();
    
    while !quit {
        reset_temporary_storage();
        
        if Game.pending_reload {
            deinit_game();
            init_game();
            start_game();
        }
        
        for Input.get_window_resizes() {
            Simp.update_window(it.window);  // Simp will do nothing if it doesn't care about this window.
            
            if it.window == window {
                window_width  = it.width;
                window_height = it.height;
                
                handle_window_resize_for_game();
                
                should_reinit_fonts := (it.width != window_width) || (it.height != window_height);
                if should_reinit_fonts init_fonts();  // Resize the font for the new window size.
            }
        }
        
        update_game();
        render_game();
        
        Sound_Player.update(); 
        Simp.swap_buffers(window);
    }
}

init_fonts :: () {
    pixel_height := window_height / 24;
    
    // @Cleanup: Don't have path + name be separate.
    default_font = Simp.get_font_at_size(".", "data/OpenSans-BoldItalic.ttf", pixel_height);
    assert(default_font != null);
}

init_gon_io_data :: () {
    LSD.add_io_data(Guy_Template, .{
        name_member = get_field(xx Guy_Template, "name"),
    });
    
    LSD.add_io_data(Decoration, .{
        name_member = get_field(xx Decoration, "name"),
    });
}

// show_debug_window: bool;
// level_path_buf: [64] u8;

// // global state for script console
// console_input_buffer:   [..] u8;
// // IMPORTANT NOTE: right now this also serves as the owner for 'source strings' that are referenced by the script!
// prev_commands:          [..] struct { statement: string; result: string; }; 
// prev_commands_index:    int;

