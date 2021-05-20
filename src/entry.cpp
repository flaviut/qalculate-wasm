#include <libqalculate/qalculate.h>
#include <emscripten/bind.h>

using namespace emscripten;

Calculator* getCalculator() {
    // there's only one global calculator, and you're not supposed to call
    // the Calculator constructor after it's initialized
    if (CALCULATOR == nullptr) {
        new Calculator();
    }
    return CALCULATOR;
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
