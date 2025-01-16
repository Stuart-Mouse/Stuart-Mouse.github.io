
struct Vec2 {
    float x, y;
    
    Vec2 operator+(Vec2 b) {
        return Vec2 { x + b.x, y + b.y };
    }
    Vec2 operator-(Vec2 b) {
        return Vec2 { x - b.x, y - b.y };
    }
    Vec2 operator*(Vec2 b) {
        return Vec2 { x * b.x, y * b.y };
    }
    Vec2 operator/(Vec2 b) {
        return Vec2 { x / b.x, y / b.y };
    }
    
    Vec2 operator+(float b) {
        return Vec2 { x + b, y + b };
    }
    Vec2 operator-(float b) {
        return Vec2 { x - b, y - b };
    }
    Vec2 operator*(float b) {
        return Vec2 { x * b, y * b };
    }
    Vec2 operator/(float b) {
        return Vec2 { x / b, y / b };
    }
    
    Vec2 operator+=(Vec2 b) {
        return Vec2 { x += b.x, y += b.y };
    }
    Vec2 operator-=(Vec2 b) {
        return Vec2 { x -= b.x, y -= b.y };
    }
    Vec2 operator*=(Vec2 b) {
        return Vec2 { x *= b.x, y *= b.y };
    }
    Vec2 operator/=(Vec2 b) {
        return Vec2 { x /= b.x, y /= b.y };
    }
    
    Vec2 operator+=(float b) {
        return Vec2 { x += b, y += b };
    }
    Vec2 operator-=(float b) {
        return Vec2 { x -= b, y -= b };
    }
    Vec2 operator*=(float b) {
        return Vec2 { x *= b, y *= b };
    }
    Vec2 operator/=(float b) {
        return Vec2 { x /= b, y /= b };
    }
};

union Vec2i {
    struct { int32_t x, y; };
    SDL_Point sdl_point;
    
    Vec2i operator+(Vec2i b) {
        return Vec2i { x + b.x, y + b.y };
    }
    Vec2i operator-(Vec2i b) {
        return Vec2i { x - b.x, y - b.y };
    }
    Vec2i operator*(Vec2i b) {
        return Vec2i { x * b.x, y * b.y };
    }
    Vec2i operator/(Vec2i b) {
        return Vec2i { x / b.x, y / b.y };
    }
    
    Vec2i operator+(int b) {
        return Vec2i { x + b, y + b };
    }
    Vec2i operator-(int b) {
        return Vec2i { x - b, y - b };
    }
    Vec2i operator*(int b) {
        return Vec2i { x * b, y * b };
    }
    Vec2i operator/(int b) {
        return Vec2i { x / b, y / b };
    }
};

struct Color4 {
    float r, g, b, a;
};

union Rect {
    struct { Vec2i position, size; };
    struct { int32_t x, y, w, h; };
    SDL_Rect sdl; 
};

Rect make_centered_rect(int x, int y, int w, int h) {
    Rect ret;
    ret.w = w;
    ret.h = h;
    ret.x = x - w / 2;
    ret.y = y - y / 2;
    return ret;
}

union FRect {
    struct { Vec2 position, size; };
    struct { float x, y, w, h; };
    SDL_FRect sdl; 
    
    FRect operator*(FRect b) {
        return FRect { x * b.x, y * b.y, w * b.w, h * b.h };
    }
};

FRect make_centered_frect(float x, float y, float w, float h) {
    FRect ret;
    ret.w = w;
    ret.h = h;
    ret.x = x - w / 2.0;
    ret.y = y - h / 2.0;
    return ret;
}


Rect to_rect(FRect frect) { 
    return Rect {
        .x = (int) frect.x,
        .y = (int) frect.y,
        .w = (int) frect.w,
        .h = (int) frect.h,
    };
}

FRect to_frect(Rect rect) { 
    return FRect {
        .x = (float) rect.x,
        .y = (float) rect.y,
        .w = (float) rect.w,
        .h = (float) rect.h,
    };
}




struct Matrix4 {
    float
        _11, _12, _13, _14,
        _21, _22, _23, _24,
        _31, _32, _33, _34,
        _41, _42, _43, _44;
};

