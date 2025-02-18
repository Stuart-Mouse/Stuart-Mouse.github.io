
/*
    Ideas:


    need to render a guy holding trampoline on each side of trampoline, and animate their legs as they move
    * player should be able to tilt trampoline to affect x velocity of bouncing dudes

    * adapt balls as the falling guys
    * rotate the graphic based on x velocity

    * spawn new guys in from left side of screen with somewhat random initial velocity
    - render arrow for guys falling from off top of screen

    * need timer that runs between guys jumping from windows
    * need multiple windows that guys can jump from

    * limit speed of guys on x axis more
    * limit max bounce height
    * reposition floor height

    * put in placeholder for ambalance
    code up the guys to have state for "about to jump" and "safe", (and dead also)


    need to create some means to actaully spawn short-lived particles in some more generic particle emitter

    spawn some bloody particles when guys hit the floor
    spawn some cloudy particles when guys bounce on stretcher


    instead of having ambulance, may just make it so that guys can land safely below a certain speed, so you just have to bounce them enough to slow them down
    this would give more reason fo needing to tilt, so that you have to keep the gusy on-screen
    then maybe we can have buildings on both sides
*/


namespace Fire_Rescue {
    const float PLAYER_HEIGHT     = 0.02;
    const float PLAYER_WIDTH      = 0.1;

    const float GAME_OVER_TIME    = 2.0;
    const float GAME_READY_TIME   = 2.0;

    const float GUY_SIZE                = 0.05;
    const float GUY_GRAVITY             = 0.5;
    const float GUY_MAX_SPEED_X         = 0.75;
    const float GUY_MAX_SPEED_Y         = sqrt(2.0f * GUY_GRAVITY * 0.8f);
    const float GUY_SPEED_INCR          = 0.025;
    const float GUY_BOUNCE_MIN          = 0.4;
    const float GUY_BOUNCE_POWER_LOW    = 0.85;
    const float GUY_BOUNCE_POWER_HIGH   = 1.15;
    const float GUY_BOUNCE_DEFLECTION   = 0.1;
    const float GUY_ROTATION_SPEED      = 12.0;
    const int   GUY_COUNT               = 16;

    // the area that the guys need to land in to be considered safe
    FRect safe_rect = {
        .x = 0.8,
        .y = 0.7,
        .w = 0.2,
        .h = 0.2,
    };

    FRect floor_rect = {
        .x = 0.0,
        .y = 0.9,
        .w = 1.0,
        .h = 0.1,
    };

    // these are the window positions used for spawning guys, not for anything visual
    const float WINDOW_POSITIONS[3] = { 0.2, 0.4, 0.6 };

    const float FLOOR_HEIGHT = 0.95;

    const int SCORE_TO_WIN = 5;

    Texture cloud_texture;
    Texture fire_texture;
    Texture guy_texture;
    Texture stretcher_texture;
    Texture ambulance_texture;

    Particle_Emitter cloud_emitter;
    Particle_Emitter fire_emitter;

    enum Player_Keys {
        PLAYER_KEY_BOUNCE_HIGH,
        PLAYER_KEY_TILT_LEFT,
        PLAYER_KEY_TILT_RIGHT,

        PLAYER_KEY_COUNT,
    };

    struct Player {
        Vec2        position;
        Vec2        position_prev;
        InputKey    controller[PLAYER_KEY_COUNT];
    };

    struct Guy {
        Vec2    position;
        Vec2    velocity;
        float   rotation;
        bool    active;
    };

    enum class Mode {
        READY,
        IN_GAME,
        GAME_OVER,
    };

    struct Game_State {
        Player  player;
        Guy     guys[GUY_COUNT];
        int     score;

        float   next_jump_time;


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

    Rect get_player_render_rect(Player* p) {
        return Rect {
            (int32_t)((p->position.x - PLAYER_WIDTH  / 2.0f) * (float)viewport.w),
            (int32_t)((p->position.y - PLAYER_HEIGHT / 2.0f) * (float)viewport.h),
            (int32_t)(PLAYER_WIDTH  * (float)viewport.w),
            (int32_t)(PLAYER_HEIGHT * (float)viewport.h),
        };
    }

