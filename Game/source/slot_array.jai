
// This is like a crappy low tech version of the bucket array that I had been using in Odin mario, should probably just use bucket array instead
// TODO: we can improve at least somewhat by using a bitfield for the occupied flags.
//       this will make it faster to find the first unoccupied slot, and will make the actual array elements packed properly
//       easier to compact down elements, track the count of currently occupied slots

Slot_Array :: struct(T: Type, capacity: int) {
    slots:    [capacity] Slot(T);
    current:  int;
}

Slot :: struct(T: Type) {
    using #as data: T;
    occupied: bool;
}

get_next_empty_slot :: (using arr: *Slot_Array($T, $N)) -> *Slot(T) {
    for *slots  if !it.occupied  return it;
    return null;
}

get_next_slot :: (arr: *Slot_Array($T, $N)) -> *Slot(T) {
    arr.current = (arr.current + 1) % arr.slots.count;
    return *arr.slots[arr.current];
}

is_valid_index :: (array: Slot_Array, index: int) -> bool {
    return index >= 0 && index < array.capacity;
}

index_is_occupied :: (array: Slot_Array, index: int) -> bool {
    return array.slots[index].occupied;
}


for_expansion :: (slot_array: *Slot_Array, body: Code, flags: For_Flags) #expand {
    REVERSE    :: cast(bool) flags & .REVERSE;
    // DO_POINTER :: cast(bool) flags & .POINTER;
    DO_POINTER :: true;
    for <=REVERSE *=DO_POINTER  `it, `it_index: slot_array.slots {
        if !it.occupied continue;
        #insert (remove={it.* = .{};}) body;
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


operator[] :: (slot_array: *Slot_Array, index: int) -> slot_array.T {
    return slot_array.slots[index].data;
}

operator*[] :: (slot_array: *Slot_Array, index: int) -> *slot_array.T {
    return *slot_array.slots[index].data;
}

clone_to_view :: (slot_array: Slot_Array) -> [] slot_array.T {
    occupied_count := 0;
    for slot_array  occupied_count += 1; // iteration skips unoccipied slots automatically
    view  := NewArray(occupied_count, slot_array.T, initialized = false); 
    index := 0;
    for slot_array {
        view[index] = it;
        index += 1;
    }
    return view;
}

clone_from_view :: (slot_array: *Slot_Array, view: [] slot_array.T, assert_size := false) {
    if assert_size  assert(slot_array.capacity >= view.count);
    for view {
        slot := get_next_slot(slot_array);
        slot.occupied = true;
        slot.data = it;
    }
}