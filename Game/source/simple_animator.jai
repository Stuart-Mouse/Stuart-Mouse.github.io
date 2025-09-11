
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


Simple_Animation :: struct(FRAME_COUNT := 0) {
    #if FRAME_COUNT == 0 {
        // TODO: maybe this should just be a view? 
        // I think it is only dynamic because of the GON issue with loading views, and most animations are defined in GON files.
        frames:  [..] Simple_Animation_Frame;   
    } else {
        frames:       [FRAME_COUNT] Simple_Animation_Frame;
        frame_count:  int; // if non-zero, will be used as actual frame_count, that way, FRAME_COUNT can simply be a max count
    }
    flags:  Simple_Animation_Flags;
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
        if animation.frames[current].duration == 0  break;
        
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


// step_animator_with_animation :: (using animator: *Simple_Animator, animation: Simple_Animation, step: float = TIMESTEP) {
//     frame_count := get_frame_count(animation);
//     if frame_count < 1  return;
//     if flags & .STOPPED  return;
    
//     // assuming step > 0 for now...
//     clock += step;
    
//     if current > frame_count then current = 0;
//     if animation.frames[current].duration == 0  return;
    
//     while clock >= animation.frames[current].duration {
//         clock -= animation.frames[current].duration;
//         current += 1;
//         if current >= frame_count {
//             if animation.flags & .LOOP {
//                 current = 0;
//             }
//             else {
//                 current = frame_count - 1;
//                 flags |= .STOPPED;
//             }
//         }
//     }
// }

get_frame_count :: inline (animation: Simple_Animation) -> int {
    return #ifx animation.FRAME_COUNT == 0 then animation.frames.count
        else ifx animation.frame_count else animation.FRAME_COUNT;
}

get_frame_index_at_time :: (animation: Simple_Animation, time: float) -> int {
    frame_count := get_frame_count(animation);
    time_so_far := 0.0;
    for 0..frame_count-1 {
        frame := animation.frames[it];
        time_so_far += frame.duration;
        if time <= time_so_far  return it;
    }
    
    return animation.frames.count-1;
}

