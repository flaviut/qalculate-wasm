#include <libqalculate/qalculate.h>
#include <emscripten/bind.h>
#include <emscripten/val.h>

using namespace emscripten;

Calculator* getCalculator() {
    // there's only one global calculator, and you're not supposed to call
    // the Calculator constructor after it's initialized
    if (CALCULATOR == nullptr) {
        new Calculator();
    }
    return CALCULATOR;
}

std::string qalc_gnuplot_data_dir() {
    return "";
}
bool qalc_invoke_gnuplot(
    std::vector<std::pair<std::string, std::string>> data_files,
    std::string commands, std::string extra, bool persist) {
    val data_obj = val::object();
    for (auto file : data_files) {
        data_obj.set(file.first, file.second);
    }
    return val::global("runGnuplot").call<bool>("call", val::undefined(), data_obj, commands, extra, persist);
}

EMSCRIPTEN_BINDINGS(calculator_bindings) {
    class_<Calculator>("Calculator")
        .constructor(&getCalculator, allow_raw_pointers())
        .function("reset", &Calculator::reset)
        .function("loadGlobalDefinitions", select_overload<bool()>(&Calculator::loadGlobalDefinitions))
        .function("calculateAndPrint", optional_override([](Calculator& self, std::string s, int msecs) {
            return self.calculateAndPrint(s, msecs);
        }));
}
