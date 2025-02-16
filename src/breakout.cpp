
/*
    Ideas:
    
    breakout + invaders
        player can hold button to shrink paddle, help navigate tight situations
            don't do paddle deflection while shrunk
        player can also hold a button to grab the ball, re-throw
        boss fights could bring back more traditional breakout gameplay by spawning in forcefields or barriers that player needs ot destroy
        space paddleship yamato
    
    breakout + gravity
        something like the fire game and watch
        bounce a dude on a trampoline and try to grab goodies/avoid enemies
    
    
        need to render a guy holding trampoline on each side of trampoline, and animate their legs as they move
        player should be able to tilt trampoline to affect x velocity of bouncing dudes
        
        adapt balls as the falling guys
            rotate the graphic based on x velocity

        multiplayer version would be fun, 
    
*/

// this can probably go in a separate file
// TODO: copy a bunch from C pong implementation that I already did before
//       also try and get the SDL audio working in the web?
namespace Breakout {
    
    const float PLAYER_MOVE_SPEED = 0.75; // in terms of playfield height per second
    const float PLAYER_HEIGHT     = 0.02;  // in terms of playfield height
    const float PLAYER_WIDTH      = 0.1;
    const float BALL_SIZE         = PLAYER_HEIGHT;
    const float BALL_INIT_SPEED   = 0.25; // viewport.w / second
    const float BALL_GRAVITY      = 1.0;
    const float BALL_MAX_SPEED_X  = 0.75;
    const float BALL_MAX_SPEED_Y  = sqrt(2.0f * BALL_GRAVITY * 0.8f);
    const float BALL_SPEED_INCR   = 0.025;
    const float GAME_OVER_TIME    = 2.0;
    const float GAME_READY_TIME   = 2.0;
    
    const float BALL_BOUNCE_POWER		=  1.05;
    const float BALL_BOUNCE_DEFLECTION	=  0.05;
    
    const int SCORE_TO_WIN = 5;
    
    // positions of players and balls will also be in unit of viewport
    // this way we do not need to adjust these when viewport changes, which it probably won't anyhow
    
    struct Player {
        int     score;
        Vec2    position;
        Vec2    position_prev;
        
    };
    
    struct Ball {
        Vec2    position;
        Vec2    velocity;
        bool    held;       // sticks to the player until the player shoots the ball
    };
    
    // bricks are just a bit set signifying the state/behaviors of the brick
    typedef char Brick;
    const Brick BRICK_NONE  = 0;
    const Brick BRICK_ALIVE = 1 << 0;
    
    #define BRICK_ROW_COUNT     13
    #define BRICK_COLUMN_COUNT  9
    #define BRICK_COUNT (BRICK_ROW_COUNT * BRICK_ROW_COUNT)
    
    FRect brick_frame = { 0.1, 0.15, 0.8, 0.5 };
    
    enum class Mode {
        READY,
        IN_GAME,
        GAME_OVER,
    };
    
    struct Game_State {
        Player  player;
        Ball    ball;
        Brick   bricks[256];
        
        Mode    mode;
        float   time_of_last_mode_change;
    };
    
    FRect get_brick_collision_rect(int x, int y) {
        FRect rect;
        rect.w = brick_frame.w / (float)BRICK_COLUMN_COUNT;
        rect.h = brick_frame.h / (float)BRICK_ROW_COUNT;
        rect.x = brick_frame.x + (float)x * rect.w;
        rect.y = brick_frame.y + (float)y * rect.h;
        
        rect.w -= BALL_SIZE / 4;
        rect.h -= BALL_SIZE / 4;
        return rect;
    }
    
    FRect get_player_collision_rect(Player* p) {
        return FRect {
            (p->position.x - PLAYER_WIDTH  / 2.0f),
            (p->position.y - PLAYER_HEIGHT / 2.0f),
            PLAYER_WIDTH,
            PLAYER_HEIGHT,
        };
    }
    
    FRect get_ball_collision_rect(Ball* b) {
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
        return Rect {
            (int32_t)((b->position.x - BALL_SIZE / 2.0f) * (float)viewport.w),
            (int32_t)((b->position.y - BALL_SIZE / 2.0f) * (float)viewport.h),
            (int32_t)(BALL_SIZE * (float)viewport.w),
            (int32_t)(BALL_SIZE * (float)viewport.h),
        };
    }
    
