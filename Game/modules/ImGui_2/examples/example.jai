// Test using ImGui on top of jai modules, eg Window_Creation, Simp, Input, etc.
// 
// To compile on android use jai imgui_jai_modules.jai -plug Toolchains/Android [-arm64]
// 

// @TODO:
// - Remove need for overriding input handler. Currently needed because of IMGUI_HANDLE_INPUT_MODULE_EVENTS. I think the Input module now does all event procesing needed and I just need to write the Input.Event -> ImGui event code then can get rid of the seprate platform "backends" :ImguiInputHandling
// - Get rid of backends and just have some code in module that lets you easily integrate imgui into a jai app, ie using the above Input handling code, and stuff for graphics etc.

my_window: Window_Type;
window_width  : s32 = 1920;
window_height : s32 = 1080;

image_test: Simp.Texture;

#import "Window_Creation";

//~
// ImGui
// This began as being largely copied from imgui-1.89.6/examples/example_win32_opengl3

ImGui :: #import "ImGui"()(USE_JAI_BACKEND = OS == .LINUX); // @TODO: Switch Window/Android to use this too

slider_progress := 0.;
counter := 0;
clear_color := ImGui.ImVec4.{0.15, 0.08, 0.08, 1.00};

show_demo_window := true;
show_another_window := false;

text_input_buffer: [256] u8;

text_to_draw := "Simp!";

// NOTE(Charles): ImGui "backends".
// Originally I was just #load ing the imgui "backends" I made, in similar way to the backends provided in c++ are expected
// to be used. #loading from this module isn't a great idea though, so I also converted them to be importable.
// I'm not sure this is good! The code is useful as a "just copy into your project and modify", but providing them it as 
// modules needs some work.

// Eg, both of these work.
#load "backends/imgui_impl_opengl3.jai";
// #import "ImGui/examples/backends/imgui_impl_opengl3";

USE_INPUT :: true;
#if USE_INPUT {
    Input :: #import "Input";
    #load "backends/imgui_impl_modules_input.jai";
}

#if OS == .WINDOWS {
    #load "backends/imgui_impl_win32.jai";

    #if !USE_INPUT {
        // You can't ifdef #add_context. If you want to conditionally add stuff to context, it has to be in a separate
        // file!
        #load "backends/imgui_impl_win32_window_proc.jai";
    }
}

#if OS == .ANDROID  #load "backends/imgui_impl_android.jai";

// @TODO(Charles): When Simp has a vulkan backend, make this example use either.
// Graphics_Backend :: enum {
//     OPENGL;
//     VULKAN;
// }
// GRAPHICS_BACKEND :: Graphics_Backend.OPENGL;

using Simp  :: #import "Simp";

// NOTE(Charles): modules/Input has some rudimentary handling of input on android. It treats touch input as mouse
// movement and left clicks.
// I hacked a few things together so this works with ImGui touch input, but when it came to keyboard input
// I decided to just use a port of the android input handling from example code.
// @Incomplete: Integrate this better event handling back into modules/Input
IMGUI_HANDLE_INPUT_MODULE_EVENTS :: OS != .ANDROID; // :AndroidMainWaitingOnImGuiInputHandling

// Avoid having to duplicate assets from simp example, and manage putting them on android device.
USE_ASSETS :: false;

