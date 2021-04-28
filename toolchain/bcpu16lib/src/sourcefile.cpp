#include "../include/sourcefile.h"

#include <stdio.h>
#include <iostream>
#include <fstream>

bool SourceFile::load(std::string fileName) {
    try {
        std::ifstream file;
        file.open(fileName, std::ios::in);
        if (!file.is_open()) {
            return false;
        }
        std::string str;
        pathname = fileName;
        while (std::getline(file, str)) {
            addLine(str);
        }
        return true;
    }
    catch (...) {
        return false;
    }
}


void SourceFile::dump() {
    for (auto p = lines.begin(); p < lines.end(); p++) {
        printf("%-8d %s\n", (*p)->getLineNumber(), (*p)->getText().c_str());
    }
}