    FRect get_guy_collision_rect(Guy* b) {
        return FRect {
            (b->position.x - GUY_SIZE / 2.0f),
            (b->position.y - GUY_SIZE / 2.0f),
            GUY_SIZE,
            GUY_SIZE,
        };
    }

    Rect get_guy_render_rect(Guy* b) {
        return Rect {
            (int32_t)((b->position.x - GUY_SIZE / 2.0f) * (float)viewport.w),
            (int32_t)((b->position.y - GUY_SIZE / 2.0f) * (float)viewport.h),
            (int32_t)(GUY_SIZE * (float)viewport.w),
            (int32_t)(GUY_SIZE * (float)viewport.h),
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
        gs->player.position = Vec2 { 0.5, 0.85 };
        gs->score = 0;

        // // set guy initial state
        // guy->position = Vec2 { 0.5, 0.5 };
        // // TODO: set velocity of guy a bit randomly
        // guy->velocity = Vec2 { 0, GUY_INIT_SPEED };

        // for (int i = 0; i < GUY_COUNT; i++) {
        //     Guy* guy = &gs->guys[i];
        //     if (i % 4 != 0)  continue;
        //     guy->active = true;
        //     float offset = 1.0f / (float)GUY_COUNT / 2.0f;
        //     guy->position.x = offset + (float)i / (float)GUY_COUNT;
        // }

        // set mode and time stuff
        gs->mode = Mode::READY;
        gs->time_of_last_mode_change = get_seconds_since_init();
    }

    void init(void* data) {
        if (!data) return;

        if (!load_texture(renderer, &guy_texture, "media/guy.png")) {
            printf("failed to load guy texture");
        }
        if (!load_texture(renderer, &stretcher_texture, "media/stretcher.png")) {
            printf("failed to load stretcher texture");
        }
        if (!load_texture(renderer, &ambulance_texture, "media/ambulance.png")) {
            printf("failed to load ambulance texture");
        }
        if (!load_texture(renderer, &cloud_texture, "media/smoke.png")) {
            printf("failed to load ambulance texture");
        }
        if (!load_texture(renderer, &fire_texture, "media/fire.png")) {
            printf("failed to load ambulance texture");
        }


        // TODO: have 3 separate fire emitters, one for each window
        //       add more fire particles and some kind of small smoke particle

        fire_emitter.texture = fire_texture;

        init_particle_emitter(&fire_emitter, 128);
        fire_emitter.emit_box                  = FRect { 0, 0, 0.15, 1.0 };
        fire_emitter.emit_freq             [0] = 10;
        fire_emitter.emit_freq             [1] = 30;
        fire_emitter.init_velocity         [0] = Vec2 {  0.0,  -0.00003   };
        fire_emitter.init_velocity         [1] = Vec2 {  0.0,  -0.000005  };
        fire_emitter.init_acceleration     [0] = Vec2 { -0.0000001, -0.0000006 };
        fire_emitter.init_acceleration     [1] = Vec2 {  0.0000001, -0.0000002 };
        fire_emitter.init_scale            [0] = 0.02;
        fire_emitter.init_scale            [1] = 0.05;
        fire_emitter.init_rotation         [0] = 0;
        fire_emitter.init_rotation         [1] = 0;
        fire_emitter.init_angular_velocity [0] = 0;
        fire_emitter.init_angular_velocity [1] = 0;
        fire_emitter.init_lifetime         [0] = 2000;
        fire_emitter.init_lifetime         [1] = 4000;
        fire_emitter.init_color_mod        [0] = { 1, 1, 1, 0.25 };
        fire_emitter.init_color_mod        [1] = { 1, 1, 1, 1 };

        fire_emitter.texture_clips.insert(fire_emitter.texture_clips.end(), {
            { 0, 0, 16, 16 },
        });


        cloud_emitter.texture = cloud_texture;

        init_particle_emitter(&cloud_emitter, 64);
        cloud_emitter.emit_box                  = FRect { -0.3, 0, 0.4, 0.3 };
        cloud_emitter.emit_freq             [0] = 200;
        cloud_emitter.emit_freq             [1] = 300;
        cloud_emitter.init_velocity         [0] = Vec2 { 0.00005, 0.0 };
        cloud_emitter.init_velocity         [1] = Vec2 { 0.00030, 0.0 };
        cloud_emitter.init_acceleration     [0] = Vec2 { 0, 0 };
        cloud_emitter.init_acceleration     [1] = Vec2 { 0, 0 };
        cloud_emitter.init_scale            [0] = 0.05;
        cloud_emitter.init_scale            [1] = 0.5;
        cloud_emitter.init_rotation         [0] = 0;
        cloud_emitter.init_rotation         [1] = 0;
        cloud_emitter.init_angular_velocity [0] = 0;
        cloud_emitter.init_angular_velocity [1] = 0;
        cloud_emitter.init_lifetime         [0] = 6000;
        cloud_emitter.init_lifetime         [1] = 8000;
        cloud_emitter.init_color_mod        [0] = { 1, 1, 1, 0.25 };
        cloud_emitter.init_color_mod        [1] = { 1, 1, 1, 1 };

        cloud_emitter.texture_clips.insert(cloud_emitter.texture_clips.end(), {
            { 0, 0, 980, 980 },
        });

        Game_State* gs = (Game_State*)data;
        gs->player.controller[PLAYER_KEY_BOUNCE_HIGH] = InputKey { .sc = { SDL_SCANCODE_X, (SDL_Scancode)0 }, .mod = (SDL_Keymod)0 };
        gs->player.controller[PLAYER_KEY_TILT_LEFT  ] = InputKey { .sc = { SDL_SCANCODE_Z, (SDL_Scancode)0 }, .mod = (SDL_Keymod)0 };
        gs->player.controller[PLAYER_KEY_TILT_RIGHT ] = InputKey { .sc = { SDL_SCANCODE_C, (SDL_Scancode)0 }, .mod = (SDL_Keymod)0 };

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


        if (current_time >= gs->next_jump_time) {
            Guy* new_guy;
            for (int i = 0; i < GUY_COUNT; i++) {
                Guy* guy = &gs->guys[i];
                if (!guy->active) {
                    new_guy = guy;
                    break;
                }
            }
            if (new_guy) {
                *new_guy = Guy {
                    .position = { 0, WINDOW_POSITIONS[rand() % 3] },
                    .velocity = { random_float(0.1, 0.3), random_float(-0.5, -0.1) },
                    .active = true,
                };
            }
            gs->next_jump_time = current_time += random_float(1, 4);
        }


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

            update_input_controller(gs->player.controller, PLAYER_KEY_COUNT);

            // move player
            Vec2 mouse_position_local = to_vec2(mouse.position - viewport.position) / to_vec2(viewport.size);
            if (mouse.left & KEYSTATE_PRESSED) {
                move_paddle_towards_target_position(&gs->player, mouse_position_local, 16);
            }

            // paddles must have positions limited by top and bottom of screen
            player->position.y = clamp(player->position.y, PLAYER_HEIGHT / 2.0, 1.0 - PLAYER_HEIGHT / 2.0);
            player->position.x = clamp(player->position.x, PLAYER_WIDTH  / 2.0, 1.0 - PLAYER_WIDTH  / 2.0);

            bool high_bounce_held = player->controller[PLAYER_KEY_BOUNCE_HIGH].state & KEYSTATE_PRESSED;


            // update guys
            for (int i = 0; i < GUY_COUNT; i++) {
                Guy* guy = &gs->guys[i];
                if (!guy->active)  continue;

                // apply gravity to guy
                guy->velocity.y += GUY_GRAVITY * delta_time;

                FRect guy_rect = get_guy_collision_rect(guy);
                Vec2  guy_move = guy->velocity * delta_time;

                FRect player_rect = get_player_collision_rect(player);
                Vec2  player_move = player->position - player->position_prev;

                float collision_time;
                Directions direction;
                if (swept_aabb_frect(&guy_rect, guy_move, &player_rect, player_move, &collision_time, &direction)) {
                    guy_move *= collision_time;

                    switch (direction) {
                      case DIR_L: {
                        if (guy->velocity.x <= 0) {
                            guy->velocity.x *= -GUY_BOUNCE_POWER_HIGH;
                        }
                        // float paddle_center_y = player->position.y;
                        // float distance_from_center = (guy->position.y - paddle_center_y) / PLAYER_HEIGHT;
                        // guy->velocity.y += distance_from_center * GUY_BOUNCE_DEFLECTION;
                      } break;

                      case DIR_R: {
                        if (guy->velocity.x >= 0) {
                            guy->velocity.x *= -GUY_BOUNCE_POWER_HIGH;
                        }
                        // float paddle_center_y = player->position.y;
                        // float distance_from_center = (guy->position.y - paddle_center_y) / PLAYER_HEIGHT;
                        // guy->velocity.y += distance_from_center * GUY_BOUNCE_DEFLECTION;
                      } break;

                      // case DIR_U: {
                      //   if (guy->velocity.y <= 0) {
                      //       if (high_bounce_held) {
                      //           guy->velocity.y *=  -GUY_BOUNCE_POWER_HIGH;
                      //       } else {
                      //           guy->velocity.y *=  -GUY_BOUNCE_POWER_LOW;
                      //       }
                      //       guy->velocity.y = fmin(guy->velocity.y, -GUY_BOUNCE_MIN);
                      //   }
                      //   // float paddle_center_x = player->position.x;
                      //   // float distance_from_center = (guy->position.x - paddle_center_x) / PLAYER_HEIGHT;
                      //   // guy->velocity.x += distance_from_center * GUY_BOUNCE_DEFLECTION;
                      // } break;

                      case DIR_D: {
                        if (guy->velocity.y >= 0) {
                            if (high_bounce_held) {
                                guy->velocity.y *=  -GUY_BOUNCE_POWER_HIGH;
                            } else {
                                guy->velocity.y *=  -GUY_BOUNCE_POWER_LOW;
                            }
                            guy->velocity.y = fmin(guy->velocity.y, -GUY_BOUNCE_MIN);
                        }
                        if (player->controller[PLAYER_KEY_TILT_LEFT].state & KEYSTATE_PRESSED) {
                            guy->velocity.x -= GUY_BOUNCE_DEFLECTION;
                        }
                        else if (player->controller[PLAYER_KEY_TILT_RIGHT].state & KEYSTATE_PRESSED) {
                            guy->velocity.x += GUY_BOUNCE_DEFLECTION;
                        }
                        // float paddle_center_x = player->position.x;
                        // float distance_from_center = (guy->position.x - paddle_center_x) / PLAYER_HEIGHT;
                        // guy->velocity.x += distance_from_center * GUY_BOUNCE_DEFLECTION;
                      } break;
                    }

                    // play bloop sound when bouncing off player
                    // Mix_Chunk *sound_to_play = player_i ? sound_bloop_1 : sound_bloop_2;
                    // Mix_PlayChannel(-1, sound_to_play, 0);
                }

                guy->position += guy_move;
                guy->rotation += guy->velocity.x * GUY_ROTATION_SPEED;

                if (guy->position.y > FLOOR_HEIGHT) {
                    guy->velocity.y = 0;
                    guy->active = false;
                    // TODO: make guy dead, remove life from player
                    gs->score -= 2;
                }
                if (guy->position.x < GUY_SIZE / 2.0) {
                    guy->position.x = GUY_SIZE / 2.0;
                    guy->velocity.x = -guy->velocity.x;
                }
                if (guy->position.x > 1.0 - GUY_SIZE / 2.0) {
                    guy->position.x = 1.0 - GUY_SIZE / 2.0;
                    guy->velocity.x = -guy->velocity.x;
                }
                guy->velocity.x = clamp(guy->velocity.x, -GUY_MAX_SPEED_X, GUY_MAX_SPEED_X);
                guy->velocity.y = clamp(guy->velocity.y, -GUY_MAX_SPEED_Y, GUY_MAX_SPEED_Y);

                if (is_point_within_rectf(guy->position, &safe_rect)) {
                    guy->active = false;
                    // TODO: spawn some cloud particles or something
                    gs->score += 1;
                }
            }
        }
    }

