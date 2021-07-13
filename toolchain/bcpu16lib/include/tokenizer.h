#ifndef TOKENIZER_H
#define TOKENIZER_H

#include <string>
#include "sourcefile.h"

enum bcpu16_asm_token_t {
    TOKEN_ERROR,
    TOKEN_EOF,
    TOKEN_EOL,
    TOKEN_ASM_INSTR, // asm instruction mnemonic
    TOKEN_DOT_CMD,   // .ident
    TOKEN_IDENT,     // identifier
    TOKEN_NUMBER,    // number constant
    TOKEN_COMMA,     // ,
    TOKEN_COLON,     //  :
    TOKEN_WHITESPACE,
    TOKEN_COMMENT,
};

enum bcpu16_asm_instr_t {
    ASM_INSTR_NOP,
    ASM_INSTR_MOV,
    ASM_INSTR_ADD,
    ASM_INSTR_ADC,
    ASM_INSTR_SUB,
    ASM_INSTR_SBC,
    ASM_INSTR_INC,
    ASM_INSTR_DEC,
    ASM_INSTR_AND,
    ASM_INSTR_XOR,
    ASM_INSTR_OR,
    ASM_INSTR_ANN,
    ASM_INSTR_MUL,
    ASM_INSTR_MUU,
    ASM_INSTR_MSU,
    ASM_INSTR_MUU,
    ASM_INSTR_CMP,
    ASM_INSTR_CPC,
    ASM_INSTR_LOAD,
    ASM_INSTR_STORE,
    ASM_INSTR_JMP,
    ASM_INSTR_CALL,
    ASM_INSTR_RET,
    ASM_INSTR_JC,
};

class SourceLine;

class Token {
public:
    bcpu16_asm_token_t type;
    int id;
    std::string str;
    int intValue;
    // source line
    const SourceLine * srcLine;
    // position in source line
    int srcPos;
public:

    Token() : type(TOKEN_EOF), id(0), str(), intValue(), srcLine(nullptr), srcPos(0) { }
    Token(const Token & v) : type(v.type), id(v.id), str(v.str), intValue(v.intValue), srcLine(v.srcLine), srcPos(v.srcPos) {

    }
    Token * setWhitespace() {
        type = TOKEN_WHITESPACE;
    }
    Token * setEol() {
        type = TOKEN_EOL;
    }
    Token * setComment() {
        type = TOKEN_EOL;
    }
    Token * setSource(SourceLine * line, int pos) {
        srcLine = line;
        srcPos = pos;
        return this;
    }
    Token * setIdent(std::string ident) {
        type = TOKEN_IDENT;
        str = ident;
    }
    Token * setInstr(int instrId, std::string mnemonic) {
        type = TOKEN_ASM_INSTR;
        id = instrId;
        str = mnemonic;
        return this;
    }
    Token * setInt(int value, std::string s) {
        type = TOKEN_NUMBER;
        intValue = value;
        str = s;
    }
    bcpu16_asm_token_t getType() const { return type; }
    int getId() const { return id; }
    std::string getString() { return str; }
    int getInt() { return intValue; }
};

class Tokenizer {
private:
    SourceFile * f;
    int line;
    SourceLine * currentLine;
    int currentLinePos;
    std::string currentLineText;
    int currentLineLen;
public:
    Tokenizer() : f(nullptr), line(0), currentLine(nullptr), currentLinePos(0), currentLineLen(0) {

    }
    void updateLine() {
        if (f->lineCount() > 0) {
            currentLine = f->line(0);
            currentLineText = currentLine->getText();
        }
        else {
            currentLine = nullptr;
            currentLineText.clear();
        }
        currentLinePos = 0;
        currentLineLen = currentLineText.length();
    }
    void init(SourceFile * file) {
        f = file;
        line = 0;
        updateLine();
    }
    Token * newToken() {
        Token * tok = new Token();
        tok->setSource(currentLine, currentLinePos);
        return tok;
    }
    Token * nextLine() {
        Token * tok = newToken()->setEol();
        line++;
        updateLine();
        return tok;
    }
    Token * nextToken() {
        if (line >= f->lineCount()) {
            return nullptr;
        }
        if (currentLinePos >= currentLineText.length()) {
            // return EOL token, and move to next line
            return nextLine();
        }
        return nullptr;
    }
};


#endif // TOKENIZER_H
