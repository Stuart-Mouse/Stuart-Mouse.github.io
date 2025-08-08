
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

center :: inline (rect: Rect) -> Vec2i {
    return .{ rect.x + rect.w / 2,  rect.y + rect.h / 2 };
}


Rectf :: struct {
    x, y, w, h : float;

    #place x; position: Vector2 = ---;
    #place w; size:     Vector2 = ---;
}

operator * :: (rect: Rectf, scalar: float) -> Rectf #symmetric {
    return .{
        x = rect.x * scalar,
        y = rect.y * scalar,
        w = rect.w * scalar,
        h = rect.h * scalar
    };
}

center :: inline (rectf: Rectf) -> Vector2 {
    return .{ rectf.x + rectf.w / 2,  rectf.y + rectf.h / 2 };
}



// TODO: should port over some of my centering/scaling procedures from C
//       and/or make some more general versions like position_within() which would center some normalized point in one rect onto normalized point in other rect


