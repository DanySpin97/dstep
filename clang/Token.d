/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Feb 14, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

module clang.Token;

import std.typecons;
import std.conv : to;

import clang.c.Index;
import clang.SourceLocation;
import clang.SourceRange;
import clang.Type;
import clang.Util;
import clang.Visitor;
import clang.Cursor;

enum TokenKind
{
    punctuation = CXTokenKind.CXToken_Punctuation,
    keyword = CXTokenKind.CXToken_Keyword,
    identifier = CXTokenKind.CXToken_Identifier,
    literal = CXTokenKind.CXToken_Literal,
    comment = CXTokenKind.CXToken_Comment,
}

TokenKind toD(CXTokenKind kind)
{
    return cast (TokenKind) kind;
}

struct Token
{
    private struct Container
    {
        CXTranslationUnit translationUnit;
        CXToken* tokens;
        ulong numTokens;

        ~this()
        {
            if (tokens != null)
            {
                clang_disposeTokens(
                    translationUnit,
                    tokens,
                    to!uint(numTokens));
            }
        }
    }

    private RefCounted!Container container;
    size_t index;

    @property private Container* containerPtr() const
    {
        return cast(Container*) &(container.refCountedPayload());
    }

    @property static Cursor empty ()
    {
        auto r = clang_getNullCursor();
        return Cursor(r);
    }

    @property string spelling() const
    {
        import clang.Util : toD;

        return toD(clang_getTokenSpelling(
            containerPtr.translationUnit,
            containerPtr.tokens[index]));
    }

    @property TokenKind kind() const
    {
        return clang_getTokenKind(containerPtr.tokens[index]).toD;
    }

    @property SourceLocation location() const
    {
        return SourceLocation(
            clang_getTokenLocation(
                containerPtr.translationUnit,
                containerPtr.tokens[index]));
    }

    @property SourceRange extent() const
    {
        return SourceRange(
            clang_getTokenExtent(
                containerPtr.translationUnit,
                containerPtr.tokens[index]));
    }

    @property string toString() const
    {
        import std.format: format;
        return format("Token(%s, %s)", kind, spelling);
    }
}

struct TokenRange
{
    private RefCounted!(Token.Container) container;
    private size_t begin;
    private size_t end;

    private static RefCounted!(Token.Container) makeContainer(
        CXTranslationUnit translationUnit,
        CXToken* tokens,
        ulong numTokens)
    {
        RefCounted!(Token.Container) result;
        result.translationUnit = translationUnit;
        result.tokens = tokens;
        result.numTokens = numTokens;
        return result;
    }

    private this(
        RefCounted!(Token.Container) container,
        size_t begin,
        size_t end)
    {
        this.container = container;
        this.begin = begin;
        this.end = end;
    }

    this(
        CXTranslationUnit translationUnit,
        CXToken* tokens,
        ulong numTokens)
    {
        container = makeContainer(translationUnit, tokens, numTokens);
        begin = 0;
        end = numTokens;
    }

    @property bool empty() const
    {
        return begin >= end;
    }

    @property Token front()
    {
        return Token(container, begin);
    }

    @property Token back()
    {
        return Token(container, end - 1);
    }

    @property void popFront()
    {
        ++begin;
    }

    @property void popBack()
    {
        --end;
    }

    @property TokenRange save()
    {
        return this;
    }

    @property size_t length() const
    {
        return end - begin;
    }

    Token opIndex(size_t index)
    {
        return Token(container, begin + index);
    }

    TokenRange opSlice(size_t begin, size_t end)
    {
        return TokenRange(container, this.begin + begin, this.begin + end);
    }

    size_t opDollar() const
    {
        return length;
    }
}
