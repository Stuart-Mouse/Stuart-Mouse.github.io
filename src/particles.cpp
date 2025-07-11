

/*
    doing fully stateful particles first just to make things work

    particles need to be rendered relative to parent emitter/icon
    that is, their relative position should not be affected by window aspect, but should be affected by render scale


    can't just have a global particle buffer, because particles need to be rendered in groups that are relative to emitter position
    ok, for now we can still do a global buffer, but then we will also need to hold an icon id so that we can find out what offset to render from...
        this is still kind of bad bc then we have to figure out the center of icon, or offset of emitter relative to icon position
        so then we also need the emitter anyhow..
        and if we are going to need the emitter ever time we render a particle why aren't we just doing the more discreet thing anyhow...
        need to see if I can pull the OG particls file out of git history or something, may have some nuggets
*/

struct Particle {
    bool                  active; // used to mark a slot in the particle buffer as occupied

    Vec2                  position;
    Vec2                  velocity;
    Vec2                  acceleration;
    float                 rotation;
    float                 angular_velocity;
    Color4                color_mod;
    Color4                color_mod_active;
    float                 scale;
    
    float                 fadein_time;
    float                 fadeout_time;

    Texture               texture;
    Rect                  texture_clip;
    // TODO: override update procedure so that we can create particles with various behaviors

    uint32_t              spawn_time;
    uint32_t              lifetime;
};

bool update_particle(Particle* p) {
    if (!p || !p->active) return false;
    float timestep = (float)(g_ticks_this_frame - g_ticks_last_frame) / 1000.0f;
    
    p->velocity += p->acceleration     * timestep;
    p->position += p->velocity         * timestep;
    p->rotation += p->angular_velocity * timestep;
    
    // SDL_Rect window_rect = { 0, 0, window_width, window_height };
    // if (!is_point_within_rect(p->position, &window_rect)) {
    //     return false;
    // }
    
    float lifetime_lerp = clamp(((float)SDL_GetTicks() - (float)p->spawn_time) / (float)p->lifetime, 0.0, 1.0);
    // calculate alpha across lifetime
    // I think I will just hardcode this for now since we will only have one particle effect, and I want it to fade in/out in a very particular way
    

    assert(lifetime_lerp >= 0);
    assert(lifetime_lerp < 1.1);

    const float max_alpha = 1.0;

    p->color_mod_active = p->color_mod;

    // fade-in and fade-out particle
    if (lifetime_lerp < p->fadein_time) {
        p->color_mod_active.a *= lifetime_lerp / p->fadein_time;
    } else if (lifetime_lerp > 1.0 - p->fadeout_time) {
        p->color_mod_active.a *= ((1.0 - lifetime_lerp) / p->fadeout_time); // this is probably dumb
    }

    return SDL_GetTicks() < p->lifetime + p->spawn_time;
}

// passed offset should be in terms of pixels
void render_particle(Particle* p, Vec2 offset) {
    if (!p || !p->active) return;

    // for now, we are only considering the viewport width. really this should be some kind of option based on prefered axis
    // TODO: really, we should have some real concept of worldspace/screensapce distinction here, and maybe use a function pointer to do the conversion so that we can just define that in future projects
    float render_scale = p->scale * (float)viewport.w / (float)p->texture_clip.w;

    FRect frect;
    frect.size     = to_vec2(p->texture_clip.size) * render_scale;
    frect.position = (p->position + offset) * to_vec2(viewport.size) - (frect.size / 2.0);
    Rect rect = to_rect(frect);

    if (p->texture.id != NULL) {
        SDL_SetTextureColorMod(p->texture.id,
            (uint8_t)clamp(p->color_mod_active.r * 255.0, 0, 255),
            (uint8_t)clamp(p->color_mod_active.g * 255.0, 0, 255),
            (uint8_t)clamp(p->color_mod_active.b * 255.0, 0, 255)
        );
        SDL_SetTextureAlphaMod(p->texture.id,
            (uint8_t)clamp(p->color_mod_active.a * 255.0, 0, 255)
        );
        SDL_RenderCopyEx(
            renderer, p->texture.id,
            &p->texture_clip.sdl, &rect.sdl,
            p->rotation, NULL,
            SDL_FLIP_NONE
        );
    }
}

