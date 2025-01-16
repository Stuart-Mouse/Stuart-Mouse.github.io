
typedef uint8_t KeyState;

#define KEYSTATE_RELEASED 0b0010
#define KEYSTATE_UP       0b0000
#define KEYSTATE_PRESSED  0b0001
#define KEYSTATE_DOWN     0b0011

struct InputKey {
	SDL_Keymod    mod;
	SDL_Scancode  sc[2];
	KeyState      state;
};

void update_input_controller(InputKey* controller, int count) {
	SDL_Keymod keymod = (SDL_Keymod)(SDL_GetModState() & (KMOD_ALT | KMOD_CTRL | KMOD_SHIFT));
	if (keymod & KMOD_ALT  ) keymod = (SDL_Keymod) (keymod | KMOD_ALT  );
	if (keymod & KMOD_CTRL ) keymod = (SDL_Keymod) (keymod | KMOD_CTRL );
	if (keymod & KMOD_SHIFT) keymod = (SDL_Keymod) (keymod | KMOD_SHIFT);
	const uint8_t *keys = SDL_GetKeyboardState(NULL);
	for (int i = 0; i < count; i++) {
		int state = 0;
		if (controller[i].mod == keymod) {
			state |= keys[controller[i].sc[0]];
			state |= keys[controller[i].sc[1]];
		}
		controller[i].state <<= 1;
		controller[i].state  |= state;
		controller[i].state  &= 0b11;
	}
}

struct {
    Vec2i position;
    Vec2i position_prev;
    Vec2i velocity;
    KeyState left;
    KeyState middle;
    KeyState right;
    Vec2i wheel;
    KeyState wheel_updated;
} mouse;

void update_mouse(void) {
	mouse.position_prev = mouse.position;
	uint32_t button_mask = SDL_GetMouseState(&mouse.position.x, &mouse.position.y);
	mouse.velocity = mouse.position - mouse.position_prev;
	mouse.wheel_updated <<= 1;
	mouse.wheel_updated &=  0b11;
	if (!mouse.wheel_updated) {
		mouse.wheel = Vec2i { 0, 0 };
	}
	uint32_t state;
	state = ((button_mask & SDL_BUTTON(SDL_BUTTON_LEFT))   != 0);
	mouse.left   = (state | (mouse.left   << 1)) & 0b11;
	state = ((button_mask & SDL_BUTTON(SDL_BUTTON_MIDDLE)) != 0);
	mouse.middle = (state | (mouse.middle << 1)) & 0b11;
	state = ((button_mask & SDL_BUTTON(SDL_BUTTON_RIGHT))  != 0);
	mouse.right  = (state | (mouse.right  << 1)) & 0b11;
}