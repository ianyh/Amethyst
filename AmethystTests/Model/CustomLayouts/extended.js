function layout() {
    return {
        name: "Extended Tall",
        extends: "tall",
        getFrameAssignments: (windows, screenFrame, state, extendedFrames) => {
            const frames = {};
            const maxX = Math.max(Object.values(extendedFrames).map(f => f.frame.x));
            const minX = Math.min(Object.values(extendedFrames).map(f => f.frame.x));
            for (const id in Object.values(extendedFrames)) {
                const frame = extendedFrames[id];
                if (frame.x === minX) {
                    frame.x = maxX;
                } else {
                    frame.x = minX;
                }
                frames[id] = frame;
            }
            return frames;
        }
    };
}