struct Particle_Emitter {
    FRect emit_box;

    uint32_t emit_freq [2];
    uint32_t next_emit_time;

    // TODO: should just use a vector with reserved size?
    Particle* particles;
    size_t particle_count;

    // min and max values for init value range
    Vec2   init_velocity         [2];
    Vec2   init_acceleration     [2];
    float  init_scale            [2];
    float  init_rotation         [2];
    float  init_angular_velocity [2];

    uint32_t  init_lifetime [2];

    Color4 init_color_mod [2]; // color range in each channel
    Color4 time_color_mod [2]; // start and end keyframes TODO: not implemented yet

    Texture texture;
    std::vector<Rect> texture_clips;
};

void init_particle_emitter(Particle_Emitter* e, size_t particle_count) {
    e->particles = (Particle*)calloc(particle_count, sizeof(Particle));
    e->particle_count = particle_count;
}

void deinit_particle_emitter(Particle_Emitter* e) {
    free(e->particles);
    memset(e, 0, sizeof(*e));
    // TODO: free particles texture?
}

void update_particle_emitter(Particle_Emitter* e) {
    if (e->particle_count <= 0) return;

    uint32_t ticks_now = SDL_GetTicks();
    if (ticks_now > e->next_emit_time) {
        // get first empty particle slot if one is avialable
        Particle* p = NULL;
        for (int i = 0; i < e->particle_count; i++) {
            if (!e->particles[i].active) {
                p = &e->particles[i];
                break;
            }
        }
        if (p != NULL) {
            e->next_emit_time = ticks_now + random_uint(e->emit_freq[0], e->emit_freq[1]);

            memset(p, 0, sizeof(Particle));

            p->active     = true;
            p->spawn_time = ticks_now;
            p->lifetime   = random_uint(e->init_lifetime[0], e->init_lifetime[1]);

            p->position.x = e->emit_box.x + random_float(0, e->emit_box.w);
            p->position.y = e->emit_box.y + random_float(0, e->emit_box.h);

            p->velocity.x = random_float(e->init_velocity[0].x, e->init_velocity[1].x);
            p->velocity.y = random_float(e->init_velocity[0].y, e->init_velocity[1].y);

            p->acceleration.x = random_float(e->init_acceleration[0].x, e->init_acceleration[1].x);
            p->acceleration.y = random_float(e->init_acceleration[0].y, e->init_acceleration[1].y);

            p->scale            = random_float(e->init_scale[0], e->init_scale[1]);
            p->rotation         = random_float(e->init_rotation[0], e->init_rotation[1]);
            p->angular_velocity = random_float(e->init_angular_velocity[0], e->init_angular_velocity[1]);

            // p->color_mod = Color4 { 1, 1, 1, 1 };
            p->color_mod = Color4 {
                .r = random_float(e->init_color_mod[0].r, e->init_color_mod[1].r),
                .g = random_float(e->init_color_mod[0].g, e->init_color_mod[1].g),
                .b = random_float(e->init_color_mod[0].b, e->init_color_mod[1].b),
                .a = random_float(e->init_color_mod[0].a, e->init_color_mod[1].a),
            };

            p->texture = e->texture;
            if (e->texture_clips.size() > 0) {
                p->texture_clip = e->texture_clips[random_int(0, e->texture_clips.size())];
            }
        }
    }

    // update all particles and check if they need to die
    for (int i = 0; i < e->particle_count; i++) {
        Particle* p = &e->particles[i];
        if (!update_particle(p)) {
            p->active = false;
        }
    }
}

void render_all_particles(Particle_Emitter* e, Vec2 layout_position) {
    Vec2 offset = layout_position * to_vec2(viewport.size);
    for (int i = 0; i < e->particle_count; i++) {
        Particle* p = &e->particles[i];
        render_particle(p, offset);
    }
}
