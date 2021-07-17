function layout() {
    return {
        name: "Uniform Columns",
        getFrameAssignments: (windows, screenFrame) => {
            const columnWidth = screenFrame.width / windows.length;
            const frames = windows.map((window, index) => {
                const frame = {
                    x: screenFrame.x + (columnWidth * index),
                    y: screenFrame.y,
                    width: columnWidth,
                    height: screenFrame.height
                };
                return { [window.id]: frame };
            });
            return frames.reduce((frames, frame) => ({ ...frames, ...frame }), {});
        }
    };
}