imgui_init :: (window: Window_Type) {
    ImGui.IMGUI_CHECKVERSION();
    ImGui.CreateContext();
    io := ImGui.GetIO();
    // io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;   // Enable Keyboard Controls
    // io.ConfigFlags |= ImGuiConfigFlags_NavEnableGamepad;    // Enable Gamepad Controls

    // Setup Dear ImGui style
    ImGui.StyleColorsDark();
    //ImGui.StyleColorsClassic();

    // Setup Platform/Renderer backends
    #if OS == .WINDOWS {
        ImGui_ImplWin32_Init(xx window);
    } else #if OS == .LINUX {
        ImGui.ImGui_ImplJai_Init(window);
    } else #if OS == .ANDROID {
        // @TODO: Handle app going in/out of focus. Atm we only init on first startup.
        assert(android_app != null);
        ImGui_ImplAndroid_Init(android_app);

        // We load the default font with increased size to improve readability on many devices with "high" DPI.
        font_cfg: ImGui.ImFontConfig;
        ImGui.ImFontConfig.Constructor(*font_cfg);
        font_cfg.SizePixels = 22.;
        io.Fonts.AddFontDefault(io.Fonts, *font_cfg);

        // Arbitrary scale-up
        style := ImGui.GetStyle();
        style.ScaleAllSizes(style, 3.);
    } else {
        assert(false, "OS == % not supported", OS);
    }

    ImGui_ImplOpenGL3_Init();
}

imgui_update :: () {
    io := ImGui.GetIO();

    #if OS == .ANDROID {
        // Open on-screen (soft) input if requested by Dear ImGui
        if io.WantTextInput && !imgui_want_text_input_last  Input.android_show_software_keyboard();
        imgui_want_text_input_last = io.WantTextInput;
    }

    // Start the Dear ImGui frame
    ImGui_ImplOpenGL3_NewFrame();
         #if OS == .WINDOWS ImGui_ImplWin32_NewFrame();
    else #if OS == .ANDROID ImGui_ImplAndroid_NewFrame();
    else #if OS == .LINUX   ImGui.ImGui_ImplJai_NewFrame();
    ImGui.NewFrame();

    // 1. Show the big demo window (Most of the sample code is in ImGui::ShowDemoWindow()! You can browse its code to learn more about Dear ImGui!).
    if show_demo_window  ImGui.ShowDemoWindow(*show_demo_window);

    // 2. Show a simple window that we create ourselves. We use a Begin/End pair to create a named window.
    {
        ImGui.Begin("Hello, world!");                          // Create a window called "Hello, world!" and append into it.

        input_text_flags := ImGui.InputTextFlags.EnterReturnsTrue | .EscapeClearsAll;
        if ImGui.InputText("Test Input", text_input_buffer.data, text_input_buffer.count, input_text_flags) {
            text_to_draw = to_string(text_input_buffer.data);
        }

        ImGui.Text("This is some useful text.");               // Display some text (you can use a format strings too)
        ImGui.Checkbox("Demo Window", *show_demo_window);      // Edit bools storing our window open/close state
        ImGui.Checkbox("Another Window", *show_another_window);

        ImGui.SliderFloat("float", *slider_progress, 0., 1.);   // Edit 1 float using a slider from 0.0f to 1.0f
        ImGui.ColorEdit3("clear color", *clear_color.xyz.component);  // Edit 3 floats representing a color

        if ImGui.Button("Button")  counter += 1;                // Buttons return true when clicked (most widgets return true when edited/activated)
            
        ImGui.SameLine();
        ImGui.Text("counter = %", counter);

        ImGui.Text("Application average % ms/frame (% FPS)", formatFloat(1000. / io.Framerate, trailing_width=3), formatFloat(io.Framerate, trailing_width=1));
        
        ImGui.End();
    }

    // 3. Show another simple window.
    if show_another_window {
        ImGui.Begin("Another Window", *show_another_window);   // Pass a pointer to our bool variable (the window will have a closing button that will clear the bool when clicked)
        ImGui.Text("Hello from another window!");
        if ImGui.Button("Close Me")  show_another_window = false;
        ImGui.End();
    }
}

imgui_render :: () {
    ImGui.Render();
    ImGui_ImplOpenGL3_RenderDrawData(ImGui.GetDrawData());
}

