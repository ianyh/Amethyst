function layout() {
    return {
        name: "Subset",
        initialState: {
            ids: []
        },
        commands: {
            command3: {
                description: "Add window to subset",
                updateState: (state, focusedWindowID) => {
                    const ids = state.ids;
                    if (!!focusedWindowID) {
                        const index = ids.indexOf(focusedWindowID);
                        if (index === -1) {
                            ids.push(focusedWindowID);
                        }
                    }
                    return { ...state, ids };
                }
            },
            command4: {
                description: "Remove window from subset",
                updateState: (state, focusedWindowID) => {
                    const ids = state.ids;
                    if (!!focusedWindowID) {
                        const index = ids.indexOf(focusedWindowID);
                        if (index > -1) {
                            ids.splice(index, 1);
                        }
                    }
                    return { ...state, ids };
                }
            }
        },
        getFrameAssignments: (windows, screenFrame, state) => {
            const mainPaneCount = state.ids.length;
            const secondaryPaneCount = Math.max(windows.length - mainPaneCount, 0);
            const hasSecondaryPane = secondaryPaneCount > 0;

            const mainPaneWindowWidth = hasSecondaryPane ? screenFrame.width / 2 : screenFrame.width;
            const mainPaneWindowHeight = Math.round(screenFrame.height / mainPaneCount);
            const secondaryPaneWindowHeight = Math.round(hasSecondaryPane ? (screenFrame.height / secondaryPaneCount) : 0);
            let mainIndex = 0;
            let secondaryIndex = 0;

            return windows.reduce((frames, window) => {
                const isMain = state.ids.includes(window.id);
                let frame;
                if (isMain) {
                    frame = {
                        x: screenFrame.x,
                        y: screenFrame.y + mainPaneWindowHeight * mainIndex,
                        width: mainPaneWindowWidth,
                        height: mainPaneWindowHeight
                    };
                    mainIndex++;
                } else {
                    frame = {
                        x: screenFrame.x + screenFrame.width / 2,
                        y: screenFrame.y + secondaryPaneWindowHeight * secondaryIndex,
                        width: screenFrame.width / 2,
                        height: secondaryPaneWindowHeight
                    };
                    secondaryIndex++;
                }
                return { ...frames, [window.id]: frame };
            }, {});
        },
        updateWithChange: (change, state) => {
            switch (change.change) {
                case "window_swap":
                    if (state.ids.includes(change.windowID) && !state.ids.includes(change.otherWindowID)) {
                        const index = state.ids.indexOf(change.windowID);
                        state.ids.splice(index, 1);
                        state.ids.push(change.otherWindowID);
                    } else if (state.ids.includes(change.otherWindowID) && !state.ids.includes(change.windowID)) {
                        const index = state.ids.indexOf(change.otherWindowID);
                        state.ids.splice(index, 1);
                        state.ids.push(change.windowID);
                    }
                    break;
            }

            return state;
        }
    };
}
