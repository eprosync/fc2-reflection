# FC2 - Reflection
A simple (and terrible) lua helper, to help you develop stuff.\
Because reloading all lua files is not an option for me - WholeCream

## Usage
We use the command pallete for running actions onto fc2.\
To do this simply <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>P</kbd> to open the pallete in command mode\
Doing <kbd>Ctrl</kbd> + <kbd>P</kbd> does the same thing, just missing <kbd>></kbd> before it

* `fc2.execute` - Runs the current active file to fc2
* `fc2.reset` - Removes all runtimes that was executed with reflection handlers

## Modes
There are two modes: HTTP and PIPE\
`HTTP` [0] - uses on_http_request to handle information\
`PIPE` [1] - uses file-based operations to handle requests (yes this is horrible, I cry)

## Configuration
By default we have reflection.lua set on HTTP.

* `fc2.reflection.pipe` - Changes mode to PIPE for file-based communication
* `fc2.reflection.port` - The port we would need to use if using HTTP mode
    * Universe4 - 9282
    * Constellation4 - 9283
* `fc2.reflection.input` - The input location if using PIPE mode
* `fc2.reflection.output` - The output location if using PIPE mode

## Interface
```ts
export namespace Reflection {
    export namespace Input {
        export type generic = {
            command: string
        }

        export interface execute extends generic {
            name: string,
            source: string
        }

        export interface reset extends generic {}
    }

    export namespace Output {
        export interface generic {
            command: string
        }

        export interface error extends generic {
            name: string,
            type: string,
            reason: string
        }

        export interface execute extends generic {
            name: string
        }

        export interface reset extends generic {}
    }
}
```

## What's Next
We have experimental additions for scripts/session information to be displayed later on.\
Right now we are very barebones for you to *regression hell* your sources.\
Have fun.