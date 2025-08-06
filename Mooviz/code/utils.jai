
Directions :: enum u8 {
    U_I   :: 0;
    R_I   :: 1;
    D_I   :: 2;
    L_I   :: 3;
    UR_I  :: 4;
    DR_I  :: 5;
    DL_I  :: 6;
    UL_I  :: 7;
     
    NONE  :: 0;
    U     :: 1 << U_I;
    R     :: 1 << R_I;
    D     :: 1 << D_I;
    L     :: 1 << L_I;
    UR    :: 1 << UR_I;
    DR    :: 1 << DR_I;
    DL    :: 1 << DL_I;
    UL    :: 1 << UL_I;

    USIDE :: U | UL | UR;
    DSIDE :: D | DL | DR;
    LSIDE :: L | UL | DL;
    RSIDE :: R | UR | DR;

    ALL   :: 0b_1111_1111;
}

direction_angles : [8] float = .[
    /* .U_I  */ 270,
    /* .R_I  */   0,
    /* .D_I  */  90,
    /* .L_I  */ 180,
    /* .UR_I */ 315,
    /* .DR_I */  45,
    /* .DL_I */ 225,
    /* .UL_I */ 135,
];

direction_opposite : [8] Directions = .[
    /* .U_I  */ .D_I,
    /* .R_I  */ .L_I,
    /* .D_I  */ .U_I,
    /* .L_I  */ .L_I,
    /* .UR_I */ .DL_I,
    /* .DR_I */ .UL_I,
    /* .DL_I */ .UR_I,
    /* .UL_I */ .DR_I,
];


Vec2f :: Vector2;
Vec2i :: struct {
    x, y : s32;
}

operator == :: (a: Vec2i, b: Vec2i) -> bool {
    return a.x == b.x && a.y == b.y;
}


operator + :: (a: Vec2i, b: Vec2i) -> Vec2i {
    return .{a.x+b.x, a.y+b.y};
}

operator - :: (a: Vec2i, b: Vec2i) -> Vec2i {
    return .{a.x-b.x, a.y-b.y};
}

operator - :: (a: Vec2i) -> Vec2i {
    return .{-a.x, -a.y};
}

operator * :: (a: Vec2i, b: Vec2i) -> Vec2i {
    // I always found it questionable to overload * as Hadamard product, but, I guess
    // this is what it is for now. We'll see if it causes confusion.
    // One example of potential confusion: * on Quaternion does a totally
    // different thing from * on Vector4.      -jblow, 7 January 2023.

    return .{a.x*b.x, a.y*b.y};
}

operator * :: (a: Vec2i, k: s32) -> Vec2i  #symmetric {
    return .{a.x*k, a.y*k};
}

operator / :: (a: Vec2i, b: Vec2i) -> Vec2i {
    return .{a.x/b.x, a.y/b.y};
}

operator / :: (a: Vec2i, k: s32) -> Vec2i {
    denom := 1 / k;
    return .{a.x*denom, a.y*denom};
}

operator / :: (k: s32, a: Vec2i) -> Vec2i {
    return .{k/a.x, k/a.y};
}



// Camera :: struct {
//     using position : Vector2;
// }
// // parameters to motion of camera
// camera_movement_lerp : float; // amount of time taken for the camera to lerp to the target position
// // parameters to the player's camera focus point
// camera_focus_distance        : float;
// camera_focus_lerp            : float;
// camera_focus_velocity_scalar : float;



Rect :: struct {
    x, y, w, h : s32;

    #place x; position : Vec2i = ---;
    #place w; size     : Vec2i = ---;
}

operator * :: (rect: Rect, scalar: s32) -> Rect {
    return .{
        x = rect.x * scalar,
        y = rect.y * scalar,
        w = rect.w * scalar,
        h = rect.h * scalar
    };
}

center :: inline (rect: Rect) -> Vector2 {
    return Vector2.{ cast(float)rect.x + cast(float)rect.w / 2,  cast(float)rect.y + cast(float)rect.h / 2 };
}


Rectf :: struct {
    x, y, w, h : float;

    #place x; position : Vector2 = ---;
    #place w; size     : Vector2 = ---;
}

operator * :: (rect: Rectf, scalar: float) -> Rectf {
    return .{
        x = rect.x * scalar,
        y = rect.y * scalar,
        w = rect.w * scalar,
        h = rect.h * scalar
    };
}

center :: inline (rectf: Rectf) -> Vector2 {
    return Vector2.{ rectf.x + rectf.w / 2,  rectf.y + rectf.h / 2 };
}


Color3 :: struct {
    r, g, b : float;

    #place r;
    component: [3] float = ---;
}

Color4 :: struct {
    r, g, b, a : float;

    #place r;
    rgb: Color3 = ---;

    #place r;
    component: [4] float = ---;
}

operator == :: (a: Color3, b: Color3) -> bool {
    return a.r == b.r && a.g == b.g && a.b == b.b;
}

operator == :: (a: Color4, b: Color4) -> bool {
    return a.r == b.r && a.g == b.g && a.b == b.b && a.a == b.a;
}

operator * :: (a: Color3, b: Color3) -> Color3 {
    return .{
        r = a.r * b.r,
        g = a.g * b.g,
        b = a.b * b.b,
    };
}

operator * :: (a: Color4, b: Color4) -> Color4 {
    return .{
        r = a.r * b.r,
        g = a.g * b.g,
        b = a.b * b.b,
        a = a.a * b.a,
    };
}

color3_from_bytes :: (r: u8, g: u8, b: u8) -> Color3 {
    return .{
        r = cast(float) r / 255,
        g = cast(float) g / 255,
        b = cast(float) b / 255,
    };  
}

color3_to_bytes :: (color: Color3) -> r: u8, g: u8, b: u8 {
    return
        cast(u8)(color.r * 255),
        cast(u8)(color.g * 255),
        cast(u8)(color.b * 255);
}

color4_from_bytes :: (r: u8, g: u8, b: u8, a: u8) -> Color4 {
    return .{
        r = cast(float) r / 255,
        g = cast(float) g / 255,
        b = cast(float) b / 255,
        a = cast(float) a / 255,
    };
}

color4_to_bytes :: (color: Color4) -> r: u8, g: u8, b: u8, a: u8 {
    return
        cast(u8)(color.r * 255),
        cast(u8)(color.g * 255),
        cast(u8)(color.b * 255),
        cast(u8)(color.a * 255);
}

// 0xaarrggbb
color4_from_u32 :: (color: u32) -> Color4 {
    return .{
        r = cast(float) (cast(*u8) *color + 2).* / 256,
        g = cast(float) (cast(*u8) *color + 1).* / 256,
        b = cast(float) (cast(*u8) *color + 0).* / 256,
        a = cast(float) (cast(*u8) *color + 3).* / 256,
    };
}
