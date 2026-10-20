function layout() {
    return {
        name: "Scale Factor",
        getFrameAssignments: (windows, screenFrame) => {
            // Two side-by-side panes; the second frame declares that the ratio governs a pane four times narrower than the screen.
            const halfWidth = screenFrame.width / 2;
            return windows.reduce((frames, window, index) => {
                const frame = {
                    x: screenFrame.x + halfWidth * Math.min(index, 1),
                    y: screenFrame.y,
                    width: halfWidth,
                    height: screenFrame.height,
                    isMain: index === 0
                };
                if (index === 1) {
                    frame.scaleFactor = 4;
                }
                return { ...frames, [window.id]: frame };
            }, {});
        }
    };
}
