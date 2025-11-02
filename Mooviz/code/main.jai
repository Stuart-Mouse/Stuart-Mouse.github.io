my_window: Window_Type;
window_width  : s32 = 1920;
window_height : s32 = 1080;

image_test: Simp.Texture;

screenshot_index := 0;

main :: () {
    #if OS == .WINDOWS {
        Windows :: #import "Windows";
        Windows.SetProcessDPIAware();

        // Windows is very bad at thread-switching by default unless you do this. Sad.
        Windows.timeBeginPeriod(1);
    }

    WANTED_MSAA :: 8;
    // On Linux, we need to pass the MSAA value to create_window
    my_window = create_window(window_width, window_height, "Mooviz", wanted_msaa = WANTED_MSAA);

    // On other operating systems, the MSAA value needs to be passed to *_create_context, so we
    // need to have an extra step here if you want MSAA.
    msaa := Simp.prepare_window(my_window, wanted_msaa = WANTED_MSAA);
    log("Wanted MSAA: %\nChosen MSAA: %", WANTED_MSAA, msaa);

    // Actual render size in pixels can be different from the window dimensions we specified above (for example on high-resolution displays on macOS/iOS).
    window_width, window_height = Simp.get_render_dimensions(my_window);

    Simp.set_render_target(my_window, .LEFT_HANDED);

    // my_init_fonts();
    // success := Simp.texture_load_from_file(*image_test, "image_test.jpg");
    // assert(success);
    
    load_script(*main_scene, script_source_path);

    quit := false;
    want_screenshot := false;
    while !quit {
        Input.update_window_events();

        for Input.get_window_resizes() {
            Simp.update_window(it.window);  // Simp will do nothing if it doesn't care about this window.

            if it.window == my_window {
                should_reinit := (it.width != window_width) || (it.height != window_height);

                window_width  = it.width;
                window_height = it.height;

                // if should_reinit my_init_fonts();  // Resize the font for the new window size.
            }
        }

        for Input.events_this_frame {
            if it.type == .QUIT then quit = true;

            if it.type == {
              case .KEYBOARD;
                if it.key_pressed {
                    if it.key_code == {
                      case .ESCAPE;  
                        quit = true;
                        
                      case .F1;
                        load_script(*main_scene, script_source_path);
                    }
                }
            }
        }

        draw_one_frame();

        sleep_milliseconds(10);
        reset_temporary_storage();
    }
}

draw_one_frame :: () {
    Simp.clear_render_target(.15, .08, .08, 1);

    Simp.set_shader_for_color();

    time := seconds_since_init().(float);
    
    main_scene.time_since_init = (time - main_scene.init_time);
    
    execute_script(*main_scene);
    for main_scene.viz_points {
        draw_square(it.position, it.size.x, it.rotation, it.color);
    }
    
    Simp.swap_buffers(my_window);
}

// my_init_fonts :: () {
//     // So that we can load our font, set to path of running executable.
//     // @Incomplete: Pack a default font into Simp.

//     if !working_directory_set {
//         // path := path_strip_filename(get_path_of_running_executable());
//         // set_working_directory(path);
//         working_directory_set = true;
//     }

//     pixel_height := window_height / 24;

//     // @Cleanup: Don't have path + name be separate.
//     my_font = Simp.get_font_at_size(".", "data/OpenSans-BoldItalic.ttf", pixel_height);
//     // assert(my_font != null);
// }

working_directory_set := false;

my_font: *Simp.Dynamic_Font;

Simp  :: #import "Simp";
Input :: #import "Input";

#import "Window_Creation";

#import "Basic";
#import "Math";
#import "File";

// #run {
//     #if OS == .WINDOWS {
//         WR :: #import "Windows_Resources";
//         WR.disable_runtime_console();
//     }
// }


#load "draw.jai";
#load "utils.jai";
#load "engine.jai";

LS :: #import "Lead_Sheets"()(DEBUG=false,USING_DYNCALL=false);