    Rect get_brick_render_rect(int x, int y) {
        FRect collision_rect = get_brick_collision_rect(x, y);
        return Rect {
            (int32_t)(collision_rect.x * (float)viewport.w),
            (int32_t)(collision_rect.y * (float)viewport.h),
            (int32_t)(collision_rect.w * (float)viewport.w),
            (int32_t)(collision_rect.h * (float)viewport.h),
        };
    }
    
    void move_paddle_towards_target_position(Player* p, Vec2 target_position, float speed_scale) {
        // TODO: maybe limit how far target position can be from current position
        // that way, we don't move too far in one frame, have a sort of max speed
        // float y_difference = p->position.y;
        // float y_target = clamp(target_position.y, 0, 1);
        // p->position.y = lerp(p->position.y, y_target, speed_scale * get_delta_time());
        float x_target = clamp(target_position.x, 0, 1);
        p->position.x = lerp(p->position.x, x_target, speed_scale * get_delta_time());
    }
    
    void start_game(Game_State* gs) {
        // set player initial state
        gs->player.position = Vec2 { 0.5, 0.9 };
        gs->player.score = 0;
        
        // set ball initial state
        gs->ball.position = Vec2 { 0.5, 0.5 };
        // TODO: set velocity of ball a bit randomly
        gs->ball.velocity = Vec2 { 0, BALL_INIT_SPEED };
        
        // set mode and time stuff
        gs->mode = Mode::READY;
        gs->time_of_last_mode_change = get_seconds_since_init();
        
        // make a checker pattern to test
        for (int i = 0; i < BRICK_ROW_COUNT; i++) {
            for (int j = 0; j < BRICK_COLUMN_COUNT; j++) {
                int index = i * BRICK_COLUMN_COUNT + j;
                gs->bricks[index] = ((j & 1) ^ (i & 1));
                // gs->bricks[index] = 1;
            }
        }
    }
    
    void init(void* data) {
        if (!data) return;
        Game_State* gs = (Game_State*)data;
        start_game(gs);
    }
    
    
    // Directions collide_ball(FRect* r1, Vec2* v1, FRect* r2, Vec2* v2, bool do_deflect) {
    //     float collision_time;
    //     Directions direction;
    //     if (swept_aabb_frect(r1, *v1, r2, *v2, &collision_time, &direction)) {
    //         ball_move *= collision_time;
		    
    //         switch (direction) {
    //           case DIR_L: {
    //             if (v1.x <= 0) {
    //                 v1.x *= -BALL_BOUNCE_POWER;
    //             }
    //             if (do_deflect) {
    //                 float paddle_center_y = r2.y + (r2.h / 2.0f);
    //                 float distance_from_center = (v1.y - paddle_center_y) / PLAYER_HEIGHT;
    //                 v1.y += distance_from_center * BALL_BOUNCE_DEFLECTION;
    //             }
    //           } break;
			  
    //           case DIR_R: {
    //             if (v1.x >= 0) {
    //                 v1.x *= -BALL_BOUNCE_POWER;
    //             }
    //             if (do_deflect) {
    //                 float paddle_center_y = r2.y + (r2.h / 2.0f);
    //                 float distance_from_center = (v1.y - paddle_center_y) / PLAYER_HEIGHT;
    //                 v1.y += distance_from_center * BALL_BOUNCE_DEFLECTION;
    //             }
    //           } break;
			  
    //           case DIR_U: {
    //             if (v1.y <= 0) {
    //                 v1.y *= -1;
    //             }
    //             if (do_deflect) {
    //                 float paddle_center_x = r2.x + (r2.w / 2.0f);
    //                 float distance_from_center = (v1.x - paddle_center_x) / PLAYER_HEIGHT;
    //                 v1.x += distance_from_center * BALL_BOUNCE_DEFLECTION;
    //             }
    //           } break;
			  
    //           case DIR_D: {
    //             if (v1.y >= 0) {
    //                 v1.y *= -1;
    //             }
    //             if (do_deflect) {
    //                 float paddle_center_x = r2.x + (r2.w / 2.0f);
    //                 float distance_from_center = (v1.x - paddle_center_x) / PLAYER_HEIGHT;
    //                 v1.x += distance_from_center * BALL_BOUNCE_DEFLECTION;
    //             }
    //           } break;
    //         }
    //     }
    // }
    
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
            Player* player = &gs->player;
            player->position_prev = player->position;
            