// @TODO: Is any of this stuff useful? Doesn't look like it. Well on android we would need to do stuff here
// to handle app going in/out of focus!
imgui_deinit :: () {
    // Deletes buffers (eg vbo), and shader program and font textures. Shouldn't be necessary for windows, will maybe
    // be necessary for android focus switching?
    // ImGui_ImplOpenGL3_Shutdown(); 

    // Doesn't look like it does anything worthwhile.
    // ImGui_ImplWin32_Shutdown();

    ImGui.DestroyContext();

    // Don't think this stuff matters.
    // CleanupDeviceWGL(hwnd, &g_MainWindow);
    // wglDeleteContext(g_hRC);
    // ::DestroyWindow(hwnd);
    // ::UnregisterClassW(wc.lpszClassName, wc.hInstance);
}

main :: () {
    #if OS == .WINDOWS {
        Windows :: #import "Windows";
        Windows.SetProcessDPIAware();

        // Windows is very bad at thread-switching by default unless you do this. Sad.
        Windows.timeBeginPeriod(1);
    }

    #if OS == .ANDROID {
        // :ImguiInputHandling

        android_handle_input :: (app: *Android_App, event: *AInputEvent) -> (s32) #c_call {
            context_pointer := cast(*Context) app.userData;
            push_context <<context_pointer {
                #if IMGUI_HANDLE_INPUT_MODULE_EVENTS {
                    result := Input.android_handle_input_event(event); // Forward to Input module
                } else {
                    result := ImGui_ImplAndroid_HandleInputEvent(event);
                }
                return cast(s32) result;
            }
        }

        android_app.onInputEvent = android_handle_input;
    }

    WANTED_MSAA :: 8;
    // On Linux, we need to pass the MSAA value to create_window
    my_window = create_window(window_width, window_height, "A Window", wanted_msaa = WANTED_MSAA);

    // On other operating systems, the MSAA value needs to be passed to *_create_context, so we
    // need to have an extra step here if you want MSAA.
    msaa := Simp.prepare_window(my_window, wanted_msaa = WANTED_MSAA);
    log("Wanted MSAA: %\nChosen MSAA: %", WANTED_MSAA, msaa);

    // Actual render size in pixels can be different from the window dimensions we specified above (for example on high-resolution displays on macOS/iOS).
    window_width, window_height = Simp.get_render_dimensions(my_window);

    Simp.set_render_target(my_window, .LEFT_HANDED);

    #if USE_ASSETS {
        my_init_fonts();
        success := Simp.texture_load_from_file(*image_test, "image_test.jpg");
        assert(success);
    }

    imgui_init(my_window);

    quit := false;
    while !quit {
        #if USE_INPUT {
            Input.update_window_events();

            for Input.get_window_resizes() {
                handle_window_resize(it.window, it.width, it.height);
            }

            #if IMGUI_HANDLE_INPUT_MODULE_EVENTS  imgui_handle_input_events(Input.events_this_frame);

            for Input.events_this_frame {
                if it.type == .QUIT then quit = true;

                // if imgui_handle_input_event(it)  break;

                if it.type == {
                  case .KEYBOARD;
                    if it.key_pressed && it.key_code == .ESCAPE {
                        quit = true;
                    }
                }
            }
        }

        imgui_update();

        draw_one_frame();

        sleep_milliseconds(10);
        reset_temporary_storage();
    }

    imgui_deinit();
}

handle_window_resize :: (window: Window_Type, width: s32, height: s32) {
    Simp.update_window(window);  // Simp will do nothing if it doesn't care about this window.

    if window == my_window {
        should_reinit := (width != window_width) || (height != window_height);

        window_width  = width;
        window_height = height;

        #if USE_ASSETS if should_reinit my_init_fonts();  // Resize the font for the new window size.
    }
}

