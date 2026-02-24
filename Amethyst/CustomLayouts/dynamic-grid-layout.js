// Dynamic Grid Layout for Amethyst
// Places windows in a grid that adapts rows and columns to the number of windows.
function layout() {
    return {
        name: 'Dynamic Grid',
        // Persisted layout state. `order` stores an array of window ids (strings)
        // in the preferred display order. Commands below mutate this state.
        initialState: { order: [] },

        // Commands exposed to Amethyst. Each command exposes an `updateState`
        // function that receives the current `state` and optionally the id of
        // the currently focused window. These functions must return the new
        // state. Note: the JavaScript layout context cannot directly change
        // system focus — it can only reorder windows. Swapping/reordering
        // will change window frames and therefore effectively move windows.
        commands: {
            // Helper command creators are defined in the file body below.
            focusLeft: { updateState: function (state, focusedId) { return _focusInDirection(state, focusedId, 'left'); } },
            focusRight: { updateState: function (state, focusedId) { return _focusInDirection(state, focusedId, 'right'); } },
            focusUp: { updateState: function (state, focusedId) { return _focusInDirection(state, focusedId, 'up'); } },
            focusDown: { updateState: function (state, focusedId) { return _focusInDirection(state, focusedId, 'down'); } },

            swapLeft: { updateState: function (state, focusedId) { return _swapInDirection(state, focusedId, 'left'); } },
            swapRight: { updateState: function (state, focusedId) { return _swapInDirection(state, focusedId, 'right'); } },
            swapUp: { updateState: function (state, focusedId) { return _swapInDirection(state, focusedId, 'up'); } },
            swapDown: { updateState: function (state, focusedId) { return _swapInDirection(state, focusedId, 'down'); } },

            swap: { updateState: function (state, sourceId, targetId) { return _swapWindows(state, sourceId, targetId); } }
        },
        extends: null,

        // windows: array of window objects
        // screenFrame: { x, y, width, height }
        getFrameAssignments: function (windows, screenFrame, state, extendedFrames) {
            const assignments = {};
            // Ensure we operate on a stable ordering stored in `state.order`.
            // If the state doesn't contain the current windows, initialize it
            // to the incoming order and keep it in sync by removing missing
            // entries and appending new ones.
            state = state || { order: [] };

            const windowMap = {};
            windows.forEach(w => { windowMap[w.id] = w; });

            // Rebuild ordered windows array from state.order, preserving any
            // new windows that aren't yet present in the saved order.
            const ordered = [];
            (state.order || []).forEach(id => { if (windowMap[id]) { ordered.push(windowMap[id]); delete windowMap[id]; } });
            windows.forEach(w => { if (windowMap[w.id]) { ordered.push(w); } });

            // Persist the canonical order back into state
            state.order = ordered.map(w => w.id);

            // Attach state to assignments so Swift can pick it up if needed
            assignments.state = state;

            const n = ordered.length;

            if (n === 0) return assignments;

            // Determine Grid Dimensions: bias towards columns because screens are usually
            // wider than they are tall.
            const cols = Math.ceil(Math.sqrt(n));
            const rows = Math.ceil(n / cols);

            const cellHeight = Math.floor(screenFrame.height / rows);

            for (let i = 0; i < n; i++) {
                const win = ordered[i];

                // Calculate which row and column this window belongs to
                const currentRow = Math.floor(i / cols);
                const colIndex = i % cols;

                // Check if we are on the final row
                const isLastRow = currentRow === rows - 1;

                // Calculate how many items are actually in this specific row
                // Usually it's 'cols', but the last row might have fewer (the remainder)
                const itemsInThisRow = isLastRow ? (n - (currentRow * cols)) : cols;

                // Calculate width for THIS specific row
                // If it's the last row with fewer items, they get wider.
                const cellWidth = Math.floor(screenFrame.width / itemsInThisRow);

                const frame = {
                    x: screenFrame.x + (colIndex * cellWidth),
                    y: screenFrame.y + (currentRow * cellHeight),
                    width: cellWidth,
                    height: cellHeight
                };

                // Rounding adjustments (Pixel Perfection)
                // Ensure the last item in a row hits the right edge
                if (colIndex === itemsInThisRow - 1) {
                    frame.width = screenFrame.x + screenFrame.width - frame.x;
                }
                // Ensure the items in the last row hit the bottom edge
                if (isLastRow) {
                    frame.height = screenFrame.y + screenFrame.height - frame.y;
                }

                assignments[win.id] = frame;
            }

            return assignments;
        },

        updateWithChange: function (change, state) {
            state = state || { order: [] };

            if (!change) return state;

            if (change.change === 'window_swap' && change.windowID && change.otherWindowID) {
                return _swapWindows(state, change.windowID, change.otherWindowID);
            }

            if (change.change === 'add' && change.windowID) {
                // Add new window to the end of the order if not already present
                if (_indexOfId(state.order, change.windowID) === -1) {
                    state.order.push(change.windowID);
                }
                return state;
            }

            if (change.change === 'remove' && change.windowID) {
                // Remove the window from the order
                const idx = _indexOfId(state.order, change.windowID);
                if (idx !== -1) {
                    state.order.splice(idx, 1);
                }
                return state;
            }

            return state;
        },

        recommendMainPaneRatio: function (ratio, state) {
            return state;
        }
    };
}

