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
                const frame = {
                    x: screenFrame.x,
                    y: screenFrame.y,
                    width: screenFrame.width * state.mainPaneRatio,
                    height: screenFrame.height
                };
                return { ...frames, [window.id]: frame };
            }, {});
        }
    };
}
