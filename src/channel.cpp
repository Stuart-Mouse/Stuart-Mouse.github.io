

// the area within foreground image that tv screen occupies
// normalized 0-1 along image axes so that we can just clip with respect to tv foreground image rect
FRect channel_viewport_clip = { 116.0/1000.0, 289.0/898.0, 615.0/1000.0, 484.0/898.0 };


typedef void (*Channel_Proc)(void*);

// very general since channels may want to do anything
// update and render are function pointers, will just be cast to proper type
struct Channel {
    // int             number;
    void*           data;
    Channel_Proc    init, update, render;
};

// really no reason to even separate update and render, but its better for organization and slightly more future proof
// anything other than data pointer provided, renderer state, etc is just global data
// data specific to individual channels is still better passed explicitly so that struct for screen can use short names for variables and such


// channel index is not channel number, its an index to the valid channels array
int vhf_channel_index = 0;
// int current_uhf_channel_index = 0; // skip doing uhf for proof of concept (14 - 83)

Channel vhf_channels[13];
// Channel uhf_channels[13];

Channel* get_current_channel() {
    vhf_channel_index = clampi(vhf_channel_index, 0, 12);
    printf("channel is %f\n", vhf_channel_index);
    return &vhf_channels[vhf_channel_index];
}



/* 
    TV GUIDE
    
    channel  4: pong
    channel  7: TMH logo with static
    channel 11: fish tank
    channel 13: static-y face
    
*/


// this can probably go in a separate file
// TODO: copy a bunch from C pong implementation that I already did before
//       also try and get the SDL audio working in the web?
namespace Pong {
    
    const int   SCORE_TO_WIN      = 10;
    const float PLAYER_MOVE_SPEED = 0.75; // in terms of playfield height per second
    const float PLAYER_HEIGHT     = 0.1;  // in terms of playfield height
    const float PLAYER_WIDTH      = 0.02;
    const float BALL_SIZE         = PLAYER_WIDTH;
    const float BALL_INIT_SPEED   = 0.5; // viewport.w / second
    const float BALL_MAX_SPEED    = 3.0;
    const float BALL_SPEED_INCR   = 0.025;
    const float GAME_OVER_TIME    = 2.0;
    const float GAME_READY_TIME   = 2.0;
    
    // positions of players and balls will also be in unit of viewport
    // this way we do not need to adjust these when viewport changes, which it probably won't anyhow
    
    struct Player {
        int     score;
        Vec2    position;
        // controller
    };
    
    struct Ball {
        int     score;
        Vec2    position;
        Vec2    velocity;
    };
    
    enum class Mode {
        READY,
        IN_GAME,
        GAME_OVER,
    };
    
    struct Game_State {
        Player  players[2];
        Ball    ball;
        
        Mode    mode;
        float   time_of_last_mode_change;
    };
    
    // using player.position is center point of paddle
    FRect get_player_rect(Player* p) {
        return FRect {
            (p->position.x - PLAYER_WIDTH  / 2.0f) * viewport.w,
            (p->position.y - PLAYER_HEIGHT / 2.0f) * viewport.h,
            PLAYER_WIDTH  * viewport.w,
            PLAYER_HEIGHT * viewport.h,
        };
    }
    
    FRect get_ball_rect(Ball* b) {
        // ball size only depends on width, not height. since both dimensions of ball need to be the same, and it is also nice for ball width to match paddle width
        FRect ball_rect = {
            (b->position.x - BALL_SIZE / 2.0f) * viewport.w,
            (b->position.y - BALL_SIZE / 2.0f) * viewport.w,
            BALL_SIZE,
            BALL_SIZE
        };
    }
    
    void init(void* data) {
        if (!data) return;
        Game_State* gs = (Game_State*)data;
        
        // set player initial state
        gs->players[0].position = Vec2 { 0.1, 0.5 };
        gs->players[1].position = Vec2 { 0.9, 0.5 };
        // TODO: init player controller
        
        // set ball initial state
        gs->ball.position = Vec2 { 0.5, 0.5 };
        // TODO: set velocity of ball a bit randomly
        
        // set mode and time stuff
        gs->mode = Mode::READY;
        gs->time_of_last_mode_change = get_seconds_since_init();
    }
    
    // instead of actually recording time of mode change, maybe we want to aggregate time manually,
    // this will prevent the game from 'running' when we aren't on the channel
    // or, we have a procedure that gets called when the user changes on to the channel, which is probabyl more generally useful
    