            // move player
            Vec2 mouse_position_local = to_vec2(mouse.position - viewport.position) / to_vec2(viewport.size);
            if (mouse.left & KEYSTATE_PRESSED) {
                move_paddle_towards_target_position(&gs->player, mouse_position_local, 8);
            }
            
            // paddles must have positions limited by top and bottom of screen
            player->position.y = clamp(player->position.y, PLAYER_HEIGHT / 2.0, 1.0 - PLAYER_HEIGHT / 2.0);
            player->position.x = clamp(player->position.x, PLAYER_WIDTH  / 2.0, 1.0 - PLAYER_WIDTH  / 2.0);
            
            
            // apply gravity to ball
            gs->ball.velocity.y += BALL_GRAVITY * delta_time;
            
            FRect ball_rect = get_ball_collision_rect(&gs->ball);
            Vec2  ball_move = gs->ball.velocity * delta_time;
            
            FRect player_rect = get_player_collision_rect(player);
            Vec2  player_move = player->position - player->position_prev;
            
            float collision_time;
            Directions direction;
            if (swept_aabb_frect(&ball_rect, ball_move, &player_rect, player_move, &collision_time, &direction)) {
                ball_move *= collision_time;
    		    
                switch (direction) {
                  case DIR_L: {
                    if (gs->ball.velocity.x <= 0) {
                        gs->ball.velocity.x *= -BALL_BOUNCE_POWER;
                    }
                    float paddle_center_y = player->position.y;
                    float distance_from_center = (gs->ball.position.y - paddle_center_y) / PLAYER_HEIGHT;
                    gs->ball.velocity.y += distance_from_center * BALL_BOUNCE_DEFLECTION;
                  } break;
    			  
                  case DIR_R: {
                    if (gs->ball.velocity.x >= 0) {
                        gs->ball.velocity.x *= -BALL_BOUNCE_POWER;
                    }
                    float paddle_center_y = player->position.y;
                    float distance_from_center = (gs->ball.position.y - paddle_center_y) / PLAYER_HEIGHT;
                    gs->ball.velocity.y += distance_from_center * BALL_BOUNCE_DEFLECTION;
                  } break;
    			  
                  case DIR_U: {
                    if (gs->ball.velocity.y <= 0) {
                        gs->ball.velocity.y *=  -BALL_BOUNCE_POWER;
                    }
                    float paddle_center_x = player->position.x;
                    float distance_from_center = (gs->ball.position.x - paddle_center_x) / PLAYER_HEIGHT;
                    gs->ball.velocity.x += distance_from_center * BALL_BOUNCE_DEFLECTION;
                  } break;
    			  
                  case DIR_D: {
                    if (gs->ball.velocity.y >= 0) {
                        gs->ball.velocity.y *=  -BALL_BOUNCE_POWER;
                    }
                    float paddle_center_x = player->position.x;
                    float distance_from_center = (gs->ball.position.x - paddle_center_x) / PLAYER_HEIGHT;
                    gs->ball.velocity.x += distance_from_center * BALL_BOUNCE_DEFLECTION;
                  } break;
                }
                
                // play bloop sound when bouncing off player
                // Mix_Chunk *sound_to_play = player_i ? sound_bloop_1 : sound_bloop_2;
                // Mix_PlayChannel(-1, sound_to_play, 0);
            }
            
            
            // collide ball with bricks
            
            // get current position of ball within brick tilemap
            Vec2 ball_position_in_brick_field = get_position_in_tilemap(gs->ball.position, &brick_frame, Vec2 { (float)BRICK_COLUMN_COUNT, (float)BRICK_ROW_COUNT });
            int start_x = MAX((int)ball_position_in_brick_field.x - 2, 0);
            int start_y = MAX((int)ball_position_in_brick_field.y - 2, 0);
            int end_x   = MIN((int)ball_position_in_brick_field.x + 2, BRICK_COLUMN_COUNT);
            int end_y   = MIN((int)ball_position_in_brick_field.y + 2, BRICK_ROW_COUNT);
            