Matrix4 Matrix4_Identity = {._11=1, ._22=1, ._33=1, ._44=1};

Matrix4 transpose(Matrix4 m) {
    Matrix4 r;
    
    float *mf = (float*)&m;
    float *rf = (float*)&r;
    
    for (int i = 0; i < 3; i++) {
        for (int j = 0; j < 3; j++) {
            rf[i*4+j] = mf[j*4+i];
        }
    }
    
    return r;
}

Matrix4 orthographic_projection(
    float left, 
    float right, 
    float bottom, 
    float top, 
    float near, 
    float far, 
    bool  depth_range_01 = false
) {
    Matrix4 m;

    m._11 = 2.0 / (right - left);
    m._14 = - (right + left) / (right - left);

    m._22 = 2.0 / (top - bottom);
    m._24 = - (top + bottom) / (top - bottom);

    // if depth_range_01 {
    //     m._33 = -1 / (far - near);
    //     m._34 = near / (far - near);
    // }
    // else {
        m._33 = -2 / (far - near);
        m._34 = - (far + near) / (far - near);
    // }
    m._44 = 1.0;
    
    if (depth_range_01) {
        // To map -1,1 depth range to 0,1 we transform z as follows: z' = z * 0.5 + 0.5
        m._33 = m._33 * 0.5 + m._43 * 0.5;
        m._34 = m._34 * 0.5 + m._44 * 0.5;
    }

    return m;
}


// assumes value is from 0 to 1
float smooth_0_to_1(float value) {
	if (value <= 0.5) {
		// (2x)^2 / 2
		value *= 2.0;
		value *= value;
		value *= 0.5;
		return value;
	}
	else {
		// -((2(x-1))^2 / 2) + 1
		value = (value - 1.0) * 2.0;
		value *= -value;
		value = (value * 0.5) + 1.0;
		return value;
	}
}

// assumes value is from 0 to 1
float smooth_0_to_1_sine(float value) {
	return (cos(M_PI * (value + 1.0)) / 2.0) + 0.5;
}

float random_float(float min, float max) { return min + (max - min) * (float)rand()/(float)(RAND_MAX); };

int random_int(int min, int max) {  return min + rand() % (max - min);};
uint32_t random_uint(uint32_t min, uint32_t max) { return min + (uint32_t)rand() % (max - min); };


// MACROS

inline void swap_detail(void* p1, void* p2, void* tmp, size_t pSize)
{
   memcpy(tmp, p1, pSize);
   memcpy(p1, p2, pSize);
   memcpy(p2 , tmp, pSize);
}
#define SWAP(a, b) swap_detail(&(a), &(b), (char[(sizeof(a) == sizeof(b)) ? (ptrdiff_t)sizeof(a) : -1]){0}, sizeof(a))



// Functions for rotating a point about the origin or about another point.
// Prefer radians in general. If you need to use the same angle for multiple rotations but have degrees, 
//		definitely calculate radians in enclosing scope and call radians versions of the functions.
inline Vec2 rotate_radians(Vec2 subject, float radians) {
	float sin_t = sin(radians),
		   cos_t = cos(radians);
	return (Vec2) {
		.x = subject.x * cos_t - subject.y * sin_t,
		.y = subject.y * cos_t + subject.x * sin_t
	};
}

inline Vec2 rotate_degrees(Vec2 subject, float degrees) {
	float radians = degrees * M_PI / 180.0;
	return rotate_radians(subject, radians);
}

inline Vec2 rotate_around_point_radians(Vec2 subject, Vec2 point, float radians) {
	Vec2 result = (subject - point);
	result = rotate_radians(result, radians);
	result = (result + point);
	return result;
}

inline Vec2 rotate_around_point_degrees(Vec2 subject, Vec2 point, float degrees) {
	float radians = degrees * M_PI / 180.0;
	return rotate_around_point_radians(subject, point, radians);
}

Vec2 to_vec2(SDL_Point point) {
    return { (float)point.x, (float)point.y };
}

Vec2 to_vec2(Vec2i point) {
    return { (float)point.x, (float)point.y };
}

Vec2i to_vec2i(Vec2 point) {
    return { (int)point.x, (int)point.y };
}