    void update(void* data) {
        printf("in update a\n");
        if (!data) return;
        Game_State* gs = (Game_State*)data;
        printf("in update b\n");
        
        // maybe change game mode, based on current mode and timer
        float current_time = get_seconds_since_init();
        float delta_time   = get_delta_time();
        float time_since_last_mode_change = current_time - gs->time_of_last_mode_change;
        
        printf("in update c\n");
        
        if (gs->mode == Mode::READY && time_since_last_mode_change >= GAME_READY_TIME) {
            printf("game ready\n");
        
            // TODO: maybe instead of using a timer here, we want to just wait until player clicks in the game viewport
            gs->mode = Mode::IN_GAME;
            gs->time_of_last_mode_change = current_time;
            return;
        }
        if (gs->mode == Mode::GAME_OVER && time_since_last_mode_change >= GAME_OVER_TIME) {
            printf("game over\n");
        
            gs->mode = Mode::READY;
            gs->time_of_last_mode_change = current_time;
            return;
        }
        if (gs->mode == Mode::IN_GAME) {
            printf("in game\n");
            // player input
            // get mouse position in local space
            Vec2 mouse_position_local = to_vec2(mouse.position);
            
            // CPU player movement
            // both player and cpu paddle will have a sort of exponential easing to them, so that they move faster when trying to move further away
            // both will just move towards a target position, player moves towards target position of mouse when clicked, cpu moves towards target position of ball.position.y
            
            float player_width  = PLAYER_WIDTH  * viewport.w;
            float player_height = PLAYER_HEIGHT * viewport.h;
            float BALL_SIZE     = BALL_SIZE     * viewport.w;
            
            // paddles must have positions limited by top and bottom of screen
            for (int i = 0; i < 2; i++) {
                Player* player = &gs->players[i];
                if (player->position.y < PLAYER_HEIGHT / 2.0) {
                    player->position.y = PLAYER_HEIGHT / 2.0;
                }
                if (player->position.y > 1.0 - PLAYER_HEIGHT / 2.0) {
                    player->position.y = 1.0 - PLAYER_HEIGHT / 2.0;
                }
            }
            
            FRect ball_rect = get_ball_rect(&gs->ball);
            for (int i = 0; i < 2; i++) {
                Player* player = &gs->players[i];
                FRect player_rect = get_player_rect(player);
                
                
                // do collision of ball with player
                // swept frect
            }
            
            // update position of ball
            
            
            if (gs->ball.position.x < -BALL_SIZE / 2.0) {
                gs->players[1].score += 1;
                // serve_ball(gs->ball, true);
            }
            if (gs->ball.position.x > 1.0 + BALL_SIZE / 2.0) {
                gs->players[0].score += 1;
                // serve_ball(gs->ball, false);
            }
        }
    }
    
    // factored out so that we can call it before or after rendreing other elements, depending on mode
    void render_player_scores(Game_State* gs) {
        Vec2i text_render_position;
        
        text_render_position = to_vec2i(to_vec2(viewport.size) * Vec2 { 0.25, 0.25 });
        render_small_text_int(gs->players[0].score, 0, text_render_position.x, text_render_position.y, 0, 0.5, 1.0);
        
        text_render_position = to_vec2i(to_vec2(viewport.size) * Vec2 { 0.75, 0.25 });
        render_small_text_int(gs->players[1].score, 0, text_render_position.x, text_render_position.y, 0, 0.5, 1.0);
    }
    
    
    void render(void* data) {
        if (!data) return;
        Game_State* gs = (Game_State*)data;
        
        const Color4 white = { 1, 1, 1, 1 };
        const Color4 gray  = { 0.5, 0.5, 0.5, 1 };
        
        Color4 text_render_color = gs->mode == Mode::IN_GAME ? gray  : white;
        Color4 game_render_color = gs->mode == Mode::IN_GAME ? white : gray;
        
        
        // while in-game, render player scores below players and ball
        if (gs->mode == Mode::IN_GAME) {
            SDL_SetRenderDrawColor(renderer, 
                (uint8_t)(text_render_color.r * 255.0),
                (uint8_t)(text_render_color.g * 255.0),
                (uint8_t)(text_render_color.b * 255.0),
                (uint8_t)(text_render_color.a * 255.0)
            );
            // render_player_scores(gs);
        }
        
        // render players and ball
        {
            SDL_SetRenderDrawColor(renderer, 
                (uint8_t)(game_render_color.r * 255.0),
                (uint8_t)(game_render_color.g * 255.0),
                (uint8_t)(game_render_color.b * 255.0),
                (uint8_t)(game_render_color.a * 255.0)
            );
            
            for (int i = 0; i < 2; i++) {
                Player* player = &gs->players[i];
                Rect player_rect = to_rect(get_player_rect(player));
                SDL_RenderFillRect(renderer, &player_rect.sdl);
            }
            
            Rect ball_rect = to_rect(get_ball_rect(&gs->ball));
            SDL_RenderFillRect(renderer, &ball_rect.sdl);
        }
        
        if (gs->mode != Mode::IN_GAME) {
            SDL_SetRenderDrawColor(renderer, 
                (uint8_t)(text_render_color.r * 255.0),
                (uint8_t)(text_render_color.g * 255.0),
                (uint8_t)(text_render_color.b * 255.0),
                (uint8_t)(text_render_color.a * 255.0)
            );
            
            // when not in-game, player scores get rendered above players and ball
            // render_player_scores(gs);
            
            // render text for READY and GAME_OVER modes
            Vec2 text_render_position = to_vec2(viewport.size) * Vec2 { 0.5, 0.25 };
            if (gs->mode == Mode::READY) {
                // render_small_text("READY?", text_render_position.x, text_render_position.y, 0, 0.5, 1.0);
            }
            if (gs->mode == Mode::GAME_OVER) {
                // char text[] = "PLAYER X WINS!";
                // text[7] = gs->players[0].score > gs->players[1].score ? '1' : '2';
                // render_small_text(text, text_render_position.x, text_render_position.y, 0, 0.5, 1.0);
            }
        }
    }
}


Pong::Game_State pong_game;