layout();

// Helper functions used by `commands` above. These live outside the exported
// layout object so they can operate on plain JS state objects provided by
// Amethyst.

function _indexOfId(order, id) {
    if (!order) return -1;
    return order.indexOf(id);
}

function _focusInDirection(state, focusedId, dir) {
    // This function won't change system focus directly; it reorders the
    // state.order so that the next reflow will place the desired window
    // in a position that will receive focus if the user navigates.
    state = state || { order: [] };
    if (!focusedId) return state;

    const idx = _indexOfId(state.order, focusedId);
    if (idx === -1) return state;

    // For grid layout, approximate left/right/up/down by neighbor indices.
    // Compute cols like in main layout function.
    const n = state.order.length;
    const cols = Math.ceil(Math.sqrt(n));
    let targetIdx = idx;

    switch (dir) {
        case 'left':
            targetIdx = (idx % cols === 0) ? idx : idx - 1; break;
        case 'right':
            targetIdx = (idx % cols === cols - 1 || idx === n - 1) ? idx : idx + 1; break;
        case 'up':
            targetIdx = (idx - cols >= 0) ? idx - cols : idx; break;
        case 'down':
            targetIdx = (idx + cols < n) ? idx + cols : idx; break;
        default:
            return state;
    }

    // Move the target index to be just after the focused index so it will be
    // one of the next candidates; this is a heuristic to influence focus.
    if (targetIdx !== idx) {
        const id = state.order.splice(targetIdx, 1)[0];
        state.order.splice(idx + (targetIdx > idx ? 0 : 1), 0, id);
    }

    return state;
}

function _swapInDirection(state, focusedId, dir) {
    state = state || { order: [] };
    if (!focusedId) return state;

    const idx = _indexOfId(state.order, focusedId);
    if (idx === -1) return state;

    const n = state.order.length;
    const cols = Math.ceil(Math.sqrt(n));
    let otherIdx = idx;

    switch (dir) {
        case 'left':
            otherIdx = (idx % cols === 0) ? idx : idx - 1; break;
        case 'right':
            otherIdx = (idx % cols === cols - 1 || idx === n - 1) ? idx : idx + 1; break;
        case 'up':
            otherIdx = (idx - cols >= 0) ? idx - cols : idx; break;
        case 'down':
            otherIdx = (idx + cols < n) ? idx + cols : idx; break;
        default:
            return state;
    }

    if (otherIdx !== idx) {
        const tmp = state.order[otherIdx];
        state.order[otherIdx] = state.order[idx];
        state.order[idx] = tmp;
    }

    return state;
}

function _swapWindows(state, sourceId, targetId) {
    state = state || { order: [] };
    if (!sourceId || !targetId) return state;

    const idx1 = _indexOfId(state.order, sourceId);
    const idx2 = _indexOfId(state.order, targetId);

    if (idx1 === -1 || idx2 === -1) return state;

    const tmp = state.order[idx1];
    state.order[idx1] = state.order[idx2];
    state.order[idx2] = tmp;

    return state;
}
