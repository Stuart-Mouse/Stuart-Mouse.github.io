
// TODO: maybe we should assume the use of Enumerated_Array for the arrays of Simple_Animations which are indexed by a Simple_Animator.
//       then we can be sure that we will never index outside the proper bounds due to someone passing the wrong slice of animations
// If we do this, then maybe it's also worth considering easing the use of animators that switch on multiple enumerated values.
//       on the other hand, the animation state type can also just be an int, so there's that to consider
// Perhaps we can even make this work with string indexing though, since at current we just allow the user to pass any type for Anim_State.
// (In either case, we should apply some type restriction and and specifically only allow the properly supported types.)


// This will need to change if we have different framerates
TIMESTEP :: 1.0 / 60.0;

Simple_Animator :: struct(Anim_State: Type) {
    state:    Anim_State;
    current:  int;
    clock:    float;
    flags:    Simple_Animator_Flags;
}

Simple_Animator_Flags :: enum_flags {
    STOPPED;
}

// When frame count is zero, we take that to mean 'use an array view for frames'
Simple_Animation :: struct(FRAME_COUNT := 0) {
    #if FRAME_COUNT == 0 {
        frames:     [] Simple_Animation_Frame;   
    } else {
        frames:     Fixed_Array(FRAME_COUNT, Simple_Animation_Frame);
    }
    flags:  Simple_Animation_Flags;
}

// only needs to be called when FRAME_COUNT is 0 (using an array view for frames)
free_animation :: inline (animation: *Simple_Animation(0)) {
    #if animation.FRAME_COUNT == 0 {
        array_free(animation.frames);
    }
}

Simple_Animation_Flags :: enum_flags {
    LOOP;
    REVERSE; // TODO 
}

Simple_Animation_Frame :: struct {
    clip:       Rect;
    flip:       Direction_Flip;
    offset:     Vector2;
    duration:   float;
}

// sets the animation state and always restarts the animation, disables .STOPPED flag
start_animation :: (animator: *Simple_Animator, state: animator.Anim_State) {
    animator.state         = state;
    animator.current = 0;
    animator.clock   = 0;
    animator.flags &= ~.STOPPED;
}

// calls start_animation only if the desired state is different than the current state
set_animation :: (animator: *Simple_Animator, state: animator.Anim_State) {
    if animator.state != state {
        start_animation(animator, state);
    }
}

// won't change animation state if the desired animation state contains no frames
maybe_set_animation :: (animator: *Simple_Animator, state: animator.Anim_State, animations: [] Simple_Animation) {
    if animator.state != state && animations[xx state].frames.count > 0 {
        start_animation(animator, state);
    }
}

// TODO: still not sure about this, but maybe we do want to store a pointer to the animation(s) that an animator uses on the animator itself.
// problem is that not all animated things follow the same structure or need 2+ teirs to deciding what animations to play.

step_animator :: inline (animator: *Simple_Animator(void), animation: Simple_Animation, step: float = TIMESTEP) {
    step_animator_with_animation(animator, animation, step);
}

step_animator :: inline (animator: *Simple_Animator, animations: [] Simple_Animation, step: float = TIMESTEP) {
    current_animation := *animations[animator.state];
    step_animator_with_animation(animator, current_animation, step);
}

step_animator_with_animation :: (using animator: *Simple_Animator, animation: Simple_Animation, step: float = TIMESTEP) {
    if animation.frames.count < 1  return;
    if flags & .STOPPED  return;
    
    // assuming step > 0 for now...
    clock += step;
    
    if current > animation.frames.count then current = 0;
    if animation.frames[current].duration == 0  return;
    
    while clock >= animation.frames[current].duration {
        clock -= animation.frames[current].duration;
        current += 1;
        if current >= animation.frames.count {
            if animation.flags & .LOOP {
                current = 0;
            }
            else {
                current = animation.frames.count - 1;
                flags |= .STOPPED;
            }
        }
    }
}

get_frame_index_at_time :: (animation: Simple_Animation, time: float) -> int {
    time_so_far := 0.0;
    for 0..animation.frames.count-1 {
        frame := animation.frames[it];
        time_so_far += frame.duration;
        if time <= time_so_far  return it;
    }
    return animation.frames.count-1;
}

EMPTY_ANIMATION_FRAME :: Simple_Animation_Frame.{};

get_current_frame :: (animator: Simple_Animator, animation: [] Simple_Animation) -> *Simple_Animation_Frame {
    current_animation := animation[animator.state];
    // If the current animation has any frames, we expect that animator.current is within the bounds.
    if current_animation.frames.count == 0 {
        return *EMPTY_ANIMATION_FRAME;
    }
    return *current_animation.frames[animator.current];
}

get_current_frame :: (animator: Simple_Animator(void), animation: Simple_Animation) -> *Simple_Animation_Frame {
    return *animation.frames[animator.current];
}

