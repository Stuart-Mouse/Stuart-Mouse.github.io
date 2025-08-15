
Vec2f :: Vector2;
Vec2i :: struct { x, y : s32; }

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



floor :: inline (v: Vec2f) -> Vec2f { return .{ floor(v.x), floor(v.y) }; } @NoProfile

// NOTE: to_Vec2i simply truncates, hence the existence of to_Vec2i_floor
to_Vec2i       :: inline (v: Vec2f) -> Vec2i { return .{ v.x.(s32), v.y.(s32) }; } @NoProfile
to_Vec2i_floor :: inline (v: Vec2f) -> Vec2i { return .{ floor(v.x).(s32), floor(v.y).(s32) }; } @NoProfile

to_Vector2     :: inline (v: Vec2i) -> Vec2f { return .{ v.x.(float), v.y.(float) }; } @NoProfile
to_Vec2f       :: to_Vector2; @NoProfile

to_Vec2f :: inline (f: float) -> Vec2f { return .{ f, f }; } @NoProfile
to_Vec2i :: inline (i: s32  ) -> Vec2i { return .{ i, i }; } @NoProfile

frac :: inline (v: Vector2) -> Vector2 { return .{ frac(v.x), frac(v.y) }; } @NoProfile



close_enough :: inline (a: Vec2f, b: Vec2f, epsilon := 0.0001) -> bool {
    return abs(a.x - b.x) < epsilon && abs(a.y - b.y) < epsilon;
}


// functions for getting distance or scaled vector of one vector along another vector
// I added _nonneg variants for the vector ones since that needs to be done between getting distance and scaling the vector, 
// but having _nonneg variants for the distance ones seems silly since you can just use max(..., 0)

distance_along_unit_vector :: (v: Vector2, u: Vector2) -> float {
    return (v.x * u.x) + (v.y * u.y);
} @NoProfile
vector_along_unit_vector :: (v: Vector2, u: Vector2) -> Vector2 {
    return u * distance_along_unit_vector(v, u);
} @NoProfile
vector_along_unit_vector_nonneg :: (v: Vector2, u: Vector2) -> Vector2 {
    return u * max(distance_along_unit_vector(v, u), 0);
} @NoProfile

distance_along_angle_radians :: (v: Vector2, a: float) -> float {
    u := unit_vector_given_angle(a);
    return (v.x * u.x) + (v.y * u.y);
} @NoProfile
vector_along_angle_radians :: (v: Vector2, a: float) -> Vector2 {
    u := unit_vector_given_angle(a);
    return u * ((v.x * u.x) + (v.y * u.y));
} @NoProfile
vector_along_angle_radians_nonneg :: (v: Vector2, a: float) -> Vector2 {
    u := unit_vector_given_angle(a);
    return u * max((v.x * u.x) + (v.y * u.y), 0);
} @NoProfile

distance_along_angle_degrees :: (v: Vector2, a: float) -> float {
    u := unit_vector_given_angle(a * PI / 180);
    return (v.x * u.x) + (v.y * u.y);
} @NoProfile
vector_along_angle_degrees :: (v: Vector2, a: float) -> Vector2 {
    u := unit_vector_given_angle(a * PI / 180);
    return u * ((v.x * u.x) + (v.y * u.y));
} @NoProfile
vector_along_angle_degrees_nonneg :: (v: Vector2, a: float) -> Vector2 {
    u := unit_vector_given_angle(a * PI / 180);
    return u * max((v.x * u.x) + (v.y * u.y), 0);
} @NoProfile


// distance_between_points :: (p1, p2: Vector2) -> float32 {
//     dx := p1.x - p2.x;
//     dy := p1.y - p2.y;
//     return math.sqrt((dx * dx) + (dy * dy));
// }

angle_between_points :: (p1: Vector2, p2: Vector2) -> float32 {
    return atan2(p2.y - p1.y, p2.x - p1.x);
} @NoProfile

unit_vector_given_angle :: (angle: float) -> Vector2 {
    return .{ cos(angle), sin(angle) };
} @NoProfile

unit_vector_given_angle_degrees :: (angle: float) -> Vector2 {
    angle = angle * PI / 180.0;
    return .{ cos(angle), sin(angle) };
} @NoProfile

unit_vector_between_points :: (p1: Vector2, p2: Vector2) -> Vector2 {
    return unit_vector(p2 - p1);
} @NoProfile

rotate_radians :: (subject: Vector2, radians: float) -> Vector2 {
	sin_t := sin(radians);
    cos_t := cos(radians);
	return .{
		x = subject.x * cos_t - subject.y * sin_t,
		y = subject.y * cos_t + subject.x * sin_t
	};
} @NoProfile

rotate_degrees :: (subject: Vector2, degrees: float) -> Vector2 {
	radians := degrees * PI / 180.0;
	return rotate_radians(subject, radians);
} @NoProfile

rotate_around_point_radians :: (subject: Vector2, point: Vector2, radians: float) -> Vector2 {
	result := subject - point;
	result = rotate_radians(result, radians);
	result += point;
	return result;
} @NoProfile

rotate_around_point_degrees :: (subject: Vector2, point: Vector2, degrees: float) -> Vector2 {
	radians := degrees * PI / 180.0;
	return rotate_around_point_radians(subject, point, radians);
} @NoProfile




multiply :: (m: $T/interface AnyMatrix3, v: Vector2) -> Vector2 {
    result: Vector2 = ---;
    result.x = m._11 * v.x + m._12 * v.y;
    result.y = m._21 * v.x + m._22 * v.y;
    return result;
} @NoProfile

transform_vector :: (m: $T/interface AnyMatrix3, v: Vector2) -> Vector2 {
    return inline multiply(m, v);
} @NoProfile


scale_to_height :: inline (v: Vec2f, f: float) -> Vec2f {
    return v * (f / v.y);
} @NoProfile

scale_to_width :: inline (v: Vec2f, f: float) -> Vec2f {
    return v * (f / v.x);
} @NoProfile

scale_by_axis :: inline (v: Vec2f, f: float, axis: Axis) -> Vec2f {
    return v * (f / get_axis(v, axis));
} @NoProfile

get_axis :: inline (v: Vec2f, axis: Axis) -> float {
    if #complete axis == {
      case .X;      return v.x;
      case .Y;      return v.y;
      case .MINOR;  return min(v.x, v.y);
      case .MAJOR;  return max(v.x, v.y);
      case .NONE;
    }
    return 0; // .NONE or invalid values
} @NoProfile;
