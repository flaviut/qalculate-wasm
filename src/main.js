const statusElement = document.getElementById('status');
const cellTmpl = document.querySelector('#cell-template .cell');
const cells = document.getElementById('cells');

/** @typedef {node: HTMLElement, input: HTMLInputElement, result: HTMLElement} Cell */

/** @type {Cell} */
let curCell;

/** @returns {Cell} */
const getCell = (cellNode) => ({
    node: cellNode,
    input: cellNode.querySelector('.cell-input'),
    result: cellNode.querySelector('.cell-result'),
});

let cellNum = 0;

function newCell() {
    if (curCell) {
        curCell.input.readOnly = true;
    }

    curCell = getCell(cellTmpl.cloneNode(true));
    cellNum += 1;
    curCell.node.id = 'cell_' + cellNum;
    curCell.input.addEventListener('keydown', onKey);
    cells.append(curCell.node);
    focusCell();
}

function focusCell(cell) {
    const c = cell || curCell;
    c.input.focus({ preventScroll: true });
    if (c.node !== curCell.node) {
        c.input.select();
    }
    c.node.scrollIntoView({ behavior: 'smooth' });
}

/** @param {KeyboardEvent} ev */
function onKey(ev) {
    /** @type {HTMLInputElement} */
    const inp = ev.target;
    if (ev.key === 'Enter') {
        const text = inp.value;
        if (inp === curCell.input) {
            curCell.result.textContent = calc.calculateAndPrint(text, 1000);
            newCell();
        } else {
            curCell.input.value = text;
            focusCell();
        }
    } else if (ev.key === 'ArrowUp' || ev.key === 'ArrowDown') {
        const cellNode = inp.parentElement;
        const adjacent =
            ev.key === 'ArrowUp'
                ? 'previousElementSibling'
                : 'nextElementSibling';
        let adjacentCellNode = cellNode;
        do {
            // this would be null if e.g. we're at the top and try to go up
            adjacentCellNode = adjacentCellNode[adjacent];
        } while (
            adjacentCellNode != null &&
            !adjacentCellNode.classList.contains('cell')
        );
        if (adjacentCellNode) {
            focusCell(getCell(adjacentCellNode));
        }
        ev.preventDefault();
    }
}

let gnuplotWorker;

function runGnuplot(data_files, commands, extra_commandline, persist) {
    if (!gnuplotWorker) {
        gnuplotWorker = new Worker('gnuplot-worker.js');
        gnuplotWorker.addEventListener('message', (ev) => {
            const { id, output } = ev.data;
            const url = URL.createObjectURL(new Blob([output], { type: 'image/svg+xml' }));
            const img = new Image();
            img.classList.add('plot');
            img.src = url;
            const cell_id = 'cell_' + id;
            document.getElementById(cell_id).insertAdjacentElement('afterend', img);
            setTimeout(() => {
                focusCell();
            }, 10);
        });
    }
    gnuplotWorker.postMessage({ data_files, commands, extra_commandline, persist, id: cellNum });
    return true;
}

var Module = {
    postRun: () => {
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
    },
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
    Module.setStatus('Exception thrown, see JavaScript console');
    Module.setStatus = function (text) {
        if (text) Module.printErr('[post-exception status] ' + text);
    };
};
