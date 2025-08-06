

draw_square :: (position: Vector2, size: float, rotation: float = 0, color: Color4 = .{ 1, 1, 1, 1 }) {
    // temporary: unit conversion from world units to pixels is hardcoded here
    minor_dimension := cast(float) min(window_width, window_height);
    // major_dimension := cast(float) max(window_width, window_height);
    
    center   := Vector2.{ xx window_width, xx window_height } / 2;
    top_left := center - (Vector2.{ minor_dimension, minor_dimension } / 2);
    
    _position := position * minor_dimension + top_left;
    
    theta := cast(float) fmod_cycling(rotation, TAU);

    ct := cos(theta);
    st := sin(theta);
    
    s := minor_dimension * size / 2;

    w := Vector2.{s*ct,  s*st};
    h := Vector2.{s*st, -s*ct};

    p0 := _position - w - h;
    p1 := _position + w - h;
    p2 := _position + w + h;
    p3 := _position - w + h;
    
    c := (cast(*Vector4)*color).*;
    
    Simp.immediate_quad(p0, p1, p2, p3, c);
}


draw :: inline (vp: Viz_Point) {
    draw_square(vp.position, vp.size.x, vp.rotation, vp.color);
}

