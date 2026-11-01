function layout() {
    return {
        name: "Resize Step Commands",
        initialState: {
            mainPaneRatio: 0.5
        },
        commands: {
            expandMain: {
                description: "Expand the main pane by the user's resize step",
                updateState: (state, focusedWindowID, settings) => {
                    return { ...state, mainPaneRatio: Math.min(1, state.mainPaneRatio + settings.windowResizeStep) };
                }
            },
            shrinkMain: {
                description: "Shrink the main pane by the user's resize step",
                updateState: (state, focusedWindowID, settings) => {
                    return { ...state, mainPaneRatio: Math.max(0, state.mainPaneRatio - settings.windowResizeStep) };
                }
            }
        },
        getFrameAssignments: (windows, screenFrame, state) => {
            const mainWidth = Math.round(screenFrame.width * state.mainPaneRatio);
            return windows.reduce((frames, window, index) => {
                const frame = index === 0
                    ? { x: screenFrame.x, y: screenFrame.y, width: mainWidth, height: screenFrame.height }
                    : { x: screenFrame.x + mainWidth, y: screenFrame.y, width: screenFrame.width - mainWidth, height: screenFrame.height };
                return { ...frames, [window.id]: frame };
            }, {});
        }
    };
}
