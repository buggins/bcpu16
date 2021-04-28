#include "../include/cmdline.h"
#include <iostream>

void CommandLine::registerParam(CommandLineParam* param) {
    params.push_back(param);
}
CommandLineParam* CommandLine::findParam(std::string paramName) {
    for (auto p = params.begin(); p < params.end(); p++) {
        if ((*p)->sameName(paramName)) {
            return *p;
        }
    }
    return nullptr;
}

bool CommandLine::addSimpleArg(std::string arg)
{
    std::cerr << "simple param: " << arg << std::endl;
    simpleArgs.push_back(arg);
    return true;
}

bool CommandLine::addArg(CommandLineParam * param, std::string value) {
    if (!param->setValue(value)) {
        return error("invalid value " + value + " for parameter " + param->name());
    }
    std::cerr << "param: " << param->name() << " = " << value << std::endl;
    return true;
}

bool CommandLine::error(std::string errMessage)
{
    std::cerr << errMessage << std::endl;
    return false;
}

bool CommandLine::pushArg(std::string arg)
{
    std::string pname;
    std::string pvalue;
    int paramNamePrefix = 0;
    if (arg.length() >= 2) {
        if (arg[0] == '-') {
            if (pendingValueArg) {
                return error("Expected value for argument " + pendingValueArg->name() + " but found " + arg);
            }
            paramNamePrefix++;
            if (arg[1] == '-') {
                paramNamePrefix++;
            }
        }
    }
    std::string s = arg.substr(paramNamePrefix);
    if (s.length() < 1 || s[0] == '-') {
        return error("Invalid commandline argument " + arg);
    }
    if (!paramNamePrefix) {
        if (pendingValueArg) {
            // part 2: value for previous arg
            bool res = addArg(pendingValueArg, arg);
            pendingValueArg = nullptr;
            return res;
        }
        return addSimpleArg(arg);
    }
    if (paramNamePrefix == 1) {
        // short param    -v  -v123
        pname = s.substr(0, 1);
        if (s.length() > 1)
            pvalue = s.substr(1);
    }
    else {
        auto eqpos = s.find('=');
        if (eqpos == std::string::npos) {
            pname = s;
        }
        else {
            pname = s.substr(0, eqpos);
            pvalue = s.substr(eqpos + 1);
        }
    }
    auto param = findParam(pname);
    if (!param) {
        return error("unknown parameter " + pname);
    }
    if (param->needsValue) {
        if (pvalue.empty()) {
            pendingValueArg = param;
            return true;
        }
        return addArg(param, pvalue);
    }
    if (!pvalue.empty()) {
        return error("unexpected value for parameter " + pname);
    }
    return addArg(param, pvalue);
}

bool CommandLine::parse(int argc, char * argv[]) {
    for (int i = 1; i < argc; i++) {
        std::string arg(argv[i]);
        if (!pushArg(arg))
            return false;
    }
    return validate();
}

bool CommandLine::validate() {
    if (pendingValueArg) {
        return error("value for parameter " + pendingValueArg->name() + " is missing");
    }
    for (auto p = params.begin(); p < params.end(); p++) {
        if ((*p)->mandatory && !(*p)->isSet()) {
            return error("madatory parameter " + (*p)->name() + " is not specified");
        }
    }
    return true;
}

