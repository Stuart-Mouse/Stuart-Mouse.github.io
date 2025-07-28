
#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#include <emscripten/html5.h>
#include <emscripten/val.h>
#include <emscripten/bind.h>
using namespace emscripten;
#endif

#include <SDL.h>
#include <SDL_ttf.h>
#include <SDL_image.h>
#include <SDL_opengles2.h>
#include <SDL_mixer.h>

#include <array>
#include <vector>
#include "math.h"

#include "structs.cpp"
#include "input.cpp"
#include "texture.cpp"

// global state for window and such
SDL_Window   *window;
SDL_Renderer *renderer;
TTF_Font     *font;
TTF_Font     *title_font;

int   canvas_width        = 720;
int   canvas_height       = 480;
float window_render_scale = 1.0;

Rect  viewport;
// float viewport_diagonal;

uint32_t g_ticks_this_frame;
uint32_t g_ticks_last_frame;

float get_canvas_aspect()   { return (float)canvas_width / (float)canvas_height; };
float get_viewport_aspect() { return (float)viewport.w   / (float)viewport.h;    };
float get_seconds_since_init() { return (float)SDL_GetTicks() / 1000.0; };
float get_delta_time() { return (float)(g_ticks_this_frame - g_ticks_last_frame) / 1000.0; };

#define PORTRAIT_ASPECT  ( 9.0 / 16.0)
#define LANDSCAPE_ASPECT (16.0 /  9.0)

// implied square resolution
#define BASE_RESOLUTION_X 720.0
#define BASE_RESOLUTION_Y 1280.0


#include "text.cpp"
#include "particles.cpp"

bool DEBUG_MODE = true;

// EM_BOOL on_web_display_size_changed(int event_type, const EmscriptenUiEvent *event, void *user_data);

EM_BOOL on_web_display_size_changed(int event_type, const EmscriptenUiEvent *event, void *user_data) {
    double w, h, is_fullscreen;
    emscripten_get_element_css_size("#canvas", &w, &h);
    canvas_width  = (int)w;
    canvas_height = (int)h;
    SDL_SetWindowSize(window, (int)w, (int)h);


    Rect canvas_rect = { 0, 0, canvas_width, canvas_height };

    // apply the viewport_internal modifier to teh window rect
    // that way, we center and scale within the region that is actually usable
    // {
    //     FRect viewport_f = to_frect(canvas_rect);

    //     viewport_f.x += viewport_f.w * viewport_internal.x;
    //     viewport_f.y += viewport_f.h * viewport_internal.y;
    //     viewport_f.w *= viewport_internal.w;
    //     viewport_f.h *= viewport_internal.h;

    //     canvas_rect = to_rect(viewport_f);
    // }
    
    viewport = canvas_rect;
    // viewport_diagonal = sqrt(viewport.x * viewport.y);
    
    // float aspect = (float)viewport.w / (float)viewport.h;
    
    // if (aspect < PORTRAIT_ASPECT) {
    //     viewport.w =  9.0;
    //     viewport.h = 16.0;
    //     center_and_scale_rect_within_rect(&viewport, &window_rect, Axis::MAJOR);
    // }
    // else if (aspect > LANDSCAPE_ASPECT) {
    //     viewport.w = 16.0;
    //     viewport.h =  9.0;
    //     center_and_scale_rect_within_rect(&viewport, &window_rect, Axis::MAJOR);
    // }

    // window_render_scale = calculate_render_scale(aspect);

    printf("updated viewport: %d, %d", w, h);

    // update on js/html side
    // char script_buffer[128]; // should be more than enough space ...?
    // sprintf(script_buffer, "update_aspect('%f')", aspect);
    // emscripten_run_script(script_buffer);

    return 0;
}

void handle_sdl_events(void) {
    SDL_Event e;
    while (SDL_PollEvent(&e) != 0) {
        switch (e.type) {
          case SDL_MOUSEWHEEL:
            mouse.wheel.x = e.wheel.x;
            mouse.wheel.y = e.wheel.y;
            mouse.wheel_updated = 1;
            break;
        }
    }
}



const char* small_text_texture_file_path = "media/8x8_text.png";

const char* particles_texture_file_path = "media/particles2.png";
Texture particles_texture;

// TODO: setup keybindings for this controller in main()
enum DEBUG_CONTROLLER {
    DEBUG_KEY_PREV_CHANNEL,
    DEBUG_KEY_NEXT_CHANNEL,

    DEBUG_KEY_COUNT
};

InputKey debug_controller[DEBUG_KEY_COUNT];

Particle_Emitter particle_emitter;

void main_loop(void* main_loop_arg) {
    g_ticks_last_frame = g_ticks_this_frame;
    g_ticks_this_frame = SDL_GetTicks();
    
    handle_sdl_events();
    update_mouse();
    
    // we shouldn't have to call this every frame, but for soem reason, the callback just isn't working...
    on_web_display_size_changed(0, 0, 0);
    
    SDL_SetRenderDrawColor(renderer, 0xe9, 0xdc, 0xcd, 0xff);
    SDL_RenderSetViewport(renderer, NULL);
    SDL_RenderClear(renderer);

    if (DEBUG_MODE) {
        update_input_controller(debug_controller, DEBUG_KEY_COUNT);
    }
    
    // spawn particles within current canvas rect
    // using absolute pixel dimensions for this application
    
    update_particle_emitter(&particle_emitter);
    render_all_particles(&particle_emitter, Vec2 { 0, 0 });
    
    SDL_RenderPresent(renderer);
}


