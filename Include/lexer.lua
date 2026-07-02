local keywords = {
    ["function"] = true,
    ["for"] = true,
    ["do"] = true,
    ["if"] = true,
    ["then"] = true,
    ["else"] = true,
    ["elseif"] = true,
    ["repeat"] = true,
    ["until"] = true,
    ["while"] = true,

    ["not"] = true,
    ["and"] = true,
    ["or"] = true,
    ["in"] = true,

    ["nil"] = true,
    ["true"] = true,
    ["false"] = true,

    ["break"] = true,
    ["end"] = true,
    ["return"] = true,

    ["goto"] = true,
    ["local"] = true
}
local twoCharacterOperators = {
    [".."] = true,
    ["~="] = true,
    ["=="] = true,
    -- ["<<"] = true,
    -- [">>"] = true,
    ["<="] = true,
    ["<="] = true,
	[">="] = true,
}
local singleCharacterOperators = {
    [">"] = true,
    ["<"] = true,
    ["="] = true,
    ["."] = true,
    ["-"] = true,
    ["/"] = true,
    ["*"] = true,
    ["%"] = true,
    ["#"] = true,
    ["#"] = true,
}

local punctuation = {
    [","] = true,
    [":"] = true,
    [";"] = true,
    ["("] = true,
    [")"] = true,
    ["["] = true,
    ["]"] = true,
    ["{"] = true,
    ["}"] = true,
}

local whitespace = {
    [" "] = true,
    ["\t"] = true,
    ["\r"] = true,
    ["\n"] = true,
}

local keywordOrAttributePrimaryCharacterSet = "[%a_]"
local keywordOrAttributeSecondaryCharacterSet = "[%a%d_]"
local numberLiteralPrimaryCharacterSet = "%d"
local numberLiteralSecondaryCharacterSet = "[%d_.]"
local numberLiteralTertiaryCharacterSet = "[%d_]"
local operatorCharacterSet = "[#=%+%-%*/%%%^&~|<>=%.]"

local TOKEN_TYPE_STRING_LITERAL = 1
local TOKEN_TYPE_UNCLOSED_STRING_LITERAL = 2
local TOKEN_TYPE_KEYWORD = 3
local TOKEN_TYPE_ATTRIBUTE = 4
local TOKEN_TYPE_NUMBER_LITERAL = 5
local TOKEN_TYPE_MULTILINE_COMMENT = 6
local TOKEN_TYPE_COMMENT = 7
local TOKEN_TYPE_OPERATOR = 8
local TOKEN_TYPE_INVALID_CHARACTER = 9
local TOKEN_TYPE_MULTILINE_STRING_LITERAL = 10
local TOKEN_TYPE_PUNCTUATION = 11
local TOKEN_TYPE_WHITESPACE = 12

local function lexStringLiteral(string, startIndex, terminator)
    local nextIndex = startIndex
    local escaped

    while nextIndex <= string:len() do
        local nextCharacter = string:sub(nextIndex, nextIndex)
        if escaped then
            escaped = false
        else
            if nextCharacter == terminator then
                return TOKEN_TYPE_STRING_LITERAL, startIndex - 1, nextIndex
            elseif nextCharacter == "\n" then
                return TOKEN_TYPE_UNCLOSED_STRING_LITERAL, startIndex - 1, nextIndex
            elseif nextCharacter == "\\" then
                escaped = true
            end
        end
        nextIndex = nextIndex + 1
    end

    return TOKEN_TYPE_UNCLOSED_STRING_LITERAL, startIndex - 1, string:len()
end

local function parseMultiLine(string, startIndex)
    if string:sub(startIndex, startIndex) ~= "[" then
        return nil
    end

    local layerCount = 0
    local nextIndex = startIndex + 1

    while nextIndex <= string:len() do
        local nextCharacter = string:sub(nextIndex, nextIndex)
        if nextCharacter == "=" then
            layerCount = layerCount + 1
            nextIndex = nextIndex + 1
        elseif nextCharacter == "[" then
            nextIndex = nextIndex + 1
            break
        else 
            return nil
        end
    end

    local multilineClose = "%]"
    for i = 1, layerCount do
        multilineClose = multilineClose .. "="
    end
    multilineClose = multilineClose .. "%]"
    local commentCloseBegin, commentCloseEnd = string:find(multilineClose, nextIndex)
    
    if commentCloseBegin then
        return commentCloseEnd
    end
end

