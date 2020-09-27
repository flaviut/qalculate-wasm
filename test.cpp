#include <libqalculate/qalculate.h>

extern "C" {
    void *newCalculator();
    char *calculate(void *calculator, char *text, int msecs);
}

void *newCalculator() {
    return new Calculator();
}

char *calculate(void *calculator, char *text, int msecs) {
    std::string result = ((Calculator *)calculator)->calculateAndPrint(text, msecs);
    char *cstr = new char[result.length() + 1];
    strcpy(cstr, result.c_str());
    return cstr;
}
