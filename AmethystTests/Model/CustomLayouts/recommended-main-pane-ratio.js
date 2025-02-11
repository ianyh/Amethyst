function layout() {
    return {
        name: "Ratio",
        initialState: {
            mainPaneRatio: 0.5
        },
        recommendMainPaneRatio: (ratio, state) => {
            return { ...state, mainPaneRatio: ratio };
        },
        getFrameAssignments: (windows, screenFrame, state) => {
            return windows.reduce((frames, window, index) => {
                if (index === 0) {
                    const frame = {
                        x: screenFrame.x,
                        y: screenFrame.y,
                        width: screenFrame.width * state.mainPaneRatio,
                        height: screenFrame.height,
                        isMain: true,
                        unconstrainedDimension: "horizontal"
                    };
                    return { ...frames, [window.id]: frame };
                } else {
                    const frame = {
                        x: screenFrame.x + screenFrame.width * state.mainPaneRatio,
                        y: screenFrame.y,
                        width: screenFrame.width - screenFrame.width * state.mainPaneRatio,
                        height: screenFrame.height,
                        isMain: false,
                        unconstrainedDimension: "horizontal"
                    };
                    return { ...frames, [window.id]: frame };
                }
            }, {});
        }
    };
}
