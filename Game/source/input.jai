
Mouse :: struct {
    position:       Vec2i;
    position_prev:  Vec2i;
    velocity:       Vec2i;
    left:           Key_State;
    middle:         Key_State;
    right:          Key_State;
    wheel:          Vec2i;
};

global_mouse: Mouse;

// TODO: this is dumb. should we not just check some context.has_mouse_focus and conditionally return the global mouse..?
//       although, we do use a separate mouse instance in the editor for reasons...

#add_context mouse: *Mouse = *global_mouse;
get_mouse :: () -> *Mouse { return context.mouse; }; // may return null if mouse is captured!
push_mouse :: (mouse: *Mouse) #expand {
    old_mouse := context.mouse;
    context.mouse = mouse;
    `defer context.mouse = old_mouse;
}

mouse_left     :: () -> Key_State { return ifx context.mouse then context.mouse.left;     }
mouse_right    :: () -> Key_State { return ifx context.mouse then context.mouse.right;    }
mouse_middle   :: () -> Key_State { return ifx context.mouse then context.mouse.middle;   }
mouse_position :: () -> Vec2i     { return ifx context.mouse then context.mouse.position; }
mouse_velocity :: () -> Vec2i     { return ifx context.mouse then context.mouse.velocity; }
mouse_wheel    :: () -> Vec2i     { return ifx context.mouse then context.mouse.wheel;    }

update_mouse :: () {
    // update mouse position
    global_mouse.position_prev = global_mouse.position;
     
    {
        x, y, ok := get_mouse_pointer_position(window, false);
        global_mouse.position.x = xx x;
        global_mouse.position.y = xx y;
    }
    
    global_mouse.velocity = .{ xx Input.mouse_delta_x, xx Input.mouse_delta_y };
    global_mouse.wheel.y  = xx Input.mouse_delta_z;
    
    // update mouse keys
    global_mouse.left   = 0b11 & ((global_mouse.left   << 1) | (keyboard_state[Key_Code.MOUSE_BUTTON_LEFT  ] & 1));
    global_mouse.middle = 0b11 & ((global_mouse.middle << 1) | (keyboard_state[Key_Code.MOUSE_BUTTON_MIDDLE] & 1));
    global_mouse.right  = 0b11 & ((global_mouse.right  << 1) | (keyboard_state[Key_Code.MOUSE_BUTTON_RIGHT ] & 1));
}


/*
  Input for "keys" in the game and editor are tracked with a persistent Key_State value:
    UP       : the key is unpressed, and was unpressed last frame
    DOWN     : the key is pressed  , and was pressed   last frame
    RELEASED : the key is unpressed, but was pressed   last frame
    PRESSED  : the key is pressed  , but was unpressed last frame
  These four state should capture anything we need to know about a given key at any given time.
  To check if a key is down at all, you can do an AND with PRESSED, since this will be true for both the DOWN and PRESSED states.
  Likewise, you can check if a key is up by doing an AND with RELEASED.
  If you need to know whether a button was just pressed or released, then compare equal to the corresponding value.
  Rarely do you need to use the state UP and DOWN by name, but they are given useful names nonetheless so that one can distinguish them from PRESSED and RELEASED.

  The Keys that we track for the editor or players in game are stored in a flat array and are indexed using an enum value.
  One can think of these as sort of "virtual" keys, since they are tied to the actual various functions we want the game or editor to perform.
  Then we bind these virtual keys to real keys by initializing the controller with the SDL_Scancode for the physical keyboard key we want to use for that virtual key.
  Once we add gamepad support, we can easily keep referring to keystates in the same way internally and just update the keystates based on gamepad instead of keyboard input in the update routine.

  The only wrinkle will be adding support for analog input, if we ever get around to that for this engine.

  To update a set of keys, we just pass the array slice of the inputkeys to the update function.
*/

Key_Code :: Input.Key_Code;

Key_State :: enum u8 {
    UP       :: 0b00;
    DOWN     :: 0b11;
    RELEASED :: 0b10;
    PRESSED  :: 0b01;
};

Key_Modifiers :: enum_flags {
    NONE  :: 0;
    SHIFT :: 0b0001;
    CTRL  :: 0b0010;
    ALT   :: 0b0100;
    META  :: 0b1000;
};

Input_Key :: struct {
    state:          Key_State;
    modifier:       Key_Modifiers;
    key_code:       [2] Key_Code;
    // gamepad_code:   Gamepad_Code;
};

key_modifier_state: Key_Modifiers;

keyboard_state: [Input.NUM_BUTTON_STATES] Key_State;

// TODO: factor in a more portable way
process_input_events :: () {
    // update all keyboard key states
    for *keyboard_state {
        it.* = 0b11 & ((it.* << 1) | (it.* & 1));
    }
    
    for Input.events_this_frame {
        if it.type == {
          case .QUIT;  quit = true;
          case .KEYBOARD;
            // overwrite bottom bit with current state
            keyboard_state[it.key_code] &= 0b10;
            keyboard_state[it.key_code] |= xx it.key_pressed;
        }
    }
    
    // collect key modifiers so we can see them all at once
    key_modifier_state = xx ((keyboard_state[Key_Code.SHIFT] & 1) << 0)
                          | ((keyboard_state[Key_Code.CTRL ] & 1) << 1) 
                          | ((keyboard_state[Key_Code.ALT  ] & 1) << 2) 
                          | ((keyboard_state[Key_Code.META ] & 1) << 3);
}

update_input_controller :: (controller: [] Input_Key, should_read_gamepad := false) {
    // if ImGui.GetIO().WantCaptureKeyboard {
    //     for *key: controller {
    //         key.state <<= 1;
    //         key.state  &= 0b11;
    //     }
    //     return;
    // }
    
    for *key: controller {
        state: Key_State;
        if key.modifier == key_modifier_state {
            state |= 0b1 & keyboard_state[key.key_code[0]];
            state |= 0b1 & keyboard_state[key.key_code[1]];
        }
        // if should_read_gamepad {
        //     state |= xx ifx gamepad.buttons[key.gamepad_code] & (.DOWN) then 1 else 0;
        // }
        key.state <<= 1;
        key.state  |= state;
        key.state  &= 0b11;
    }
}
