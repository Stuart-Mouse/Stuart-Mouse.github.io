
/*
    Ideas:

    
    if we still want to have an ambulance on the right but simplify gameplay, 
        we can probably make the horizontal movement of the guy asymptotically slower as he approahces right side of screen
        
    
    audio:
        maybe some bg ambience track?
            crackling fire noises, wind, ambulancee sounds
        broken heart sfx
        
    art:
        fire/smoke particles
        cloud particles
        the outline-y bits on the building foreground actually need to go on the background layer so that they are rendered behind the guys
            I fixed this manually in gimp for now
        hearts for health meter
            regular heart and two broken heart pieces
            I plan to have these break apart and fall out of frame when you lose a guy
        title screen and game over screen art
            just a static image for each, I can maybe spruce up with particles if need be
        maybe have some sidewalk around building or somehow better blend the building with background
        bloody giblets particles and/or some animation frame for dudes begin flattened on the ground
            
    other: 
        maybe we should add new different types of guys? fat dudes and skinny dudes with different physics 
        If we want to keep the tilting/power bounce then we need new stretcher guys' animations frames for sure
        
    code:
        title screen/gameover code, high score tracking
        spawning bloody giblets particles
*/


namespace Fire_Rescue {
    const float PLAYER_HEIGHT     = 0.02;
    const float PLAYER_WIDTH      = 0.1;

    const float GAME_OVER_TIME    = 2.0;
    const float GAME_READY_TIME   = 2.0;

    const float GUY_SIZE                = 0.15;
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
    
    std::vector<Mix_Chunk*> bounce_sounds;
    std::vector<Mix_Chunk*> dead_sounds;
    std::vector<Mix_Chunk*> safe_sounds;
    
    Mix_Chunk* poof_sound = NULL;
    
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

    // these are the window positions used for spawning guys
    const float WINDOW_POSITIONS[3] = { 280.0f/2048.0f, 770.0f/2048.0f, 1220.0f/2048.0f };

    const float FLOOR_HEIGHT = 0.95;

    const int SCORE_TO_WIN = 5;

    Texture cloud_texture;
    Texture fire_texture;
    Texture guy_texture;
    Texture stretcher_texture;
    Texture ambulance_texture;
    
    Rect guy_clips[7] = {
        { 270*0, 270*0, 270, 270 },
        { 270*1, 270*0, 270, 270 },
        { 270*2, 270*0, 270, 270 },
        { 270*0, 270*1, 270, 270 },
        { 270*1, 270*1, 270, 270 },
        { 270*2, 270*1, 270, 270 },
        { 270*0, 270*2, 270, 270 },
    };
    
    Rect stretcher_clips[6] = {
        { 460*0, 285*0, 460, 285 },
        { 460*1, 285*0, 460, 285 },
        { 460*2, 285*0, 460, 285 },
        { 460*0, 285*1, 460, 285 },
        { 460*1, 285*1, 460, 285 },
        { 460*2, 285*1, 460, 285 },
    };
    
    Texture bg_sky;
    Texture bg_city;
    Texture bg_clouds;
    Texture bg_building_back;
    Texture bg_building_front;
    
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
        
        int     lives;

        float   next_jump_time;
        
        std::array<Particle, 256> fg_particles;
        
