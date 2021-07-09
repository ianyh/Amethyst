var layout = {
    name: "Fullscreen",
    getFrameAssignments: (windows, screenFrame) => {
        return windows.reduce((frames, w) => ({ ...frames, [w.id]: screenFrame }), {});
    }
};
