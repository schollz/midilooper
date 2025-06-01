# midilooper

## usage

- k2: toggle playback
- k3: toggle recording
- k1+k2: erase
- k1+k3: quantize
- e1: change loop

## formatting

```
lua-format -i --indent-width=2 --column-limit=120 --no-keep-simple-function-one-line --no-spaces-around-equals-in-field --no-spaces-inside-table-braces --no-spaces-inside-functiondef-parens lib/looper.lua && lua-format -i --indent-width=2 --column-limit=120 --no-keep-simple-function-one-line --no-spaces-around-equals-in-field --no-spaces-inside-table-braces --no-spaces-inside-functiondef-parens midilooper.lua
```