Vec2i get_rect_center(const Rect *rect) {
    return Vec2i { rect->w / 2, rect->h / 2 };
}

Rect clip_within_rect(Rect* rect, FRect* clip) {
    return Rect {
        (int32_t)(rect->x + (float)rect->w * clip->x),
        (int32_t)(rect->y + (float)rect->h * clip->y),
        (int32_t)((float)rect->w * clip->w),
        (int32_t)((float)rect->w * clip->h),
    };
}

FRect clip_within_frect(FRect* rect, FRect* clip) {
    return FRect {
        rect->x + rect->w * clip->x,
        rect->y + rect->h * clip->y,
        rect->w * clip->w,
        rect->w * clip->h,
    };
}

void center_rect_on_point(Rect *rect, Vec2i point) {
    Vec2i rect_center = get_rect_center(rect);
    rect->x = point.x - rect_center.x;
    rect->y = point.y - rect_center.y;
}

void center_rect_within_rect(Rect *rect, const Rect *within) {
    Vec2i within_center = get_rect_center(within);
    Vec2i rect_center   = get_rect_center(rect);
    rect->x = within->x + within_center.x - rect_center.x;
    rect->y = within->y + within_center.y - rect_center.y;
}


enum class Axis { NONE, X, Y, MINOR, MAJOR };

void center_and_scale_rect_within_rect(
    Rect* rect, const Rect* within, 
    Axis scale_axis = Axis::NONE
) {
    float rect_aspect   = (float)rect->w   / (float)rect->h;
    float within_aspect = (float)within->w / (float)within->h;
    
    float scale = 1.0;
    
    switch (scale_axis) {
      case Axis::X:
        scale = (float)within->w / (float)rect->w;
        break;
        
      case Axis::Y:
        scale = (float)within->h / (float)rect->h;
        break;
        
      case Axis::MINOR:
        if (rect_aspect > within_aspect) {
            scale = (float)within->h / (float)rect->h;
        } else {
            scale = (float)within->w / (float)rect->w;
        }
        break;
        
      case Axis::MAJOR:
        if (rect_aspect < within_aspect) {
            scale = (float)within->h / (float)rect->h;
        } else {
            scale = (float)within->w / (float)rect->w;
        }
        break;
    
      case Axis::NONE: break;
    }
    
    rect->w *= scale;
    rect->h *= scale;
    
    center_rect_within_rect(rect, within);
}

// void center_and_scale_rect_within_rect_by_major_dimension(Rect *rect, const Rect *within) {
//     float rect_aspect   = (float)rect->w   / (float)rect->h;
//     float within_aspect = (float)within->w / (float)within->h;
    
//     float scale = 1.0;
//     if (rect_aspect > within_aspect) {
//         scale = (float)within->w / (float)rect->w;
//     } else {
//         scale = (float)within->h / (float)rect->h;
//     }
//     rect->w *= scale;
//     rect->h *= scale;
    
//     center_rect_within_rect(rect, within);
// }

int clampi(int x, int min, int max) {
    if      (x < min) x = min;
    else if (x > max) x = max;
    return x;
}

// TODO: rename clampf
float clamp(float x, float min, float max) {
    if      (x < min) x = min;
    else if (x > max) x = max;
    return x;
}

float lerp(float min, float max, float t) {
    return min + (max - min) * t;
}

Vec2 lerp(Vec2 start, Vec2 end, float t) {
    Vec2 ret;
    ret.x = lerp(start.x, end.x, t);
    ret.y = lerp(start.y, end.y, t);
    return ret;
}


Color4 lerp(Color4 start, Color4 end, float t) {
    Color4 ret;
    ret.r = lerp(start.r, end.r, t);
    ret.g = lerp(start.g, end.g, t);
    ret.b = lerp(start.b, end.b, t);
    ret.a = lerp(start.a, end.a, t);
    return ret;
}

FRect lerp(FRect start, FRect end, float t) {
    FRect ret;
    ret.x = lerp(start.x, end.x, t);
    ret.y = lerp(start.y, end.y, t);
    ret.w = lerp(start.w, end.w, t);
    ret.h = lerp(start.h, end.h, t);
    return ret;
}


