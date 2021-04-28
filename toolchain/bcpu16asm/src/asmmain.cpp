#include <stdio.h>
#include <stdint.h>
#include <iostream>

#include "../../bcpu16lib/include/cmdline.h"
#include "../../bcpu16lib/include/sourcefile.h"



int main(int argc, char * argv[] )
{
    std::cout << "Hello, world!\n";

    CommandLine cmdline;
    BoolParam bool1("v", "verbose", "turn on diagnostic messages");
    StringParam outFile("o", "out", "output file", true, "");
    StringParam lstFile("l", "lst", "list file", false, "");
    IntParam threadCount("j", "threads", "number of threads", false, 1, 1, 16);
    cmdline.registerParam(&bool1);
    cmdline.registerParam(&outFile);
    cmdline.registerParam(&lstFile);
    if (!cmdline.parse(argc, argv)) {
        std::cerr << "Error while parsing commandline - exiting";
        return 1;
    }
    std::cerr << "Parameters: " << std::endl;
    for (auto p = cmdline.params.begin(); p < cmdline.params.end(); p++) {
        std::cerr << (*p)->name() << " = " << (*p)->getString() << std::endl;
    }
    std::cerr << "Simple strings: " << std::endl;
    for (auto p = cmdline.simpleArgs.begin(); p < cmdline.simpleArgs.end(); p++) {
        std::cerr << *p << std::endl;
    }
    if (cmdline.simpleArgs.size() != 1) {
        std::cerr << "No source file specified.";
        return 1;
    }
    SourceFile file;
    std::string fname = cmdline.simpleArgs[0];
    if (!file.load(fname)) {
        std::cerr << "Cannot open source file " << fname << std::endl;
        return 1;
    }
    std::cout << "Dumping source file" << std::endl;
    file.dump();
    return 0;
}
