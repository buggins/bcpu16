#ifndef SOURCEFILE_H
#define SOURCEFILE_H

#include <string>
#include <vector>

class SourceFile;

class SourceLine {
protected:
    SourceFile * file;
    std::string text;
    int lineNumber;
public:
    SourceLine(SourceFile * sourceFile, std::string line, int number)
    : file(sourceFile), text(line), lineNumber(number) 
    {}
    SourceFile * getSourceFile() { return file; }
    const std::string& getText() const { return text; }
    int getLineNumber() const { return lineNumber; }
};

class SourceFile {
protected:
    SourceLine* includedFrom;
    std::string pathname;
    std::vector<SourceLine*> lines;
    void addLine(std::string text) {
        lines.push_back(new SourceLine(this, text, lines.size() + 1));
    }
public:
    SourceFile()
        : includedFrom(nullptr), pathname() {

    }
    SourceFile(std::string fileName, SourceLine* includedFromLine)
        : includedFrom(includedFromLine), pathname(fileName) {

    }
    ~SourceFile() {
        clear();
    }
    void clear() {
        for (auto p = lines.begin(); p < lines.end(); p++)
            delete (*p);
        lines.clear();
    }
    SourceLine* getIncludedFrom() { return includedFrom; }
    bool load(std::string fileName);
    int lineCount() { return lines.size(); }
    SourceLine * line(int index) {
        if (index < 0 || index > (int)lines.size())
            return nullptr;
        return lines[index];
    }
    void dump();
};

#endif // SOURCEFILE_H
