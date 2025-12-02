#!/usr/bin/env python3

import sys

class BadArgException(Exception):
    pass

def at(i, name, args):
    start = i
    end = name+".end"
    r = []

    while len(args):
        arg = args.pop(0)
        i += 1
        if arg == end:
            return i, r, args
        r.append(arg)

    raise BadArgException(f"Expected '{end}' after arg {start}.")

def split(names, args):
    """

    :param names: the names of specified arrays
    :param args: list of args
    :return: tuple of map values of spefied arrays and std values

    >>> split(["a", "b"], [])
    ({'a': [], 'b': []}, [])
    >>> split(["a", "b"], ["1", "2"])
    ({'a': [], 'b': []}, ['1', '2'])
    >>> split(["a", "b"], ["a.start", "a.end", "b.start", "b.end"])
    ({'a': [], 'b': []}, [])
    >>> split(["a", "b"], ["a.start", "a1", "a.end", "b.start", "b.end"])
    ({'a': ['a1'], 'b': []}, [])
    >>> split(["a"], ["a.start", "a1", "a.end", "b.start", "b1", "b.end"])
    ({'a': ['a1']}, ['b.start', 'b1', 'b.end'])
    >>> split(["a", "b"], ["a.start", "a1", "a2", "a.end", "b.start", "b.end"])
    ({'a': ['a1', 'a2'], 'b': []}, [])
    >>> split(["a", "b"], ["a.start", "a1", "a2", "a.end", "b.start", "b1", "b.end"])
    ({'a': ['a1', 'a2'], 'b': ['b1']}, [])
    >>> split(["a", "b"], ["a.start", "a1", "a2", "a.end", "3", "b.start", "b1", "b.end", "4"])
    ({'a': ['a1', 'a2'], 'b': ['b1']}, ['3', '4'])
    >>> split(["a", "b"], ["1", "2", "a.start", "a1", "a2", "a.end", "3", "b.start", "b1", "b.end", "4"])
    ({'a': ['a1', 'a2'], 'b': ['b1']}, ['1', '2', '3', '4'])
    >>> split(["a", "b"], ["1", "2", "a.start", "a1", "a2", "a.end", "3", "b.start", "b1", "b.end", "4", "a.start", "a3", "a4", "a.end"])
    ({'a': ['a1', 'a2', 'a3', 'a4'], 'b': ['b1']}, ['1', '2', '3', '4'])
    >>> split(["a", "b"], ["a.start", "a.end", "b.start"])
    Traceback (most recent call last):
    BadArgException: Expected 'b.end' after arg 2.
    >>> split(["a", "b"], ["a.start", "a1", "a.end", "b.start", "b1", "b2"])
    Traceback (most recent call last):
    BadArgException: Expected 'b.end' after arg 3.
    """
    out = {n: [] for n in names}
    std = []
    i = -1

    while len(args):
        arg = args.pop(0)
        i += 1

        ok = False
        for n in names:
            if arg == n+".start":
                ok = True
                i, v, rest = at(i, n, args)
                if v is None:
                    return None

                out[n].extend(v)
                args = rest
                break

        if not ok:
            std.append(arg)

    return out, std

def to_bash(std_name, names, args):
    """
    split and generate bash command
    :param std_name: the name of std array
    :param names: the names of specified arrays
    :param args: list of args
    :return: bash command lines

    >>> to_bash("std_array", [], [])
    []
    >>> to_bash("std_array", [], ["1", "2"])
    ['std_array+=( 1 2 )']
    >>> to_bash("std_array", ["a", "b"], [])
    []
    >>> to_bash("std_array", ["a", "b"], ["1", "2"])
    ['std_array+=( 1 2 )']
    >>> to_bash("std_array", ["a", "b"], ["a.start", "a.end", "b.start", "b.end"])
    []
    >>> to_bash("std_array", ["a", "b"], ["1", "2", "a.start", "a1", "a 2", "a.end"])
    ['std_array+=( 1 2 )', "a+=( a1 'a 2' )"]
    """

    from shlex import quote

    out, std = split(names, args)
    r = []

    if len(std):
        r.append(f"{std_name}+=( {' '.join(list(map(quote, std)))} )")

    for k in sorted(out.keys()):
        v = out[k]
        if len(v):
            r.append(f"{k}+=( {' '.join(list(map(quote, v)))} )")

    return r

def parse_argv(argv):
    """
    Parse argv and return bash output lines
    :param argv: the argv
    :return: the bash output lines

    >>> parse_argv([])
    Traceback (most recent call last):
    ValueError: No arguments separator given

    >>> parse_argv(['std_array'])
    Traceback (most recent call last):
    ValueError: No arguments separator given

    >>> parse_argv(['std_array', 'a'])
    Traceback (most recent call last):
    ValueError: No arguments separator given

    >>> parse_argv(["std_array", "a", "b", "--", "1", "2", "a.start", "a1", "a 2", "a.end"])
    ['std_array+=( 1 2 )', "a+=( a1 'a 2' )"]
    """
    names = []
    sep_found = False

    while len(argv):
        arg = argv.pop(0)

        if arg == "--":
            sep_found = True
            break

        names.append(arg)

    if not sep_found:
        raise ValueError("No arguments separator given")

    if not len(names):
        raise ValueError("No arguments given")

    return to_bash(names[0], names[1:], argv)

if __name__ == '__main__':
    args = sys.argv[1:]
    if len(args):
        for line in parse_argv(args):
            print(line)
    else:
        import doctest
        doctest.testmod()