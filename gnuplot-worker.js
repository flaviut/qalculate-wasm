let pendingRequests = [];

self.addEventListener('message', ({ data }) => {
    if (pendingRequests) {
        // gnuplot not loaded yet
        pendingRequests.push(data);
    } else {
        doPlot(data);
    }
});

var Module = {
    noInitialRun: true,
    postRun: () => {
        shouldRunNow = true;
        pendingRequests.forEach(doPlot);
        pendingRequests = null;
    },
    print: (s) => {
        console.log('GNUPLOT LOG: ' + s);
    },
    printErr: (s) => {
        console.warn('GNUPLOT ERR: ' + s);
    },
};

function doPlot({
    fix_cmd = true,
    data_files = {},
    commands,
    id,
    // TODO: do something with these...?
    extra_commandline,
    persist,
}) {
    const files = Object.keys(data_files);
    for (const [file, data] of Object.entries(data_files)) {
        FS.writeFile(file, data);
    }
    const cmd = fix_cmd
        ? commands.replace(
              'set terminal pop',
              "set terminal svg; set output '/output'"
          )
        : commands;
    FS.writeFile('/commands', cmd);
    callMain(['/commands']);
    const output = FS.readFile('/output', { encoding: 'utf8' });
    for (const file of ['/commands', '/output', ...files]) {
        FS.unlink(file);
    }
    self.postMessage({ id, output });
}

importScripts('gnuplot.js');
