
Rect :: struct {
    x, y, w, h : s32;

    #overlay(x) position: Vec2i;
    #overlay(w) size:     Vec2i;
}

operator * :: (rect: Rect, scalar: s32) -> Rect #symmetric {
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

    #overlay(x) position: Vector2;
    #overlay(w) size:     Vector2;
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



Axis :: enum { NONE; X; Y; MINOR; MAJOR; }


get_aspect :: (rect: Rectf) -> float {
    return rect.w / rect.h;
}

get_aspect :: (rect: Rect) -> float {
    return get_aspect(to_Rectf(rect));
}

center_and_scale_rect_within_container :: (rect: Rectf, container: Rectf, scale_axis := Axis.NONE) -> Rectf {
    rect_aspect      := get_aspect(rect);
    container_aspect := get_aspect(container);
    
    scale := 1.0;
    
    if #complete scale_axis == {
      case .X;  scale = container.w / rect.w;
      case .Y;  scale = container.h / rect.h;
        
      case .MINOR;
        scale = ifx rect_aspect > container_aspect
            then container.h / rect.h
            else container.w / rect.w;
        
      case .MAJOR;
        scale = ifx rect_aspect < container_aspect
            then container.h / rect.h 
            else container.w / rect.w;
        
      case .NONE;
    }
    
    return center_rect_on_other(.{ position = rect.position, size = rect.size * scale }, container);
}

center_rect_on_point :: inline (rect: Rectf, point: Vec2f) -> Rectf {
    return .{
        position = point - rect.size / 2,
        size     = rect.size,
    };
} @NoProfile

center_rect_on_other :: inline (rect: Rectf, container: Rectf) -> Rectf {
    return .{
        position = container.position + (container.size - rect.size) / 2,
        size     = rect.size,
    };
} @NoProfile

make_rect_centered :: inline (size: Vec2f, center: Vec2f) -> Rectf {
    return .{
        position = center - size/2,
        size     = size,
    };
} @NoProfile

pin_rect :: inline (rect: Rectf, point: Vec2f, alignment: Vec2f) -> Rectf {
    return .{
        position = point - rect.size * alignment,
        size     = rect.size,
    };
}