        Mode    mode;
        float   time_of_last_mode_change;
    };

    FRect get_player_collision_rect(Player* p) {
        return FRect {
            (p->position.x - PLAYER_WIDTH  * 0.5f),
            (p->position.y - PLAYER_HEIGHT * 0.0f),
            PLAYER_WIDTH,
            PLAYER_HEIGHT,
        };
    }

    Rect get_player_render_rect(Player* p) {
        Rect rect;
        rect.size.x = (int)(PLAYER_WIDTH * 3.0f * (float)viewport.h);
        rect.size.y = (int)((float)rect.size.x * (float)stretcher_clips[0].h / (float)stretcher_clips[0].w);
        rect.position = Vec2i {
            (int)(p->position.x * (float)viewport.w) - rect.w / 2,
            (int)(p->position.y * (float)viewport.h) - rect.h / 2,
        };
        return rect;
    }
    
    Rect* get_player_render_clip(Player* p) {
        int index = (int)(p->position.x * 100.0) % 6;
        return &stretcher_clips[index];
    }
    
    FRect get_guy_collision_rect(Guy* b) {
        return FRect {
            (b->position.x - GUY_SIZE / 4.0f),
            (b->position.y - GUY_SIZE / 4.0f),
            GUY_SIZE / 2.0f,
            GUY_SIZE / 2.0f,
        };
    }
    
    Rect get_guy_render_rect(Guy* b) {
        Rect rect;
        rect.size = Vec2i {
            (int)(GUY_SIZE * (float)viewport.h),
            (int)(GUY_SIZE * (float)viewport.h),
        };
        rect.position = Vec2i {
            (int)(b->position.x * (float)viewport.w) - rect.w / 2,
            (int)(b->position.y * (float)viewport.h) - rect.h / 2,
        };
        return rect;
    }
    
    Rect* get_guy_render_clip(Guy* b) {
        float current_time = get_seconds_since_init();
        float frame_time = 0.1;
        float index_f = current_time/frame_time;
        int index = (int)index_f % 7;
        return &guy_clips[index];
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
        gs->lives = 3;
        
        for (Guy& guy: gs->guys) {
            guy = Guy {};
        }
        
        // set mode and time stuff
        gs->mode = Mode::READY;
        gs->time_of_last_mode_change = get_seconds_since_init();
    }
    
    Mix_Chunk* load_sound(const char* path) {
        Mix_Chunk* chunk = Mix_LoadWAV(path);
        if (!chunk) printf("Unable to load audio from file %s\n", path);
        return chunk;
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
        if (!load_texture(renderer, &cloud_texture, "media/cloud.png")) {
            printf("failed to load cloud texture");
        }
        if (!load_texture(renderer, &fire_texture, "media/fire.png")) {
            printf("failed to load fire texture");
        }
        
        if (!load_texture(renderer, &bg_sky, "media/bg/bg_sky.png")) {
            printf("failed to load texture \"bg_sky.png\"");
        }
        if (!load_texture(renderer, &bg_city, "media/bg/bg_city.png")) {
            printf("failed to load texture \"bg_city.png\"");
        }
        if (!load_texture(renderer, &bg_clouds, "media/bg/bg_clouds.png")) {
            printf("failed to load texture \"bg_clouds.png\"");
        }
        if (!load_texture(renderer, &bg_building_back, "media/bg/bg_building_back.png")) {
            printf("failed to load texture \"bg_building_back.png\"");
        }
        if (!load_texture(renderer, &bg_building_front, "media/bg/bg_building_front.png")) {
            printf("failed to load texture \"bg_building_front.png\"");
        }
        
        
        poof_sound = load_sound("media/sfx/poof.mp3");
        
        std::array<char*, 29> bounce_sounds_paths = {
            "media/sfx/1.mp3",
            "media/sfx/2.mp3",
            "media/sfx/3.mp3",
            "media/sfx/4.mp3",
            "media/sfx/5.mp3",
            "media/sfx/6.mp3",
            "media/sfx/ahh.mp3",
            "media/sfx/ahh1.mp3",
            "media/sfx/ahhh.mp3",
            "media/sfx/ahhhh.mp3",
            "media/sfx/ahhhh1.mp3",
            "media/sfx/daaa.mp3",
            
            "media/sfx/duhhh.mp3",
            "media/sfx/eyugh.mp3",
            "media/sfx/eyugh1.mp3",
            "media/sfx/eyugh2.mp3",
            "media/sfx/eyugh3.mp3",
            "media/sfx/goo.mp3",
            "media/sfx/heeel.mp3",
            "media/sfx/huh.mp3",
            "media/sfx/hyuohh.mp3",
            "media/sfx/ohhh.mp3",
            "media/sfx/ohhh1.mp3",
            "media/sfx/ooo.mp3",
            "media/sfx/ooo1.mp3",
            "media/sfx/ooo2.mp3",
            "media/sfx/owo.mp3",
            "media/sfx/woah.mp3",
            "media/sfx/woah1.mp3",
        };
        for (const char* path: bounce_sounds_paths) {
            Mix_Chunk* chunk = load_sound(path);
            if (chunk) bounce_sounds.push_back(chunk);
        }
        
        
        std::array<char*, 5> safe_sounds_paths = {
            "media/sfx/safe.mp3",
            "media/sfx/safe1.mp3",
            "media/sfx/safe2.mp3",
            "media/sfx/safe3.mp3",
            "media/sfx/safe4.mp3",
        };
        for (const char* path: safe_sounds_paths) {
            Mix_Chunk* chunk = load_sound(path);
            if (chunk) safe_sounds.push_back(chunk);
        }
        
        
        std::array<char*, 4> dead_sounds_paths = {
            "media/sfx/dead.mp3",
            "media/sfx/dead1.mp3",
            "media/sfx/dead2.mp3",
            "media/sfx/dead3.mp3",
        };
        for (const char* path: dead_sounds_paths) {
            Mix_Chunk* chunk = load_sound(path);
            if (chunk) dead_sounds.push_back(chunk);
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
            
            Mix_Chunk* sound_to_play = bounce_sounds[rand() % bounce_sounds.size()];
            Mix_PlayChannel(-1, sound_to_play, 0);
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
                        
                        Mix_PlayChannel(-1, poof_sound, 0);
                        
                        Mix_Chunk* sound_to_play = bounce_sounds[rand() % bounce_sounds.size()];
                        Mix_PlayChannel(-1, sound_to_play, 0);
                        
                        // spawn some cloud particles when player bounces
                        for (int i = 0; i < 10; i++) {
                            uint32_t ticks_now = SDL_GetTicks();
                            
                            Particle* p = NULL;
                            for (Particle& p0: gs->fg_particles) {
                                if (!p0.active) { p = &p0; break; }
                            }
                            
                            memset(p, 0, sizeof(Particle));
                            
                            p->active     = true;
                            p->spawn_time = ticks_now;
                            p->lifetime   = (int)(random_float(0.25, 0.5) * 1000.0f);
                            
                            p->position.x = guy->position.x + random_float(-0.04, 0.04);
                            p->position.y = guy->position.y + random_float(-0.02, 0.02) + GUY_SIZE / 2;
                            
                            p->velocity.x = random_float(-0.1,  0.1);
                            p->velocity.y = random_float(0.0f, 0.5f) * guy->velocity.y;
                            // Vec2 {  0.0,  -0.00003   };
                            // Vec2 {  0.0,  -0.000005  };
                            // Vec2 { -0.0000001, -0.0000006 };
                            // Vec2 {  0.0000001, -0.0000002 };
                            // p->acceleration.x = random_float(e->init_acceleration[0].x, e->init_acceleration[1].x);
                            // p->acceleration.y = random_float(e->init_acceleration[0].y, e->init_acceleration[1].y);
                            
                            p->scale            = random_float(0.03f, 0.06f);
                            // p->rotation         = random_float();
                            // p->angular_velocity = random_float();
                            
                            // p->color_mod = Color4 { 1, 1, 1, 1 };
                            p->color_mod = Color4 {
                                .r = 1.0,
                                .g = 1.0,
                                .b = 1.0,
                                .a = random_float(0.5, 0.9),
                            };
                            
                            p->fadeout_time = 1.0;
                            p->texture = cloud_texture;
                            p->texture_clip = Rect { 0, 0, cloud_texture.width, cloud_texture.height };
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
                    
                    gs->lives -= 1;
                    
                    Mix_Chunk* sound_to_play = dead_sounds[rand() % dead_sounds.size()];
                    Mix_PlayChannel(-1, sound_to_play, 0);
                }
                if (guy->position.x < 0) {
                    guy->position.x = 0;
                    guy->velocity.x = -guy->velocity.x;
                }
                if (guy->position.x > 1.0) {
                    guy->position.x = 1.0;
                    guy->velocity.x = -guy->velocity.x;
                }
                guy->velocity.x = clamp(guy->velocity.x, -GUY_MAX_SPEED_X, GUY_MAX_SPEED_X);
                guy->velocity.y = clamp(guy->velocity.y, -GUY_MAX_SPEED_Y, GUY_MAX_SPEED_Y);

                if (is_point_within_rectf(guy->position, &safe_rect)) {
                    guy->active = false;
                    // TODO: spawn some cloud particles or something
                    gs->score += 1;
                    
                    Mix_Chunk* sound_to_play = safe_sounds[rand() % safe_sounds.size()];
                    Mix_PlayChannel(-1, sound_to_play, 0);
                }
            }
        }
        
        for (Particle& p: gs->fg_particles) {
            if (!update_particle(&p)) {
                p.active = false;
            }
        }
        
        if (gs->mode == Mode::IN_GAME && gs->lives <= 0) {
            gs->mode = Mode::GAME_OVER;
            gs->time_of_last_mode_change = current_time;
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
        const Color4 black = { 0, 0, 0, 1 };

        Color4 text_render_color = black;
        Color4 game_render_color = white;

        SDL_SetTextureColorMod(small_text_texture.id,
            (uint8_t)(text_render_color.r * 255.0),
            (uint8_t)(text_render_color.g * 255.0),
            (uint8_t)(text_render_color.b * 255.0)
        );
        
        float bg_aspect = 640.0f/480.0f;
        Rect bg_rect = { (int)(0.12*viewport.w), 0, (int)((float)viewport.h * bg_aspect), viewport.h };
        SDL_RenderCopy(renderer, bg_sky.id, NULL, NULL);
        
        // render bg clouds twice at different offsets to create illusion of moving clouds looping around
        {
            float time_lerp = fmodf(get_seconds_since_init(), 30.0) / 30.0;
            Rect bg_rect = { (int)((float)viewport.w * time_lerp), 0, viewport.w, viewport.h };
            SDL_RenderCopy(renderer, bg_clouds.id, NULL, &bg_rect.sdl);
            bg_rect = { (int)((float)viewport.w * (-1.0 + time_lerp)), 0, viewport.w, viewport.h };
            SDL_RenderCopy(renderer, bg_clouds.id, NULL, &bg_rect.sdl);
        }
        
        SDL_RenderCopy(renderer, bg_city.id, NULL, &bg_rect.sdl);
        
        bg_rect = Rect { 0, 0, (int)((float)viewport.h * bg_aspect), viewport.h };
        SDL_RenderCopy(renderer, bg_building_back.id, NULL, &bg_rect.sdl);
        
        SDL_SetRenderDrawColor(renderer,
            (uint8_t)(text_render_color.r * 255.0),
            (uint8_t)(text_render_color.g * 255.0),
            (uint8_t)(text_render_color.b * 255.0),
            (uint8_t)(text_render_color.a * 255.0)
        );

        // for (int i = 0; i < 3; i++) {
        //     Rect window_rect = {
        //         .x = (int)(0.00f * (float)viewport.w),
        //         .w = (int)(0.05f * (float)viewport.w),
        //         .h = (int)(0.15f * (float)viewport.h),
        //     };
        //     window_rect.y = (int)(WINDOW_POSITIONS[i] * (float)viewport.h) - window_rect.h / 2,
        //     SDL_RenderDrawRect(renderer, &window_rect.sdl);
        // }

        // update_particle_emitter(&cloud_emitter);
        // render_all_particles(&cloud_emitter, Vec2 { 0, 0 });

        // update_particle_emitter(&fire_emitter);
        // render_all_particles(&fire_emitter, Vec2 { 0, 0 });

        Rect ambulance_rect = to_rect(safe_rect * to_vec2(viewport.size));
        SDL_RenderCopyEx(renderer, ambulance_texture.id, NULL, &ambulance_rect.sdl, 0, NULL, SDL_FLIP_NONE);

        // Rect floor_render_rect = to_rect(floor_rect * to_vec2(viewport.size));
        // SDL_RenderDrawRect(renderer, &floor_render_rect.sdl);

        // while in-game, render player scores below players and guy
        if (gs->mode == Mode::IN_GAME) {
            render_player_scores(gs);
        }

        // render player, guys
        {
            bool high_bounce_held = gs->player.controller[PLAYER_KEY_BOUNCE_HIGH].state & KEYSTATE_PRESSED;
            // Color4 paddle_render_color = high_bounce_held ? Color4 { 1, 0, 0, 1 } : game_render_color;
            // SDL_SetTextureColorMod(stretcher_texture.id,
            //     (uint8_t)(paddle_render_color.r * 255.0),
            //     (uint8_t)(paddle_render_color.g * 255.0),
            //     (uint8_t)(paddle_render_color.b * 255.0)
            // );
            
            float paddle_rotation = 0;
            if (gs->player.controller[PLAYER_KEY_TILT_LEFT].state & KEYSTATE_PRESSED) {
                paddle_rotation = -7;
            } else if (gs->player.controller[PLAYER_KEY_TILT_RIGHT].state & KEYSTATE_PRESSED) {
                paddle_rotation = 7;
            }

            Player* player = &gs->player;
            Rect player_rect = get_player_render_rect(player);
            Rect* clip = get_player_render_clip(player);
            SDL_RenderCopyEx(renderer, stretcher_texture.id, &clip->sdl, &player_rect.sdl, paddle_rotation, NULL, SDL_FLIP_NONE);

            for (int i = 0; i < GUY_COUNT; i++) {
                Guy* guy = &gs->guys[i];
                if (!guy->active)  continue;
                
                Rect guy_rect = get_guy_render_rect(guy);
                Rect* clip = get_guy_render_clip(guy);
                SDL_RenderCopyEx(renderer, guy_texture.id, &clip->sdl, &guy_rect.sdl, guy->rotation, NULL, SDL_FLIP_NONE);
            }
        }
        
        SDL_RenderCopy(renderer, bg_building_front.id, NULL, &bg_rect.sdl);
        
        for (Particle& p: gs->fg_particles) {
            render_particle(&p, Vec2 { 0, 0 });
        }

        if (gs->mode != Mode::IN_GAME) {
            // when not in-game, player scores get rendered above players and guy
            render_player_scores(gs);
            
            // render text for READY? and GAME_OVER modes
            Vec2 text_render_position = Vec2 { 0.5f * (float)viewport.w, 0.25f * (float)viewport.h };
            if (gs->mode == Mode::READY) {
                render_small_text("READY?", text_render_position.x, text_render_position.y, 0, 0.5, 3.0);
            }
            if (gs->mode == Mode::GAME_OVER) {
                render_small_text("GAME OVER", text_render_position.x, text_render_position.y, 0, 0.5, 3.0);
            }
            
            // TODO: title screen mode, render high score (init with some default high score to beat)
            
            // maybe also add high score table screen allowing players to enter their nickname
            // or maybe we wait until we have some protocol for getting user data from the main site
        }
    }
}


