

// the area within foreground image that tv screen occupies
// normalized 0-1 along image axes so that we can just clip with respect to tv foreground image rect
FRect channel_viewport_clip = { 116.0/1000.0, 289.0/898.0, 615.0/1000.0, 436.0/898.0 };


// typedef void (*Channel_Proc)(void*);

// very general since channels may want to do anything
// update and render are function pointers, will just be cast to proper type
struct Channel {
    // int             number;
    void*           data;
    void (*init  )(void*);
    void (*update)(void*);
    void (*render)(void*);
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
    const float BALL_INIT_SPEED   = 0.25; // viewport.w / second
    const float BALL_MAX_SPEED    = 2.0;
    const float BALL_SPEED_INCR   = 0.025;
    const float GAME_OVER_TIME    = 2.0;
    const float GAME_READY_TIME   = 2.0;
    
    const float BALL_BOUNCE_POWER		=  1.05;
    const float BALL_BOUNCE_DEFLECTION	=  0.25;
    
    
    // positions of players and balls will also be in unit of viewport
    // this way we do not need to adjust these when viewport changes, which it probably won't anyhow
    
    struct Player {
        int     score;
        Vec2    position;
        Vec2    position_prev;
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
    
    FRect get_player_collision_rect(Player* p) {
        return FRect {
            (p->position.x - PLAYER_WIDTH  / 2.0f),
            (p->position.y - PLAYER_HEIGHT / 2.0f),
            PLAYER_WIDTH,
            PLAYER_HEIGHT,
        };
    }
    
    FRect get_ball_collision_rect(Ball* b) {
        // ball size only depends on width, not height. since both dimensions of ball need to be the same, and it is also nice for ball width to match paddle width
        return FRect {
            (b->position.x - BALL_SIZE / 2.0f),
            (b->position.y - BALL_SIZE / 2.0f),
            BALL_SIZE,
            BALL_SIZE,
        };
    }
    
    Rect get_player_render_rect(Player* p) {
        return Rect {
            (int32_t)((p->position.x - PLAYER_WIDTH  / 2.0f) * (float)viewport.w),
            (int32_t)((p->position.y - PLAYER_HEIGHT / 2.0f) * (float)viewport.h),
            (int32_t)(PLAYER_WIDTH  * (float)viewport.w),
            (int32_t)(PLAYER_HEIGHT * (float)viewport.h),
        };
    }
    
    Rect get_ball_render_rect(Ball* b) {
        // ball size only depends on width, not height. since both dimensions of ball need to be the same, and it is also nice for ball width to match paddle width
        return Rect {
            (int32_t)((b->position.x - BALL_SIZE / 2.0f) * (float)viewport.w),
            (int32_t)((b->position.y - BALL_SIZE / 2.0f) * (float)viewport.h),
            (int32_t)(BALL_SIZE * (float)viewport.w),
            (int32_t)(BALL_SIZE * (float)viewport.h),
        };
    }
    
    void move_paddle_towards_target_position(Player* p, Vec2 target_position, float speed_scale) {
        // TODO: maybe limit how far target position can be from current position
        // that way, we don't move too far in one frame, have a sort of max speed
        // float y_difference = p->position.y;
        float y_target = clamp(target_position.y, 0, 1);
        p->position.y = lerp(p->position.y, y_target, speed_scale * get_delta_time());
    }
    
    void start_game(Game_State* gs) {
        // set player initial state
        gs->players[0].position = Vec2 { 0.1, 0.5 };
        gs->players[1].position = Vec2 { 0.9, 0.5 };
        gs->players[0].score = 0;
        gs->players[1].score = 0;
        
        // set ball initial state
        gs->ball.position = Vec2 { 0.5, 0.5 };
        // TODO: set velocity of ball a bit randomly
        gs->ball.velocity = Vec2 { BALL_INIT_SPEED, 0 };
        
        // set mode and time stuff
        gs->mode = Mode::READY;
        gs->time_of_last_mode_change = get_seconds_since_init();
    }
    