local function lex(string)
    local tokenCount = 0
    local tokenTypes = {}
    local tokenStartIndices = {}
    local tokenEndIndices = {}

    local function addToken(type, startIndex, endIndex)
        tokenCount = tokenCount + 1
        tokenTypes[tokenCount] = type
        tokenStartIndices[tokenCount] = startIndex
        tokenEndIndices[tokenCount] = endIndex
    end

    local nextIndex = 1
    local stringLength = string:len()
    
    while nextIndex <= stringLength do
        local shouldContinue

        local currentIndex = nextIndex
        nextIndex = nextIndex + 1

        local character = string:sub(currentIndex, currentIndex)

        if whitespace[character] then
            addToken(TOKEN_TYPE_WHITESPACE, currentIndex, currentIndex)
        elseif punctuation[character] then
            addToken(TOKEN_TYPE_PUNCTUATION, currentIndex, currentIndex)
        elseif character:find(keywordOrAttributePrimaryCharacterSet) then
            local startIndex = currentIndex
            while currentIndex <= stringLength do
                local character = string:sub(nextIndex, nextIndex)
                if not character or not character:find(keywordOrAttributeSecondaryCharacterSet) then
                    local keywordOrAttribute = string:sub(startIndex, currentIndex)
                    local tokenType
                    if keywords[keywordOrAttribute] then
                        tokenType = TOKEN_TYPE_KEYWORD
                    else
                        tokenType = TOKEN_TYPE_ATTRIBUTE
                    end

                    addToken(tokenType, startIndex, currentIndex)

                    nextIndex = currentIndex + 1
                    break
                end

                currentIndex = nextIndex
                nextIndex = nextIndex + 1
            end

        elseif character:find(numberLiteralPrimaryCharacterSet) then
            local numberBegin, numberEnd = string:find("[%d_]*[%.x]?[%d_ABCDEF]*", nextIndex) -- TODO: more fine-grained parsing, what if the decimal point is there, and nothing after it?
            if numberBegin == nextIndex then
                addToken(TOKEN_TYPE_NUMBER_LITERAL, currentIndex, numberEnd)
                nextIndex = numberEnd + 1
            else
                addToken(TOKEN_TYPE_NUMBER_LITERAL, currentIndex, currentIndex)
            end
        elseif character == "-" and string:sub(nextIndex, nextIndex) == "-" then -- comment
            local multilineCommentEndIndex = parseMultiLine(string, nextIndex + 1)
            if multilineCommentEndIndex then
                addToken(TOKEN_TYPE_MULTILINE_COMMENT, currentIndex, multilineCommentEndIndex)
                nextIndex = multilineCommentEndIndex + 1
            else
                local commentEnd = string:find("\n", nextIndex + 1) or stringLength
                addToken(TOKEN_TYPE_COMMENT, currentIndex, commentEnd)
                nextIndex = commentEnd + 1
            end
        elseif character:find(operatorCharacterSet) then
            if twoCharacterOperators[string:sub(currentIndex, nextIndex)] then
                addToken(TOKEN_TYPE_OPERATOR, currentIndex, nextIndex)
                nextIndex = nextIndex + 1
            elseif singleCharacterOperators[string:sub(currentIndex, currentIndex)] then
                addToken(TOKEN_TYPE_OPERATOR, currentIndex, currentIndex)
            else
                addToken(TOKEN_TYPE_INVALID_CHARACTER, currentIndex, currentIndex)
            end
        elseif character == "\'" then
            addToken(lexStringLiteral(string, nextIndex, "\'"))
            nextIndex = tokenEndIndices[tokenCount] + 1
        elseif character == "\"" then
            addToken(lexStringLiteral(string, nextIndex, "\""))
            nextIndex = tokenEndIndices[tokenCount] + 1
        elseif character == "[" then -- multi-line string literal
            local multilineStringEndIndex = parseMultiLine(string, currentIndex)
            if multilineStringEndIndex then
                addToken(TOKEN_TYPE_MULTILINE_STRING_LITERAL, currentIndex, multilineStringEndIndex)
                nextIndex = multilineStringEndIndex + 1
            else
                addToken(TOKEN_TYPE_PUNCTUATION, currentIndex, currentIndex)
            end
        else
            addToken(TOKEN_TYPE_INVALID_CHARACTER, currentIndex, currentIndex)
        end
    end

    return tokenCount, tokenTypes, tokenStartIndices, tokenEndIndices
end

return {
    TOKEN_TYPE = {
        STRING_LITERAL = TOKEN_TYPE_STRING_LITERAL,
        UNCLOSED_STRING_LITERAL = TOKEN_TYPE_UNCLOSED_STRING_LITERAL,
        KEYWORD = TOKEN_TYPE_KEYWORD,
        ATTRIBUTE = TOKEN_TYPE_ATTRIBUTE,
        NUMBER_LITERAL = TOKEN_TYPE_NUMBER_LITERAL,
        MULTILINE_COMMENT = TOKEN_TYPE_MULTILINE_COMMENT,
        COMMENT = TOKEN_TYPE_COMMENT,
        OPERATOR = TOKEN_TYPE_OPERATOR,
        INVALID_CHARACTER = TOKEN_TYPE_INVALID_CHARACTER,
        MULTILINE_STRING_LITERAL = TOKEN_TYPE_MULTILINE_STRING_LITERAL,
        PUNCTUATION = TOKEN_TYPE_PUNCTUATION,
        WHITESPACE = TOKEN_TYPE_WHITESPACE
    },
    lex = lex
}