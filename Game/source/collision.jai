
aabb_frect :: (r1: Rectf, r2: Rectf) -> bool {
  return !(r1.x        > r2.x + r2.w ||
           r1.x + r1.w < r2.x        ||
           r1.y        > r2.y + r2.h ||
           r1.y + r1.h < r2.y        );
}

aabb_rect :: (r1: Rect, r2: Rect) -> bool {
  return !(r1.x        > r2.x + r2.w ||
           r1.x + r1.w < r2.x        ||
           r1.y        > r2.y + r2.h ||
           r1.y + r1.h < r2.y        );
}

swept_aabb_frect :: (r1: Rectf, v1: Vector2, r2: Rectf, v2: Vector2) -> (int, float, Direction) {
    // check if rectangles are in collision at time == 0
    if (aabb_frect(r1, r2)) {
        return 0, 0, .U;
    }

    // do broad phase collision check
    r1_broad: Rectf = .{
        x = ifx v1.x > 0 then r1.x        else r1.x + v1.x,
        y = ifx v1.y > 0 then r1.y        else r1.y + v1.y,
        w = ifx v1.x > 0 then v1.x + r1.w else r1.w - v1.x,
        h = ifx v1.y > 0 then v1.y + r1.h else r1.h - v1.y,
    };
    r2_broad: Rectf = .{
        x = ifx v2.x > 0 then r2.x        else r2.x + v2.x,
        y = ifx v2.y > 0 then r2.y        else r2.y + v2.y,
        w = ifx v2.x > 0 then v2.x + r2.w else r2.w - v2.x,
        h = ifx v2.y > 0 then v2.y + r2.h else r2.h - v2.y,
    };
    if (!aabb_frect(r1_broad, r2_broad)) {
        return -1, 0, .U;
    }

    // get relative velocity
    v := v1 - v2;

    // determine distance to collision entry and exit
    dEntry, dExit: Vector2;
    if (v.x >= 0.0) {
        dEntry.x = r2.x - (r1.x + r1.w);
        dExit.x  = (r2.x + r2.w) - r1.x;
    }
    else {
        dEntry.x = (r2.x + r2.w) - r1.x;
        dExit.x  = r2.x - (r1.x + r1.w);
    }

    if (v.y >= 0.0) {
        dEntry.y = r2.y - (r1.y + r1.h);
        dExit.y  = (r2.y + r2.h) - r1.y;
    }
    else {
        dEntry.y = (r2.y + r2.h) - r1.y;
        dExit.y  = r2.y - (r1.y + r1.h);
    }

    // determine time of entry and exit in each axis
    tEntry, tExit: Vector2;

    tEntry.x = dEntry.x / v.x;
    tExit.x  = dExit.x  / v.x;

    tEntry.y = dEntry.y / v.y;
    tExit.y  = dExit.y  / v.y;

    // determine actual time of entry and exit
    entryTime, exitTime: float;
    entryTime = max(tEntry.x, tEntry.y);
    exitTime  = min(tExit.x,  tExit.y );

    // return false if no collision occurred
    if (entryTime > exitTime || (tEntry.x < 0.0 && tEntry.y < 0.0) || tEntry.x > 1.0 || tEntry.y > 1.0) {
        return -1, 0, .U;
    }

    direction: Direction =
        ifx tEntry.x > tEntry.y then
             (ifx dEntry.x > 0.0 then .R else .L)
        else (ifx dEntry.y > 0.0 then .D else .U);
    
    return 1, entryTime, direction;
}

is_point_within_frect :: (point: Vector2, rect: Rectf) -> bool {
    return point.x >= rect.x && point.x < rect.x + rect.w &&
           point.y >= rect.y && point.y < rect.y + rect.h;
}

is_point_within_rect :: (point: Vec2i, rect: Rect) -> bool {
    return point.x >= rect.x && point.x < rect.x + rect.w &&
           point.y >= rect.y && point.y < rect.y + rect.h;
}