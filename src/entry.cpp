#include <libqalculate/qalculate.h>
#include <emscripten/bind.h>

using namespace emscripten;

EMSCRIPTEN_BINDINGS(calculator_bindings) {
    class_<Calculator>("Calculator")
        .constructor()
        .function("reset", &Calculator::reset)
        .function("loadGlobalDefinitions", select_overload<bool()>(&Calculator::loadGlobalDefinitions))
        .function("calculateAndPrint", optional_override([](Calculator& self, std::string s, int msecs) {
            return self.calculateAndPrint(s, msecs);
        }));
}
