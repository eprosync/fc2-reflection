# FC2 - Reflection
A simple (and terrible) lua helper, to help you develop stuff.\
Because reloading all lua files is not an option for me - WholeCream

## Usage
We use the command pallete for running actions onto fc2.\
To do this simply <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>P</kbd> to open the pallete in command mode\
Doing <kbd>Ctrl</kbd> + <kbd>P</kbd> does the same thing, just missing <kbd>></kbd> before it

* `fc2: Execute` - Runs the current active file to fc2
* `fc2: Authenticate` - Reconnects & authenticates with fc2

## Modes
There are two modes: HTTP and PIPE\
`HTTP` [0] - uses on_http_request to handle information\
`PIPE` [1] - uses file-based operations to handle requests (yes this is horrible, I cry)\
Do note that we still try to red from output pipe for asyncronous actions done.

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
	export const version = 0x004;
	export let active: boolean = false;

	export interface script {
		author: string,
		core: string,
		elapsed: string,
		enabled: boolean,
		forums: string,
		id: number,
		last_bonus: string,
		last_update: number,
		library: string,
		name: string,
		script: string,
		software: number,
		team: string[],
		update_notes: string
	}

	export interface runtime {
		name: string,
		source: string,
		time: number,
		id: number
	}

	export interface config {
		[key: string]: {
			[key: string]: boolean | number | string
		}
	}

	export interface configs {
		solution: string,
		Constellation4?: config,
		Universe4?: config,
		Reflection?: config,
		[key: string]: config | undefined | string
	}

	export interface session {
		avatar: string,
		directory: string,
		fid: number,
		is_media: number,
		is_sdk: number,
		level: number,
		license: string,
		link: number,
		minimum_mode: number,
		os: string,
		posts: number,
		protection: number,
		score: number,
		server: string,
		superstar: number,
		uid: number,
		unlink: number,
		unread_alerts: number,
		unread_conversations: number,
		username: string,
	}

	export namespace Input {
		export type generic = {
			command: string,
			[key: string]: any
		}

		export interface version extends generic {}
		export interface session extends generic {}
		export interface reload extends generic {}

		export interface execute extends generic {
			name: string,
			source: string
		}
		export interface runtimes extends generic {}
		export interface runtimes_reset extends generic {}
		export interface runtime_kill extends generic {
			id: number
		}

		export interface scripts extends generic {}
		export interface script_toggle extends generic {
			id: number
		}

		export interface configs extends generic {}
		export interface config_update extends generic {
			solution: string,
			runtime: number,
			script: string,
			key: string,
			value: boolean | number | string,
			type: "boolean" | "number" | "string"
		}
	}

	export namespace Output {
		export interface generic {
			command: string,
			[key: string]: any
		}

		export interface error extends generic {
			name: string,
			type: string,
			reason: string
		}

		export interface version extends generic {
			version: number
		}
		export interface reload extends generic {
			script: string | boolean
		}
		export interface session extends generic, Reflection.session {}

		export interface execute extends generic {
			name: string
		}
		export interface runtimes extends generic {
			list: runtime[]
		}
		export interface runtime_kill extends generic {
			name?: string,
			id: number
		}
		export interface runtimes_reset extends generic {}

		export interface scripts extends generic {
			list: script[]
		}
		export interface script_toggle extends generic {
			id: number
		}

		export interface configs extends generic, Reflection.configs {}
		export interface config_update extends generic {
			solution: string,
			runtime: number,
			script: string,
			key: string,
			value: boolean | number | string,
			type: string
		}
	}
}
```