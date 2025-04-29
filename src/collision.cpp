
typedef enum Directions {
	DIR_NONE	= 0,
	DIR_U_I		= 0,
	DIR_R_I		= 1,
	DIR_D_I		= 2,
	DIR_L_I		= 3,
	DIR_UR_I	= 4,
	DIR_DR_I	= 5,
	DIR_DL_I	= 6,
	DIR_UL_I	= 7,
	DIR_U		= 1 << DIR_U_I,
	DIR_D		= 1 << DIR_D_I,
	DIR_L		= 1 << DIR_L_I,
	DIR_R		= 1 << DIR_R_I,
	DIR_UR		= 1 << DIR_UR_I,
	DIR_DR		= 1 << DIR_DR_I,
	DIR_UL		= 1 << DIR_UL_I,
	DIR_DL		= 1 << DIR_DL_I,
	DIR_USIDE	= DIR_U | DIR_UR | DIR_UL,
	DIR_DSIDE	= DIR_D | DIR_DR | DIR_DL,
	DIR_LSIDE	= DIR_L | DIR_UL | DIR_DL,
	DIR_RSIDE	= DIR_R | DIR_UR | DIR_DR,
	DIR_PRIMARY = DIR_U | DIR_D | DIR_L | DIR_R,
	DIR_ALL		= 255,
} Directions;


bool is_point_within_rect(Vec2i point, const Rect* rect) {
	if (point.x <  rect->x
	 || point.y <  rect->y
	 || point.x >= rect->x + rect->w
	 || point.y >= rect->y + rect->h)
		return false;
	return true;
}

bool is_point_within_rectf(Vec2 point, const FRect* rect) {
	if (point.x <  rect->x
	 || point.y <  rect->y
	 || point.x >= rect->x + rect->w
	 || point.y >= rect->y + rect->h)
		return false;
	return true;
}

bool aabb_frect(const FRect* r1, const FRect* r2) {
	return r1->x <= r2->x + r2->w
	    && r2->x <= r1->x + r1->w
	    && r1->y <= r2->y + r2->h
	    && r2->y <= r1->y + r1->h;
}


// performs a sweeped collision test between two axis-aligned rectangles 
bool swept_aabb_frect(const FRect* r1, Vec2 v1, const FRect* r2, Vec2 v2, float* time, Directions* direction) {
	Vec2 dEntry, dExit;
	Vec2 v = v1 - v2;
	
	if (v.x >= 0.0) {
		dEntry.x = r2->x - (r1->x + r1->w);
		dExit.x  = (r2->x + r2->w) - r1->x;
	}
	else {
		dEntry.x = (r2->x + r2->w) - r1->x; 
		dExit.x  = r2->x - (r1->x + r1->w);
	}

	if (v.y >= 0.0) {
		dEntry.y = r2->y - (r1->y + r1->h);
		dExit.y  = (r2->y + r2->h) - r1->y;
	}
	else {
		dEntry.y = (r2->y + r2->h) - r1->y;
		dExit.y  = r2->y - (r1->y + r1->h);
	}


	// determine time of entry and exit in each axis
	Vec2 tEntry, tExit;

	tEntry.x = dEntry.x / v.x;
	tExit.x  = dExit.x  / v.x;

	tEntry.y = dEntry.y / v.y;
	tExit.y  = dExit.y  / v.y;
	
	// printf("tEntry: %f, %f\n", tEntry.x, tEntry.y);

	// determine actual time of entry and exit
	float entryTime, exitTime;
	entryTime = fmaxf(tEntry.x, tEntry.y);
	exitTime  = fminf(tExit.x,  tExit.y );

	// return false if no collision occurred
	if (entryTime > exitTime || (tEntry.x < 0.0 && tEntry.y < 0.0) || tEntry.x > 1.0 || tEntry.y > 1.0) {
		return false;
	}

	if (time != NULL) {
		*time = entryTime;
	}

	if (direction != NULL) {
		if (tEntry.x > tEntry.y) {
			if (dEntry.x > 0.0) *direction = DIR_R;
			else				*direction = DIR_L;
		}
		else {
			if (dEntry.y > 0.0) *direction = DIR_D;
			else				*direction = DIR_U;
		}
	}

	return true;
};



Vec2 get_position_in_tilemap(Vec2 position_global, FRect* tilemap_rect, Vec2 tilemap_size) {
	return (position_global - tilemap_rect->position) / tilemap_rect->size * tilemap_size;
}

