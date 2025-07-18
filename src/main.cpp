
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
#include "collision.cpp"
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

EM_BOOL on_web_display_size_changed(int event_type, const EmscriptenUiEvent *event, void *user_data);

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





#include "channel.cpp"

Fire_Rescue::Game_State game_state;

// Particle_Emitter bg_emitter;

const char* small_text_texture_file_path = "media/8x8_text.png";

const char* bg_texture_file_path = "media/bgtexture.png";
Texture bg_texture;

const char* scanlines_texture_file_path = "media/scanlines3.png";
Texture scanlines_texture;

const char* tv_texture_file_path = "media/tv.png";
Texture tv_texture;

// TODO: setup keybindings for this controller in main()
enum DEBUG_CONTROLLER {
    DEBUG_KEY_PREV_CHANNEL,
    DEBUG_KEY_NEXT_CHANNEL,

    DEBUG_KEY_COUNT
};

InputKey debug_controller[DEBUG_KEY_COUNT];


void main_loop(void* main_loop_arg) {
    g_ticks_last_frame = g_ticks_this_frame;
    g_ticks_this_frame = SDL_GetTicks();

    handle_sdl_events();
    update_mouse();

    SDL_SetRenderDrawColor(renderer, 0x00, 0x00, 0x00, 0xff);
    SDL_RenderSetViewport(renderer, NULL);
    SDL_RenderClear(renderer);

    if (DEBUG_MODE) {
        update_input_controller(debug_controller, DEBUG_KEY_COUNT);

        if (debug_controller[DEBUG_KEY_PREV_CHANNEL].state == KEYSTATE_PRESSED) {
            vhf_channel_index -= 1;
        }
        if (debug_controller[DEBUG_KEY_NEXT_CHANNEL].state == KEYSTATE_PRESSED) {
            vhf_channel_index += 1;
        }
    }
    
    Rect canvas_rect = {
        .w = canvas_width,
        .h = canvas_height
    };
    
    // SDL_SetRenderDrawColor(renderer, 0, 128, 255, 255);
    // SDL_RenderFillRect(renderer, &canvas_rect.sdl);

    // bg_color_mod = get_timed_lerp_value(&bg_color_mod_lerp);
    // SDL_SetTextureColorMod(
    //     bg_texture.id,
    //     (bg_color_mod.r * 255.0),
    //     (bg_color_mod.g * 255.0),
    //     (bg_color_mod.b * 255.0)
    // );

    // set viewport for channel
    // first, figure out rect for foreground image of tv
    // then use channel_viewport_clip to figure out channel viewport relative to that rect
    // Rect tv_rect = {
    //     .w = tv_texture.width,
    //     .h = tv_texture.height,
    // };
    // center_and_scale_rect_within_rect(&tv_rect, &canvas_rect, Axis::MAJOR);

    // viewport = clip_within_rect(&tv_rect, &channel_viewport_clip);
    // SDL_RenderSetViewport(renderer, &viewport.sdl);

    // update and render channel
    Channel* channel = &vhf_channels[0];
    // printf("channel data is %p\n", channel->data);
    // if (channel->update) {
        // printf("calling update %p\n", channel->update);
        // Fire_Rescue::update(channel->data);
        channel->update(channel->data);
        // printf("after update\n");
    // }
    // if (channel->render) {
        // printf("calling render %p\n", channel->render);
        // Fire_Rescue::render(channel->data);
        channel->render(channel->data);
        // printf("after render\n");
    // } else {
    //     // default render just shows tv static
    //     // render_static();

    //     Rect bg_rect = {
    //         .w = bg_texture.width,
    //         .h = bg_texture.height,
    //     };
    //     center_and_scale_rect_within_rect(&bg_rect, &vp, Axis::MINOR);
    //     SDL_RenderCopy(renderer, bg_texture.id, NULL, &bg_rect.sdl);
    // }

    // render screen overlay
    // printf("after\n");

    // TODO: interact with tv dials and power button


    SDL_RenderSetViewport(renderer, NULL);

    // FRect scanlines_rect
    // Rect scanlines_rect = clip_within_rect(&tv_rect, &channel_viewport_clip);
    // SDL_SetTextureAlphaMod(scanlines_texture.id, 0x55 + (uint8_t)((float)0x11 * abs(sin(get_seconds_since_init()))));
    // SDL_RenderCopy(renderer, scanlines_texture.id, NULL, &scanlines_rect.sdl);

    // DEBUG: render rectangle around tv viewport
    // SDL_SetRenderDrawColor(renderer, 0, 255, 0, 255);
    // SDL_RenderDrawRect(renderer, &viewport.sdl);
    viewport = canvas_rect;

    // SDL_RenderCopy(renderer, tv_texture.id, NULL, &tv_rect.sdl);

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
    
    
    auto mixer_flags = MIX_InitFlags::MIX_INIT_MP3;
    const int result = Mix_Init(mixer_flags);
    if ((result & mixer_flags) != mixer_flags) {
        printf("Error: failed to initialize SDL_Mixer. %s\n", Mix_GetError());
        return 0;
    }
    
    if (Mix_OpenAudio(44100, MIX_DEFAULT_FORMAT, MIX_DEFAULT_CHANNELS, 2048) == -1) {
        printf("Error: failed to open audio device. %s\n", Mix_GetError());
        return 0;
    }
    
    
    if (!load_texture(renderer, &small_text_texture, small_text_texture_file_path)) {
        printf("failed to load texture");
    }
    SDL_SetTextureScaleMode(small_text_texture.id, SDL_ScaleModeNearest);

    if (!load_texture(renderer, &bg_texture, bg_texture_file_path)) {
        printf("failed to load texture");
    }
    if (!load_texture(renderer, &tv_texture, tv_texture_file_path)) {
        printf("failed to load texture");
    }
    if (!load_texture(renderer, &scanlines_texture, scanlines_texture_file_path)) {
        printf("failed to load texture");
    }



    vhf_channels[0] = Channel { };
    vhf_channels[0].data   = &game_state;
    vhf_channels[0].init   = Fire_Rescue::init;
    vhf_channels[0].update = Fire_Rescue::update;
    vhf_channels[0].render = Fire_Rescue::render;

    vhf_channels[0].init(vhf_channels[0].data);
    
    printf("update is %p\n", vhf_channels[0].update);
    printf("render is %p\n", vhf_channels[0].render);
    printf("game_state is %p\n", &game_state);


    // for (int i = 0; i < 13; i++) {
    //     if (vhf_channels[i].init && vhf_channels[i].data) {
    //         vhf_channels[i].init(&vhf_channels[i].data);
    //     }
    // }

    // Start the main loop
    EM_ASM(document.getElementById('loader').remove());
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

