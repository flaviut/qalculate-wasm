const statusElement = document.getElementById('status');
const resultTmpl = document.getElementById('result');
const inputTmpl = document.getElementById('input');
const cells = document.getElementById('cells');

let curResult, curInput;

function newCell() {
    if (curInput){
        curInput.readOnly = true;
    }
    curResult = resultTmpl.cloneNode();
    curInput = inputTmpl.cloneNode();
    curInput.addEventListener('keypress', onKey)
    cells.append(curInput, curResult);
    focusCurrent();
}

function focusCurrent() {
    curInput.focus();
    curResult.scrollIntoView()
}

function onKey(ev) {
    if (ev.key == 'Enter') {
        const text = ev.target.value
        if (ev.target == curInput) {
            curResult.textContent = calc.calculateAndPrint(text, 1000);
            newCell();
        } else {
            curInput.value = text;
            focusCurrent();
        }
    }
}



var Module = {
    preRun: [],
    postRun: [() => {
        console.time('new')
        window.calc = new Module.Calculator()
        calc.loadGlobalDefinitions();
        console.timeEnd('new')
        console.time('calc x1000')
        for (let i = 0; i < 1000; i++) {
            calc.calculateAndPrint('1+1', 1000)
        }
        console.timeEnd('calc x1000')

        newCell();
    }],
    print: function (text) {
        if (arguments.length > 1) text = Array.prototype.slice.call(arguments).join(' ');
        console.log(text);
    },
    printErr: function (text) {
        if (arguments.length > 1) text = Array.prototype.slice.call(arguments).join(' ');
        console.error(text);
    },
    setStatus: function (text) {
        if (!Module.setStatus.last) Module.setStatus.last = { time: Date.now(), text: '' };
        if (text === Module.setStatus.last.text) return;
        var m = text.match(/([^(]+)\((\d+(\.\d+)?)\/(\d+)\)/);
        var now = Date.now();
        if (m && now - Module.setStatus.last.time < 30) return; // if this is a progress update, skip it if too soon
        Module.setStatus.last.time = now;
        Module.setStatus.last.text = text;
        if (m) {
            text = m[1];
        }
        statusElement.innerHTML = text;
    },
    totalDependencies: 0,
    monitorRunDependencies: function (left) {
        this.totalDependencies = Math.max(this.totalDependencies, left);
        Module.setStatus(left ? 'Preparing... (' + (this.totalDependencies - left) + '/' + this.totalDependencies + ')' : 'All downloads complete.');
    }
};
Module.setStatus('Downloading...');
window.onerror = function (event) {
    // TODO: do not warn on ok events like simulating an infinite loop or exitStatus
    Module.setStatus('Exception thrown, see JavaScript console ' + event + event.stack);
    Module.setStatus = function (text) {
        if (text) Module.printErr('[post-exception status] ' + text);
    };
};
