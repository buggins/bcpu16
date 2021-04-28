#ifndef CMDLINE_H_INCLUDED
#define CMDLINE_H_INCLUDED

#include <string>
#include <vector>
#include <stdint.h>

class CommandLineParam {
public:
    const std::string shortName;
    const std::string longName;
    const bool mandatory;
    const bool needsValue;
    const std::string defValue;
    const std::string description;
    CommandLineParam(std::string paramShortName, std::string paramLongName, std::string paramDescription, bool isMandatory, bool valueRequired, std::string defaultValue)
        : shortName(paramShortName), longName(paramLongName), description(paramDescription)
        , mandatory(isMandatory), needsValue(valueRequired)
        , defValue(defaultValue), _isSet(false)
    {

    }
    virtual ~CommandLineParam() {}

    /// returns true if arg matches short or long name
    bool sameName(const std::string& name) {
        return (longName == name || shortName == name);
    }

    /// returns long name if defined, otherwise short name
    std::string name() { return longName.empty() ? shortName : longName; }

    /// returns true if parameter is set in commandline
    bool isSet() { return _isSet; }

    /// get parameter value as string
    std::string getString() { return strValue; }

    /// return bool parameter value, valid for bool parameters only
    virtual bool getBool() { return true; }
    /// return int parameter value, valid for numeric only
    virtual int getInt() { return 0; }


    /// sets value to parameter, returns false if value is invalid
    virtual bool setValue(const std::string& value) {
        strValue = value;
        _isSet = true;
        return true;
    }
protected:
    // string value
    std::string strValue;
    // true when value is set
    bool _isSet;
};

class StringParam : public CommandLineParam {
public:
    StringParam(std::string paramShortName, std::string paramLongName, std::string paramDescription, bool isMandatory, std::string defaultValue)
        : CommandLineParam(paramShortName, paramLongName, paramDescription, isMandatory, true, defaultValue)
    {
    }
    virtual ~StringParam() {

    }
};

class BoolParam : public CommandLineParam {
public:
    BoolParam(std::string paramShortName, std::string paramLongName, std::string paramDescription, bool defValue = false)
        : CommandLineParam(paramShortName, paramLongName, paramDescription, false, false, defValue ? "true" : "false"), value(defValue)
    {
        strValue = defValue ? "true" : "false";
    }
    ~BoolParam() override { }
    bool setValue(const std::string& str) override {
        if (!str.empty()) {
            if (str == "1" || str == "y" || str == "yes" || str == "t" || str == "true" || str == "on") {
                strValue = "true";
                value = true;
            } else if (str == "0" || str == "n" || str == "no" || str == "f" || str == "false" || str == "off") {
                strValue = "false";
                value = false;
            } else {
                return false;
            }
        }
        strValue = "true";
        value = true;
        _isSet = true;
        return true;
    }
    bool getBool() override { return value; }
protected:
    bool value;
};

class IntParam : public CommandLineParam {
public:
    IntParam(std::string paramShortName, std::string paramLongName, std::string paramDescription, bool mandatory = false, int defValue = 0, int minValue = 0, int maxValue = 0)
        : CommandLineParam(paramShortName, paramLongName, paramDescription, mandatory, true, std::to_string(defValue))
        , value(defValue)
        , _minValue(minValue), _maxValue(maxValue)
    {
        strValue = std::to_string(defValue);
    }
    ~IntParam() override { }
    bool setValue(const std::string& str) override {
        int intValue = 0;
        try {
            intValue = std::stoi(str);
        }
        catch (...) {
            return false;
        }
        if (_minValue != _maxValue) {
            if (intValue < _minValue || intValue > _maxValue) {
                return false;
            }
        }
        value = intValue;
        _isSet = true;
        return true;
    }
    int getInt() override { return value; }
protected:
    int value;
    int _minValue;
    int _maxValue;
    int _defValue;
};

/// Command line parser
class CommandLine {
public:
    CommandLine() : pendingValueArg(nullptr) {}
    virtual ~CommandLine() {}
    virtual bool parse(int argc, char * argv[]);
    std::vector<std::string> simpleArgs;
    std::vector<CommandLineParam*> params;
    // register commandline parameter
    void registerParam(CommandLineParam* param);
    // find parameter by name
    CommandLineParam* findParam(std::string paramName);
protected:
    virtual bool pushArg(std::string arg);
    virtual bool validate();
    virtual bool addSimpleArg(std::string arg);
    virtual bool addArg(CommandLineParam * param, std::string value);
    virtual bool error(std::string errMessage);
    CommandLineParam * pendingValueArg;
};



#endif //CMDLINE_H_INCLUDED