    // factored out so that we can call it before or after rendering other elements, depending on mode
    void render_player_scores(Game_State* gs) {
        Vec2i text_render_position;

        text_render_position = to_vec2i(to_vec2(viewport.size) * Vec2 { 0.5, 0.075 });
        render_small_text_int(gs->score, 0, text_render_position.x, text_render_position.y, 0, 0.5, 3.0);

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

        SDL_SetRenderDrawColor(renderer,
            (uint8_t)(0.3f * 255.0),
            (uint8_t)(0.3f * 255.0),
            (uint8_t)(0.3f * 255.0),
            (uint8_t)(0.3f * 255.0)
        );

        Rect building_rect = {
            .x = (int)(0.0f * (float)viewport.w),
            .y = (int)(0.0f * (float)viewport.h),
            .w = (int)(0.12f * (float)viewport.w),
            .h = (int)(0.9f * (float)viewport.h),
        };
        SDL_RenderFillRect(renderer, &building_rect.sdl);


        SDL_SetRenderDrawColor(renderer,
            (uint8_t)(text_render_color.r * 255.0),
            (uint8_t)(text_render_color.g * 255.0),
            (uint8_t)(text_render_color.b * 255.0),
            (uint8_t)(text_render_color.a * 255.0)
        );

        for (int i = 0; i < 3; i++) {
            Rect window_rect = {
                .x = (int)(0.00f * (float)viewport.w),
                .w = (int)(0.05f * (float)viewport.w),
                .h = (int)(0.15f * (float)viewport.h),
            };
            window_rect.y = (int)(WINDOW_POSITIONS[i] * (float)viewport.h) - window_rect.h / 2,
            SDL_RenderDrawRect(renderer, &window_rect.sdl);
        }

        update_particle_emitter(&cloud_emitter);
        render_all_particles(&cloud_emitter, Vec2 { 0, 0 });

        update_particle_emitter(&fire_emitter);
        render_all_particles(&fire_emitter, Vec2 { 0, 0 });

        Rect ambulance_rect = to_rect(safe_rect * to_vec2(viewport.size));
        SDL_RenderCopyEx(renderer, ambulance_texture.id, NULL, &ambulance_rect.sdl, 0, NULL, SDL_FLIP_NONE);

        Rect floor_render_rect = to_rect(floor_rect * to_vec2(viewport.size));
        SDL_RenderDrawRect(renderer, &floor_render_rect.sdl);


        // while in-game, render player scores below players and guy
        if (gs->mode == Mode::IN_GAME) {
            render_player_scores(gs);
        }

        // render player, guys
        {
            bool high_bounce_held = gs->player.controller[PLAYER_KEY_BOUNCE_HIGH].state & KEYSTATE_PRESSED;
            Color4 paddle_render_color = high_bounce_held ? Color4 { 1, 0, 0, 1 } : game_render_color;
            SDL_SetTextureColorMod(stretcher_texture.id,
                (uint8_t)(paddle_render_color.r * 255.0),
                (uint8_t)(paddle_render_color.g * 255.0),
                (uint8_t)(paddle_render_color.b * 255.0)
            );

            float paddle_rotation = 0;
            if (gs->player.controller[PLAYER_KEY_TILT_LEFT].state & KEYSTATE_PRESSED) {
                paddle_rotation = -15;
            } else if (gs->player.controller[PLAYER_KEY_TILT_RIGHT].state & KEYSTATE_PRESSED) {
                paddle_rotation = 15;
            }

            Player* player = &gs->player;
            Rect player_rect = get_player_render_rect(player);
            SDL_RenderCopyEx(renderer, stretcher_texture.id, NULL, &player_rect.sdl, paddle_rotation, NULL, SDL_FLIP_NONE);

            for (int i = 0; i < GUY_COUNT; i++) {
                Guy* guy = &gs->guys[i];
                if (!guy->active)  continue;
                Rect guy_rect = get_guy_render_rect(guy);
                SDL_RenderCopyEx(renderer, guy_texture.id, NULL, &guy_rect.sdl, guy->rotation, NULL, SDL_FLIP_NONE);
            }
        }


        if (gs->mode != Mode::IN_GAME) {
            // when not in-game, player scores get rendered above players and guy
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