    void init(void* data) {
        if (!data) return;
        Game_State* gs = (Game_State*)data;
        start_game(gs);
    }
    
    // instead of actually recording time of mode change, maybe we want to aggregate time manually,
    // this will prevent the game from 'running' when we aren't on the channel
    // or, we have a procedure that gets called when the user changes on to the channel, which is probabyl more generally useful
    
    void update(void* data) {
        if (!data) return;
        Game_State* gs = (Game_State*)data;
        
        // maybe change game mode, based on current mode and timer
        float current_time = get_seconds_since_init();
        float delta_time   = get_delta_time();
        float time_since_last_mode_change = current_time - gs->time_of_last_mode_change;
        
        if (gs->mode == Mode::READY && time_since_last_mode_change >= GAME_READY_TIME) {
            // TODO: maybe instead of using a timer here, we want to just wait until player clicks in the game viewport
            gs->mode = Mode::IN_GAME;
            gs->time_of_last_mode_change = current_time;
            return;
        }
        if (gs->mode == Mode::GAME_OVER && time_since_last_mode_change >= GAME_OVER_TIME) {
            start_game(gs);
            return;
        }
        if (gs->mode == Mode::IN_GAME) {
            for (int i = 0; i < 2; i++) {
                Player* player = &gs->players[i];
                player->position_prev = player->position;
            }
            
            // move players
            Vec2 mouse_position_local = to_vec2(mouse.position - viewport.position) / to_vec2(viewport.size);
            if (mouse.left & KEYSTATE_PRESSED) {
                move_paddle_towards_target_position(&gs->players[0], mouse_position_local, 8);
            }
            move_paddle_towards_target_position(&gs->players[1], gs->ball.position + Vec2 { 0, gs->ball.velocity.y }, 8);
            
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
            
            FRect ball_rect = get_ball_collision_rect(&gs->ball);
            Vec2 ball_move = gs->ball.velocity * delta_time;
            for (int i = 0; i < 2; i++) {
                Player* player = &gs->players[i];
                FRect player_rect = get_player_collision_rect(player);
                Vec2  player_move = player->position - player->position_prev;
                
        		// Here we call our function to perform swept AABB collision between the two rectangles. 
        		// If the two rectangles collided, then we are given the time that the rectangles collide and which side of the ball collided with the paddle.
        		float collision_time;
        		Directions direction;
        		if (swept_aabb_frect(&ball_rect, ball_move, &player_rect, player_move, &collision_time, &direction)) {
        		    ball_move *= collision_time;
                    printf("collided player %d\n", i);
                    printf("player rect %f, %f, %f, %f\n", player_rect.x, player_rect.y, player_rect.w, player_rect.h);
                    printf("player move %f, %f\n", player_move.x, player_move.y);
                    
        			switch (direction) {
        			  case DIR_L:
        				puts("l");
        			  case DIR_R: {
        				puts("r");
        				gs->ball.velocity.x *= -BALL_BOUNCE_POWER;
        				float paddle_center_y = player->position.y;
        				float distance_from_center = (gs->ball.position.y - paddle_center_y) / PLAYER_HEIGHT;
        				gs->ball.velocity.y += distance_from_center * BALL_BOUNCE_DEFLECTION;
        				} break;
        			  case DIR_U:
        				puts("u");
        				if (gs->ball.velocity.y < 0)
        					gs->ball.velocity.y *= -1;
        				gs->ball.velocity.y += player_move.y;
        				break;
        			  case DIR_D:
        				puts("d");
        				if (gs->ball.velocity.y > 0)
        					gs->ball.velocity.y *= -1;
        				gs->ball.velocity.y += player_move.y;
        				break;
        			}
                    
        			// play bloop sound when bouncing off player
                    // Mix_Chunk *sound_to_play = player_i ? sound_bloop_1 : sound_bloop_2;
                    // Mix_PlayChannel(-1, sound_to_play, 0);
        		}
            }
            
            // update position of ball
            gs->ball.position += ball_move;
            
            if (gs->ball.position.y < -BALL_SIZE / 2.0) {
                gs->ball.position.y = -BALL_SIZE / 2.0;
                gs->ball.velocity.y = -gs->ball.velocity.y;
            }
            if (gs->ball.position.y > 1.0 + BALL_SIZE / 2.0) {
                gs->ball.position.y = 1.0 + BALL_SIZE / 2.0;
                gs->ball.velocity.y = -gs->ball.velocity.y;
            }
            if (gs->ball.position.x < -BALL_SIZE / 2.0) {
                gs->players[1].score += 1;
                // serve_ball(gs->ball, true);
                gs->ball.velocity = Vec2 { BALL_INIT_SPEED, 0 };
                gs->ball.position = Vec2 { 0.5, 0.5 };
            }
            if (gs->ball.position.x > 1.0 + BALL_SIZE / 2.0) {
                gs->players[0].score += 1;
                // serve_ball(gs->ball, false);
                gs->ball.velocity = Vec2 { -BALL_INIT_SPEED, 0 };
                gs->ball.position = Vec2 { 0.5, 0.5 };
            }
            
            if (gs->players[0].score >= 10 || gs->players[1].score >= 10) {
                gs->mode = Mode::GAME_OVER;
                gs->time_of_last_mode_change = current_time;
            }
        }
    }
    