float delerp(float low, float high, float t) {
    return (t - low) / (high - low);
}

float delerp_clamped(float low, float high, float t) {  
    return clamp(delerp(low, high, t), 0, 1);
}


// TODO: maybe later we want to do collision for icons based on some polygon instead of keeping raw image in memory?
// bool is_point_in_polygon(Point p, SDL_Point* vertices, int vertices_count) {
//     if (vertices_count <= 0) return false; 

//     float min_x = vertices[0].x;
//     float max_x = vertices[0].x;
//     float min_y = vertices[0].y;
//     float max_y = vertices[0].y;
    
//     for (int i = 1; i < vertices_count; i++) {
//         Point v = vertices[i];
//         min_x = Math.Min( v.x, min_x );
//         max_x = Math.Max( v.x, max_x );
//         min_y = Math.Min( v.y, min_y );
//         max_y = Math.Max( v.y, max_y );
//     }

//     if (p.x < min_x || p.x > max_x || p.y < min_y || p.y > max_y) {
//         return false;
//     }

//     // https://wrf.ecse.rpi.edu/Research/Short_Notes/pnpoly.html
//     bool inside = false;
//     for (int i = 0, j = vertices_count - 1; i < vertices_count; j = i, i += 1) {
//         if ( ( vertices[i].y > p.y ) != ( vertices[j].y > p.y ) &&
//              p.x < ( vertices[j].x - vertices[i].x ) * ( p.y - vertices[i].y ) / ( vertices[j].y - vertices[i].y ) + polygon[i].x )
//         {
//             inside = !inside;
//         }
//     }

//     return inside;
// }

inline float angle_difference_degrees(float a1, float a2) {
	float result = a1 - a2;
	if (result >= 180.0) result -= 360.0;
	if (result < -180.0) result += 360.0;
	return result;
}

inline Vec2 normal_vector_from_angle_radians(float radians) {
	Vec2 normal;
	normal.x = cos(radians);
	normal.y = sin(radians);
	return normal;
}

inline Vec2 normal_vector_from_angle_degrees(float degrees) {
	float radians = degrees * M_PI / 180.0 ;
	Vec2 normal;
	normal.x = cos(radians);
	normal.y = sin(radians);
	return normal;
}


// struct Pointer_And_Index {
//     void   *pointer;
//     size_t  index;
// }

// bool get_sorted_ordering(
//     void   *base, 
//     size_t  nitems, 
//     size_t  size,
//     void   *compare,
    
//     size_t *indices // array count assumed to match nitems!
// ) {
    
//     qsort();
// }


#define MIN(a,b) (((a)<(b))?(a):(b))
#define MAX(a,b) (((a)>(b))?(a):(b))


#define seconds_to_ticks(time) ((uint32_t)((time) * 1000.0))
// #define ticks_to_seconds(time) ((uint32_t)((time) * 1000.0))





// Lerping actions for basic types

// template<typename T>
// struct Timed_Lerp {
//     T        from, to;
//     uint32_t start_time, end_time;
//     bool     smooth;
// };

// template<typename T>
// float get_timed_lerp_value(Timed_Lerp<T> *tl) {
//     float t = delerp_clamped(tl->start_time, tl->end_time, SDL_GetTicks());
//     if (tl->smooth) t = smooth_0_to_1_sine(t);
//     return lerp(tl->from, tl->to, t);
// }

// template<typename T>
// void begin_timed_lerp(Timed_Lerp<T> *tl, float from, float to, uint32_t ticks, bool smooth = false) {
//     tl->from       = from;
//     tl->to         = to;
//     tl->start_time = SDL_GetTicks();
//     tl->end_time   = tl->start_time + ticks;
// }

// template<typename T>
// void reverse_timed_lerp(Timed_Lerp<T> *tl) {
//     uint32_t ticks_now = SDL_GetTicks();
//     float time_since_start = MIN(ticks_now, tl->end_time) - tl->start_time;
//     float time_until_end   = MAX(tl->end_time - ticks_now, 0);
    
//     tl->start_time = ticks_now - time_until_end;
//     tl->end_time   = ticks_now + time_since_start;
    
//     SWAP(tl->from, tl->to);
// }


