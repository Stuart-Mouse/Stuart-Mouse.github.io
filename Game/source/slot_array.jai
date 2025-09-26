
// This is like a crappy low tech version of the bucket array that I had been using in Odin mario, should probably just use bucket array instead
// TODO: we can improve at least somewhat by using a bitfield for the occupied flags.
//       this will make it faster to find the first unoccupied slot, and will make the actual array elements packed properly
//       easier to compact down elements, track the count of currently occupied slots

Slot_Array :: struct(T: Type, capacity: int) {
    slots:          [capacity] T;
    next:           int;
    occupancy_mask: [capacity/8] u8;
}

// TODO: decide if we want the slot getter procs to automatically set the returned slot as occupied

get_first_empty_slot :: (using array: *Slot_Array) -> *array.T {
    for 0..capacity-1  if !index_is_occupied(array, it)  { return *slots[it]; }
    return null;
}

get_next_empty_slot :: (using array: *Slot_Array) -> *array.T {
    for next..capacity-1  if !index_is_occupied(array, it)  { return *slots[it]; }
    for    0..next-1      if !index_is_occupied(array, it)  { return *slots[it]; }
    return null;
}

get_next_slot :: (arr: *Slot_Array($T, $N)) -> *T {
    ret := *arr.slots[arr.next];
    arr.next = (arr.next + 1) % arr.capacity;
    return ret;
}

is_valid_index :: (array: Slot_Array, index: int) -> bool {
    return index >= 0 && index < array.capacity;
}

index_is_occupied :: (array: Slot_Array, index: int) -> bool {
    if !is_valid_index(array, index)  return false;
    return array.occupancy_mask[index/8] & (1 << (index % 8)) != 0;
}

// TODO: maybe not always by pointer anymore...
// TODO: optimize so that we do the occupancy checking manually
for_expansion :: (array: *Slot_Array, body: Code, flags: For_Flags) #expand {
    REVERSE    :: cast(bool) flags & .REVERSE;
    // DO_POINTER :: cast(bool) flags & .POINTER;
    DO_POINTER :: true;
    for <=REVERSE *=DO_POINTER  `it, `it_index: array.slots {
        if !index_is_occupied(array, it_index) continue;
        #insert (remove={set_index_occupied(array, it_index, false);}) body;
    }
}

set_index_occupied :: (array: *Slot_Array, index: int, $$occupied: bool) {
    assert(is_valid_index(array, index));
    if occupied {
        array.occupancy_mask[index/8] |= (1 << (index % 8)).(u8);
    } else {
        array.occupancy_mask[index/8] &= ~(1 << (index % 8)).(u8);
    }
}

set_index_occupied :: (array: *Slot_Array, element: *array.T, $$occupied: bool) {
    assert(element >= array.slots.data && element < array.slots.data + array.capacity);
    index := (element.(u64) - array.slots.data.(u64)) / size_of(array.T);
    if occupied {
        array.occupancy_mask[index/8] |= (1 << (index % 8)).(u8);
    } else {
        array.occupancy_mask[index/8] &= ~(1 << (index % 8)).(u8);
    }
}

// pairs :: (slot_array: *Slot_Array, body: Code, flags: For_Flags) #expand {
//     assert(flags & .REVERSE == 0, "cannot iterate slot array pairs in reverse");
//     DO_POINTER :: true;
//     for *=DO_POINTER  `it_a, `it_a_index: slot_array.slots {
//         if !it_a.occupied continue;
//         for *=DO_POINTER  `it_b, `it_b_index: slot_array.slots {
//             if !it_b.occupied || it_a == it_b continue;
//             #insert (remove={assert(false, "cannot remove when iterating pairs in slot array");}) body;
//         }
//     }
// }


operator[] :: (array: *Slot_Array, index: int) -> array.T {
    return array.slots[index];
}

operator*[] :: (array: *Slot_Array, index: int) -> *array.T {
    return *array.slots[index];
}

clone_to_view :: (array: Slot_Array) -> [] array.T {
    // TODO: make this more efficient
    occupied_count := 0;
    for array  occupied_count += 1; // iteration skips unoccipied slots automatically
    
    view  := NewArray(occupied_count, array.T, initialized = false); 
    index := 0;
    for array {
        view[index] = it;
        index += 1;
    }
    return view;
}

clone_from_view :: (array: *Slot_Array, view: [] array.T, assert_size := false) {
    if assert_size  assert(array.capacity >= view.count);
    for view {
        slot := get_next_slot(array);
        set_index_occupied(array, it_index, true);
        slot.* = it;
    }
}