    // factored out so that we can call it before or after rendreing other elements, depending on mode
    void render_player_scores(Game_State* gs) {
        Vec2i text_render_position;
        
        text_render_position = to_vec2i(to_vec2(viewport.size) * Vec2 { 0.25, 0.1 });
        render_small_text_int(gs->players[0].score, 0, text_render_position.x, text_render_position.y, 0, 0.5, 3.0);
        
        text_render_position = to_vec2i(to_vec2(viewport.size) * Vec2 { 0.75, 0.1 });
        render_small_text_int(gs->players[1].score, 0, text_render_position.x, text_render_position.y, 0, 0.5, 3.0);
    }
    
    
    void render(void* data) {
        if (!data) return;
        Game_State* gs = (Game_State*)data;
        
        const Color4 white = { 1, 1, 1, 1 };
        const Color4 gray  = { 0.65, 0.65, 0.65, 1 };
        
        Color4 text_render_color = (gs->mode == Mode::IN_GAME) ? gray  : white;
        Color4 game_render_color = (gs->mode == Mode::IN_GAME) ? white : gray;
        
        SDL_SetTextureColorMod(small_text_texture.id,
            (uint8_t)(text_render_color.r * 255.0),
            (uint8_t)(text_render_color.g * 255.0),
            (uint8_t)(text_render_color.b * 255.0)
        );
        
        // while in-game, render player scores below players and ball
        if (gs->mode == Mode::IN_GAME) {
            render_player_scores(gs);
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
                Rect player_rect = get_player_render_rect(player);
                SDL_RenderFillRect(renderer, &player_rect.sdl);
            }
            
            Rect ball_rect = get_ball_render_rect(&gs->ball);
            SDL_RenderFillRect(renderer, &ball_rect.sdl);
        }
        
        if (gs->mode != Mode::IN_GAME) {
            // when not in-game, player scores get rendered above players and ball
            render_player_scores(gs);
            
            // render text for READY and GAME_OVER modes
            Vec2 text_render_position = Vec2 { 0.5f * (float)viewport.w, 0.25f * (float)viewport.h };
            if (gs->mode == Mode::READY) {
                render_small_text("READY?", text_render_position.x, text_render_position.y, 0, 0.5, 3.0);
            }
            if (gs->mode == Mode::GAME_OVER) {
                char text[32];
                sprintf(text, "PLAYER %d WINS!", gs->players[0].score > gs->players[1].score ? 1 : 2);
                render_small_text(text, text_render_position.x, text_render_position.y, 0, 0.5, 3.0);
            }
        }
    }
}


