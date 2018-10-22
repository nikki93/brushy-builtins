# brushy-builtins

This repository contains the Lua code that is automatically loaded by brushy. brushy uses [Love](https://love2d.org/) to provide a programmable 2d graphics, input and audio system (along with various other goodies). Love is built into the brushy app and loaded before the Lua code in this repository is loaded, so it has access to all of the Love libraries.

## Files

- `main.lua` -- The starting point of this code. The brushy app just loads this file, the rest of the code is loaded from here.
- `framework.lua` -- Implements the base painting system. This includes features such as undo, writing out the actual '.png' file when you export an image, and so on. Maintains a map of brushes by name and calls their `.paint(...)` etc. functions when appropriate. Communicates with the rest of the brushy app through Love [`Channel`](https://love2d.org/wiki/Channel)s.
- `brushes/*.lua` -- The brushes built into brushy.

- `uuid.lua` -- A [UUID](https://en.wikipedia.org/wiki/Universally_unique_identifier) library used by the rest of the code. Not really brushy-specific.