            // iterate only over nearby bricks ot check for collision
            for (int i = start_y; i < end_y; i++) {
                for (int j = start_x; j < end_x; j++) {
                    int index = i * BRICK_COLUMN_COUNT + j;
                    if (gs->bricks[index] == 0) continue; 
                    FRect brick_rect = get_brick_collision_rect(j, i);
                    Vec2 brick_move = {};
                    
                    // Here we call our function to perform swept AABB collision between the two rectangles. 
                    // If the two rectangles collided, then we are given the time that the rectangles collide and which side of the ball collided with the paddle.
                    float collision_time;
                    Directions direction;
                    if (swept_aabb_frect(&ball_rect, ball_move, &brick_rect, brick_move, &collision_time, &direction)) {
                        ball_move *= collision_time;
            		    
                        switch (direction) {
                          case DIR_L: {
                            if (gs->ball.velocity.x <= 0) {
                                gs->ball.velocity.x *= -1;
                            }
                          } break;
            			  
                          case DIR_R: {
                            if (gs->ball.velocity.x >= 0) {
                                gs->ball.velocity.x *= -1;
                            }
                          } break;
            			  
                          case DIR_U: {
                            if (gs->ball.velocity.y <= 0) {
                                gs->ball.velocity.y *= -1;
                            }
                          } break;
            			  
                          case DIR_D: {
                            if (gs->ball.velocity.y >= 0) {
                                gs->ball.velocity.y *= -1;
                            }
                          } break;
                        }
                        
                        gs->bricks[index] = 0;
                        gs->player.score += 1;
                        
                        // play bloop sound when bouncing off player
                        // Mix_Chunk *sound_to_play = player_i ? sound_bloop_1 : sound_bloop_2;
                        // Mix_PlayChannel(-1, sound_to_play, 0);
                    }
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
                gs->ball.position.x = -BALL_SIZE / 2.0;
                gs->ball.velocity.x = -gs->ball.velocity.x;
            }
            if (gs->ball.position.x > 1.0 + BALL_SIZE / 2.0) {
                gs->ball.position.x = 1.0 + BALL_SIZE / 2.0;
                gs->ball.velocity.x = -gs->ball.velocity.x;
            }
            gs->ball.velocity.x = clamp(gs->ball.velocity.x, -BALL_MAX_SPEED_X, BALL_MAX_SPEED_X);
            gs->ball.velocity.y = clamp(gs->ball.velocity.y, -BALL_MAX_SPEED_Y, BALL_MAX_SPEED_Y);
            
            
            // if (gs->players[0].score >= SCORE_TO_WIN || gs->players[1].score >= SCORE_TO_WIN) {
            //     gs->mode = Mode::GAME_OVER;
            //     gs->time_of_last_mode_change = current_time;
            // }
        }
    }
    
    // factored out so that we can call it before or after rendreing other elements, depending on mode
    void render_player_scores(Game_State* gs) {
        Vec2i text_render_position;
        
        text_render_position = to_vec2i(to_vec2(viewport.size) * Vec2 { 0.5, 0.075 });
        render_small_text_int(gs->player.score, 0, text_render_position.x, text_render_position.y, 0, 0.5, 3.0);
        
        // text_render_position = to_vec2i(to_vec2(viewport.size) * Vec2 { 0.75, 0.1 });
        // render_small_text_int(gs->players[1].score, 0, text_render_position.x, text_render_position.y, 0, 0.5, 3.0);
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
        
        // render player, ball, and bricks
        {
            SDL_SetRenderDrawColor(renderer, 
                (uint8_t)(game_render_color.r * 255.0),
                (uint8_t)(game_render_color.g * 255.0),
                (uint8_t)(game_render_color.b * 255.0),
                (uint8_t)(game_render_color.a * 255.0)
            );
            
            Player* player = &gs->player;
            Rect player_rect = get_player_render_rect(player);
            SDL_RenderFillRect(renderer, &player_rect.sdl);
            
            Rect ball_rect = get_ball_render_rect(&gs->ball);
            SDL_RenderFillRect(renderer, &ball_rect.sdl);
            
            for (int i = 0; i < BRICK_ROW_COUNT; i++) {
                for (int j = 0; j < BRICK_COLUMN_COUNT; j++) {
                    int index = i * BRICK_COLUMN_COUNT + j;
                    if (gs->bricks[index] == 0) continue; 
                    Rect brick_rect = get_brick_render_rect(j, i);
                    SDL_RenderFillRect(renderer, &brick_rect.sdl);
                }
            }
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
                // char text[32];
                // sprintf(text, "PLAYER %d WINS!", gs->players[0].score > gs->players[1].score ? 1 : 2);
                // render_small_text(text, text_render_position.x, text_render_position.y, 0, 0.5, 3.0);
            }
        }
    }
}


