const statusElement = document.getElementById('status');
const cellTmpl = document.querySelector('#cell-template .cell');
const plotErrTmpl = document.querySelector('#plot-template .plot-err');
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
    focusCell(curCell);
}

/** @param {Cell} cell */
function focusCell(cell) {
    cell.input.focus({ preventScroll: true });
    if (cell.input.readOnly) {
        cell.input.select();
    }
    cell.node.scrollIntoView({ behavior: 'smooth' });
}

/** @param {KeyboardEvent} ev */
function onKey(ev) {
    /** @type {HTMLInputElement} */
    const inp = ev.target;
    if (ev.key === 'Enter') {
        const text = inp.value;
        if (inp === curCell.input) {
            if (text.trim() !== '') {
                curCell.result.textContent = calc.calculateAndPrint(text, 1000);
            }
            newCell();
        } else {
            if (text.trim() !== '') {
                curCell.input.value = text;
            }
            focusCell(curCell);
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

const emptySvg = `<?xml version="1.0" encoding="utf-8" standalone="no"?>
<svg
 width="600" height="480"
 viewBox="0 0 600 480"
 xmlns="http://www.w3.org/2000/svg"
 xmlns:xlink="http://www.w3.org/1999/xlink"
/>`;

let emptySvgUrl;
let plot_id = 0;
let gnuplotWorker;

const makeSvgUrl = (data) =>
    URL.createObjectURL(new Blob([data], { type: 'image/svg+xml' }));
function runGnuplot(data_files, commands, extra_commandline, persist) {
    if (!gnuplotWorker) {
        gnuplotWorker = new Worker('gnuplot-worker.js');
        gnuplotWorker.addEventListener('message', (ev) => {
            const { id, output } = ev.data;
            const plot = document.getElementById('plot_' + id);
            if (output) {
                plot.src = makeSvgUrl(output);
                setTimeout(() => {
                    focusCell(curCell);
                }, 10);
            } else {
                plot.replaceWith(plotErrTmpl.cloneNode(true));
            }
        });
    }
    if (!emptySvgUrl) {
        emptySvgUrl = makeSvgUrl(emptySvg);
    }

    const img = new Image();
    img.classList.add('plot');
    img.src = emptySvgUrl;
    const id = plot_id++;
    img.id = 'plot_' + id;
    curCell.node.insertAdjacentElement('afterend', img);

    gnuplotWorker.postMessage({
        data_files,
        commands,
        extra_commandline,
        persist,
        id,
    });
    return true;
}

var Module = {
    postRun: () => {
        console.time('new');
        window.calc = new Module.Calculator();
        calc.loadGlobalDefinitions();
        console.timeEnd('new');

        newCell();
    },
    print: function (text) {
        if (arguments.length > 1)
            text = Array.prototype.slice.call(arguments).join(' ');
        console.log(text);
    },
    printErr: function (text) {
        if (arguments.length > 1)
            text = Array.prototype.slice.call(arguments).join(' ');
        console.error(text);
    },
    setStatus: function (text) {
        if (!Module.setStatus.last)
            Module.setStatus.last = { time: Date.now(), text: '' };
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
        Module.setStatus(
            left
                ? 'Preparing... (' +
                      (this.totalDependencies - left) +
                      '/' +
                      this.totalDependencies +
                      ')'
                : 'All downloads complete.'
        );
    },
};
Module.setStatus('Downloading...');
window.onerror = function (event) {
    // TODO: do not warn on ok events like simulating an infinite loop or exitStatus
    Module.setStatus('Exception thrown, see JavaScript console');
    Module.setStatus = function (text) {
        if (text) Module.printErr('[post-exception status] ' + text);
    };
};
