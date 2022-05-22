function layout() {
    return {
        name: "Static Ratio Tall",
        initialState: {
            mainPaneCount: 1
        },
        commands: {
            command3: {
                description: "Increase main pane count",
                updateState: (state) => {
                    return { ...state, mainPaneCount: state.mainPaneCount + 1 };
                }
            },
            command4: {
                description: "Decrease main pane count",
                updateState: (state) => {
                    return { ...state, mainPaneCount: Math.max(1, state.mainPaneCount - 1) };
                }
            }
        },
        getFrameAssignments: (windows, screenFrame, state) => {
            const mainPaneCount = Math.min(state.mainPaneCount, windows.length);
            const secondaryPaneCount = windows.length - mainPaneCount;
            const hasSecondaryPane = secondaryPaneCount > 0;

            const mainPaneWindowHeight = Math.round(screenFrame.height / mainPaneCount);
            const secondaryPaneWindowHeight = Math.round(hasSecondaryPane ? (screenFrame.height / secondaryPaneCount) : 0);

            return windows.reduce((frames, window, index) => {
                const isMain = index < mainPaneCount;
                let frame;
                if (isMain) {
                    frame = {
                        x: screenFrame.x,
                        y: screenFrame.y + mainPaneWindowHeight * index,
                        width: screenFrame.width / 2,
                        height: mainPaneWindowHeight
                    };
                } else {
                    frame = {
                        x: screenFrame.x + screenFrame.width / 2,
                        y: screenFrame.y + secondaryPaneWindowHeight * (index - mainPaneCount),
                        width: screenFrame.width / 2,
                        height: secondaryPaneWindowHeight
                    }
                }
                return { ...frames, [window.id]: frame };
            }, {});
        }
    };
}
