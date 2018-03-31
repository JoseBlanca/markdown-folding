# markdown-folding package

It folds and unfolds markdown sections following the headers.

This package is inspired by the package [markdown-foler](https://github.com/tshort/markdown-folder), but unfortunately after Atom 1.9.0 that package [stop working](https://github.com/tshort/markdown-folder/issues/19) and I reimplemented some of its functionality.

Commands:
1. 'markdown-folding:cycle': => Cycle heading at cursor (Show headings of subsections - collapse all - show all)
2. 'markdown-folding:foldall-h1': => Fold all h1 headings
3. 'markdown-folding:foldall-h2': => Fold all h2 headings

Suggested bindings (not implemented, use in your personal settings if you like):
```
'atom-text-editor[data-grammar="source gfm"]:not([mini])':
  'tab':        'markdown-folding:cycle'
```
