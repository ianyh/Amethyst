function layout() {
    return {
        name: "Extended Tall",
        extends: "tall",
        getFrameAssignments: (windows, screenFrame, state, extendedFrames) => {
            const maxX = Math.max(...extendedFrames.map(f => f.frame.x));
            const minX = Math.min(...extendedFrames.map(f => f.frame.x));
            return extendedFrames.reduce((frames, extendedFrame) => {
                const frame = {
                    x: extendedFrame.frame.x === minX ? maxX : minX,
                    y: extendedFrame.frame.y,
                    width: extendedFrame.frame.width,
                    height: extendedFrame.frame.height
                };
                return { ...frames, [extendedFrame.id]: frame };
            }, {});
        }
    };
}