struct Timed_Lerp_Float {
    float    from, to;
    uint32_t start_time, end_time;
    bool     smooth;
};

float get_timed_lerp_value(Timed_Lerp_Float *tl) {
    float t = delerp_clamped(tl->start_time, tl->end_time, SDL_GetTicks());
    if (tl->smooth) t = smooth_0_to_1_sine(t);
    return lerp(tl->from, tl->to, t);
}

void begin_timed_lerp(Timed_Lerp_Float *tl, float from, float to, uint32_t ticks, bool smooth = false) {
    tl->from       = from;
    tl->to         = to;
    tl->start_time = SDL_GetTicks();
    tl->end_time   = tl->start_time + ticks;
}

void begin_timed_lerp_from_current(Timed_Lerp_Float *tl, float from, float to, uint32_t ticks, bool smooth = false) {
    float current_value = get_timed_lerp_value(tl); 
    float start_lerp = delerp_clamped(from, to, current_value);
    begin_timed_lerp(tl, current_value, to, (uint32_t)((float)ticks * (1.0 - (float)start_lerp)), smooth);
}

void reverse_timed_lerp(Timed_Lerp_Float *tl) {
    uint32_t ticks_now = SDL_GetTicks();
    float time_since_start = MIN(ticks_now, tl->end_time) - tl->start_time;
    float time_until_end   = MAX(tl->end_time - ticks_now, 0);
    
    tl->start_time = ticks_now - time_until_end;
    tl->end_time   = ticks_now + time_since_start;
    
    SWAP(tl->from, tl->to);
}

struct Timed_Lerp_Vec2 {
    Vec2     from, to;
    uint32_t start_time, end_time;
    bool     smooth;
};

Vec2 get_timed_lerp_value(Timed_Lerp_Vec2 *tl) {
    float t = delerp_clamped(tl->start_time, tl->end_time, SDL_GetTicks());
    if (tl->smooth) t = smooth_0_to_1_sine(t);
    return lerp(tl->from, tl->to, t);
}

void begin_timed_lerp(Timed_Lerp_Vec2 *tl, Vec2 from, Vec2 to, uint32_t ticks, bool smooth = false) {
    tl->from       = from;
    tl->to         = to;
    tl->start_time = SDL_GetTicks();
    tl->end_time   = tl->start_time + ticks;
}

void reverse_timed_lerp(Timed_Lerp_Vec2 *tl) {
    uint32_t ticks_now = SDL_GetTicks();
    float time_since_start = MIN(ticks_now, tl->end_time) - tl->start_time;
    float time_until_end   = MAX(tl->end_time - ticks_now, 0);
    
    tl->start_time = ticks_now - time_until_end;
    tl->end_time   = ticks_now + time_since_start;
    
    SWAP(tl->from, tl->to);
}

struct Timed_Lerp_Color4 {
    Color4   from, to;
    uint32_t start_time, end_time;
    bool     smooth;
};

Color4 get_timed_lerp_value(Timed_Lerp_Color4 *tl) {
    float t = delerp_clamped(tl->start_time, tl->end_time, SDL_GetTicks());
    if (tl->smooth) t = smooth_0_to_1_sine(t);
    return lerp(tl->from, tl->to, t);
}

void begin_timed_lerp(Timed_Lerp_Color4 *tl, Color4 from, Color4 to, uint32_t ticks, bool smooth = false) {
    tl->from       = from;
    tl->to         = to;
    tl->start_time = SDL_GetTicks();
    tl->end_time   = tl->start_time + ticks;
}

void reverse_timed_lerp(Timed_Lerp_Color4 *tl) {
    uint32_t ticks_now = SDL_GetTicks();
    float time_since_start = MIN(ticks_now, tl->end_time) - tl->start_time;
    float time_until_end   = MAX(tl->end_time - ticks_now, 0);
    
    tl->start_time = ticks_now - time_until_end;
    tl->end_time   = ticks_now + time_since_start;
    
    SWAP(tl->from, tl->to);
}







// very little reason for this to go here, but this is basically a utils file atm
void to_upper(char* text) {
    while (*text) {
        if (*text >= 'a' && *text <= 'z') {
            *text -= 32;
        }
        text += 1;
    }
}