draw_one_frame :: () {
    // Simp.clear_render_target(.15, .08, .08, 1);
    Simp.clear_render_target(clear_color.x, clear_color.y, clear_color.z, 1);

    // @Tmp draw mouse location
    #if false 
    {
        SIZE :: 50.;
        center := ImGui.GetMousePos();
        // print("mouse pos == %\n", center);
        // center := Vector2.{touch_x_f, touch_y_f};
        p0 := center - Vector2.{SIZE / 2, SIZE / 2};
        p1 := center + Vector2.{SIZE / 2, SIZE / 2};
        Simp.set_shader_for_color();
        Simp.immediate_quad(p0.x, p0.y, p1.x, p1.y, Vector4.{1., 1., 0., 0.});
        Simp.immediate_flush();
    }

    Simp.set_shader_for_color();

    time := seconds_since_init();

    // This is our own code to set up a rotating square:
    {
        b := cast(float)window_height / 10;
        p: Vector2;
        p.x = cast(float)(window_width  / 2);
        p.y = cast(float)(window_height / 2);

        theta := cast(float) fmod_cycling(time, TAU);

        ct := cos(theta);
        st := sin(theta);

        w := Vector2.{b*ct, b*st};
        h := Vector2.{b*st, -b*ct};

        p0 := p - w - h;
        p1 := p + w - h;
        p2 := p + w + h;
        p3 := p - w + h;

        a :: 1.0;
        c0 := Vector4.{1, 0, 0, a};
        c1 := Vector4.{0, 1, 0, a};
        c2 := Vector4.{0, 0, 1, a};
        c3 := Vector4.{1, 1, 1, a};

        Simp.immediate_quad(p0, p1, p2, p3, c0, c1, c2, c3);
    }

    // Draw some text.
    #if USE_ASSETS
    {
        // Do a bunch of wacky math to figure out the text color.
        theta := cast(float) fmod_cycling(time*3, TAU);

        color: Vector4;
        color.x = cos(theta)*.5+.5;
        Clamp(*color.x, 0, 1);
        color.y = 1;
        color.z = sin(theta)*-.5+.5;
        Clamp(*color.z, 0, 1);
        color.w = 1;

        // Now, to draw the text:
        // text := "Simp!";
        text := text_to_draw;

        // We could just call Simp.draw_text to draw text! But we want to know the width
        // so that we can center the text, and to find the width, we have to do all the
        // text layout. So it makes sense just to draw the prepared text after that,
        // so there's a special routine, "draw_prepared_text", that draws the thing
        // you just prepared and got the width of.

        text_width := Simp.prepare_text(my_font, text);

        text_x := (window_width - text_width) / 2;
        text_y := window_height/2 + my_font.character_height/4;

        Simp.draw_prepared_text(my_font, text_x, text_y, color);
    }

    // NOTE(Charles): This still tries to draw the image, for some reason Simp.Texture.width/height default to 1?
    if image_test.width && image_test.height {
        // Draw the texture test, to make sure
        // it comes out right-side-up.

        Simp.set_shader_for_images(*image_test);
        Simp.immediate_begin();

        w := window_height/8.0;
        y0 := cast(float) window_height;

        Simp.immediate_quad(.{0, y0-w}, .{w, y0-w}, .{w, y0}, .{0, y0});
        Simp.immediate_flush();
    }

    imgui_render();

    Simp.swap_buffers(my_window);
}

my_init_fonts :: () {
    // So that we can load our font, set to path of running executable.
    // @Incomplete: Pack a default font into Simp.

    if !working_directory_set {
        path := path_strip_filename(get_path_of_running_executable());
        set_working_directory(path);
        working_directory_set = true;
    }

    pixel_height := window_height / 24;

    // @Cleanup: Don't have path + name be separate.
    my_font = Simp.get_font_at_size(".", "OpenSans-BoldItalic.ttf", pixel_height);
    assert(my_font != null);
}

working_directory_set := false;

my_font: *Simp.Dynamic_Font;

#import "Basic";
#import "Math";
#import "System";  // For get_path_of_running_executable. @Cleanup.
#import "String";  // For path_strip_filename. @Cleanup.

#if OS == .ANDROID  #import "Android"()(main);