int main(int argc, char** argv) {
    on_web_display_size_changed(0, 0, 0);
    emscripten_set_resize_callback(EMSCRIPTEN_EVENT_TARGET_WINDOW, 0, 0, on_web_display_size_changed);

    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO) < 0) {
        printf("failed to init sdl");
        return 0;
    }
    SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "1");

    int img_flags = IMG_INIT_PNG;
    if (IMG_Init(img_flags) < 0)  {
        printf("failed to init sdl image");
        return 0;
    }

    if (SDL_CreateWindowAndRenderer(canvas_width, canvas_height, SDL_WINDOW_RESIZABLE, &window, &renderer) < 0) {
        printf("failed to create window and renderer");
        return 0;
    }
    SDL_SetRenderDrawBlendMode(renderer, SDL_BLENDMODE_BLEND);

    if (TTF_Init() < 0) {
        printf("failed to init sdl ttf");
        return 0;
    }
    
    font = TTF_OpenFont("media/Lora-Regular.ttf", 64);
    
    
    
    if (!load_texture(renderer, &small_text_texture, small_text_texture_file_path)) {
        printf("failed to load texture");
    }
    SDL_SetTextureScaleMode(small_text_texture.id, SDL_ScaleModeNearest);
    
    if (!load_texture(renderer, &particles_texture, particles_texture_file_path)) {
        printf("failed to load texture");
    }
    
    init_particle_emitter(&particle_emitter, 256);
    particle_emitter.emit_box                  = FRect { 0, 0.1, 1, 1.2 };
    particle_emitter.emit_freq             [0] = 200;
    particle_emitter.emit_freq             [1] = 300;
    particle_emitter.init_velocity         [0] = Vec2 { 0, -0.02 };
    particle_emitter.init_velocity         [1] = Vec2 { 0, -0.08 };
    particle_emitter.init_acceleration     [0] = Vec2 { 0, 0 };
    particle_emitter.init_acceleration     [1] = Vec2 { 0, 0 };
    particle_emitter.init_scale            [0] = 0.02;
    particle_emitter.init_scale            [1] = 0.05;
    particle_emitter.init_rotation         [0] = 0;
    particle_emitter.init_rotation         [1] = 360;
    particle_emitter.init_angular_velocity [0] = -30;
    particle_emitter.init_angular_velocity [1] =  30;
    particle_emitter.init_lifetime         [0] = 6000;
    particle_emitter.init_lifetime         [1] = 8000;
    particle_emitter.init_color_mod        [0] = { (float)0x61/(float)0xff, (float)0x3a/(float)0xff, (float)0x43/(float)0xff, 0.8 };
    particle_emitter.init_color_mod        [1] = { (float)0x84/(float)0xff, (float)0x99/(float)0xff, (float)0x74/(float)0xff, 0.8 };
    
    particle_emitter.texture = particles_texture;
    particle_emitter.fadein_time = 0.1;
    particle_emitter.fadeout_time = 0.1;
    particle_emitter.texture_clips.insert(particle_emitter.texture_clips.end(), {
        // { 0,  0, 48, 48 },
        // { 0, 48, 48, 48 },
        
        // { 48,  0, 48, 48 },
        // { 48, 48, 48, 48 },
        
        // { 96,  0, 48, 48 },
        // { 96, 48, 48, 48 },
        
        // { 144,  0, 48, 48 },
        // { 144, 48, 48, 48 },
        
        { 0*192, 0*192, 192, 192 },
        { 1*192, 0*192, 192, 192 },
        { 2*192, 0*192, 192, 192 },
        { 3*192, 0*192, 192, 192 },
        { 4*192, 0*192, 192, 192 },
        
        { 0*192, 1*192, 192, 192 },
        { 1*192, 1*192, 192, 192 },
        { 2*192, 1*192, 192, 192 },
        { 3*192, 1*192, 192, 192 },
        
        { 0*192, 2*192, 192, 192 },
        { 1*192, 2*192, 192, 192 },
        { 2*192, 2*192, 192, 192 },
        { 3*192, 2*192, 192, 192 },
        
        { 0*192, 3*192, 192, 192 },
        { 1*192, 3*192, 192, 192 },
        { 2*192, 3*192, 192, 192 },
        { 3*192, 3*192, 192, 192 },
        { 4*192, 3*192, 192, 192 },
         
        { 0*256, 4*192, 256, 256 },
        { 1*256, 4*192, 256, 256 },
        { 2*256, 4*192, 256, 256 },
    });
    
    // Start the main loop
    EM_ASM(document.getElementById('canvas').classList.remove('hide'););
    g_ticks_last_frame = g_ticks_this_frame = SDL_GetTicks();
    void* main_loop_arg = NULL;

#ifdef __EMSCRIPTEN__
    int fps = 0; // Use browser's requestAnimationFrame
    emscripten_set_main_loop_arg(main_loop, main_loop_arg, fps, true);
#else
    while (true) {
        main_loop(main_loop_arg);
    }
#endif

    IMG_Quit();
    SDL_Quit();

    return 0;
}



// Functions exposed to JavaScript
// TODO: Maybe would be good to add some way to set JS to run as callback when certain events occur

void enable_debug() { DEBUG_MODE = true; }

EMSCRIPTEN_BINDINGS(my_module) {
    function("enable_debug", &enable_debug);
}

