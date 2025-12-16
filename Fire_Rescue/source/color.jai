
COLORS :: struct {
    WHITE    :: Color4.{1,1,1,1};
    BLACK    :: Color4.{0,0,0,1};
    RED      :: Color4.{1,0,0,1};
    GREEN    :: Color4.{0,1,0,1};
    BLUE     :: Color4.{0,0,1,1};
    YELLOW   :: Color4.{1,1,0,1};
    MAGENTA  :: Color4.{1,0,1,1};
    CYAN     :: Color4.{0,1,1,1};
};

Color3 :: struct {
    r, g, b : float;

    #overlay(r) component: [3] float;
}

Color4 :: struct {
    r, g, b, a : float;

    #overlay(r) rgb: Color3;
    #overlay(r) component: [4] float;
    #overlay(r) as_vector4: Vector4;
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

to_Color4 :: (v: Vector4) -> Color4 { return (*v).(*Color4).*; }
to_Color3 :: (v: Vector3) -> Color3 { return (*v).(*Color3).*; }

lerp :: (a: Color4, b: Color4, t: float) -> Color4 {
    return (*lerp((*a).(*Vector4).*, (*b).(*Vector4).*, t)).(*Color4).*;
}

color3_from_bytes :: (r: u8, g: u8, b: u8) -> Color3 {
    return .{
        r = r.(float) / 255,
        g = g.(float) / 255,
        b = b.(float) / 255,
    };  
}

color3_to_bytes :: (color: Color3) -> r: u8, g: u8, b: u8 {
    return
        (color.r * 255).(u8),
        (color.g * 255).(u8),
        (color.b * 255).(u8);
}

color4_from_bytes :: (r: u8, g: u8, b: u8, a: u8) -> Color4 {
    return .{
        r = r.(float) / 255,
        g = g.(float) / 255,
        b = b.(float) / 255,
        a = a.(float) / 255,
    };
}

color4_to_bytes :: (color: Color4) -> r: u8, g: u8, b: u8, a: u8 {
    return
        (color.r * 255).(u8),
        (color.g * 255).(u8),
        (color.b * 255).(u8),
        (color.a * 255).(u8);
}

// 0xaarrggbb
color4_from_u32 :: (color: u32) -> Color4 {
    return .{
        r = ((*color + 2).(*u8).* / 256).(float),
        g = ((*color + 1).(*u8).* / 256).(float),
        b = ((*color + 0).(*u8).* / 256).(float),
        a = ((*color + 3).(*u8).* / 256).(float),
    };
}

