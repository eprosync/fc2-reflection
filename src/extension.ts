import * as vscode from 'vscode';
import fs from "fs";

/*
    FC2 - Reflection
    A simple (and terrible) lua helper, to help you develop stuff.
    Because reloading all lua files is not an option for me - WholeCream
    Source: https://github.com/eprosync/fc2-reflection
*/

export namespace Reflection {
	export const version = 0x007;
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

	export interface perk {
		name: string,
		id: number,
		description: string,
		enabled: boolean
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
		export interface uplift extends generic {
			delay?: number
		}
		export interface reload extends generic {}

		export interface session extends generic {}
		export interface perks extends generic {}

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
		export interface uplift extends generic {
			delay: number,
			input: string,
			output: string
		}
		export interface reload extends generic {
			script: string | boolean
		}

		export interface session extends generic, Reflection.session {}
		export interface perks extends generic {
			list: perk[]
		}

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

async function http(port: number, data: {[index: string | number]: any}): Promise<Reflection.Output.generic | undefined> {
    const url = `http://localhost:${port}/luar?reflection=1`;

    try {
        const response = await fetch(url, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(data),
        });

        if (!response.ok) {
            throw new Error(`Status: ${response.status}`);
        }

        return (await response.json()) as Reflection.Output.generic;
    } catch (error) {
		
    }
}

const fc2Event: vscode.EventEmitter<Reflection.Output.generic> = new vscode.EventEmitter<Reflection.Output.generic>();

function fc2Handle(element: Reflection.Output.generic) {
    switch (element.command) {
        case "version":
            const version = element as Reflection.Output.version;
            if (version.version === Reflection.version) {
                vscode.window.showInformationMessage("fc2: You are connected!");
                Reflection.active = true;

				const config = vscode.workspace.getConfiguration("fc2.reflection");
				let config_interval: number | undefined = config.get("interval");
				if (config_interval !== undefined) {
					config_interval = config_interval / 1000;
				}

				fc2Command({
					command: "uplift",
					delay: config_interval
				});

				const config_output: string | undefined = config.get("output");
				if (!config_output || !fs.existsSync(config_output)) {
					vscode.window.showWarningMessage("fc2: WARNING - output pipe isn't setup correctly, runtime errors won't show!");
				}
            } else {
                vscode.window.showErrorMessage(`fc2: Version Deviation (Extension: ${Reflection.version}, Lua: ${version.version})\nPlease update to access fc2`);
                Reflection.active = false;
            }
            break;
		case "uplift":
			const uplift = element as Reflection.Output.uplift;
			const config = vscode.workspace.getConfiguration("fc2.reflection");
			config.update("input", uplift.input);
			config.update("output", uplift.output);
			
			fc2Command({
				command: "session"
			});

			fc2Command({
				command: "scripts"
			});

			fc2Command({
				command: "runtimes"
			});

			fc2Command({
				command: "configs"
			});
			break;
        case "error":
            const error = element as Reflection.Output.error;
            vscode.window.showErrorMessage("fc2: ERROR - " + error.type + " - " + (error.reason || "unknown"));
            break;
        case "execute":
            const execute = element as Reflection.Output.execute;
            vscode.window.showInformationMessage("fc2: Execution successful - " + execute.name);
			fc2Command({
				command: "runtimes"
			});

			fc2Command({
				command: "configs"
			});
            break;
		case "runtime_kill":
            const runtime_kill = element as Reflection.Output.runtime_kill;
			if (runtime_kill.name) {
				vscode.window.showInformationMessage(`fc2: Runtime '${runtime_kill.name}'#${runtime_kill.id} has been killed`);
				fc2Command({
					command: "runtimes"
				});

				fc2Command({
					command: "configs"
				});
			} else {
				vscode.window.showInformationMessage(`fc2: Runtime ${runtime_kill.id} doesn't exist`);
			}
			break;
        case "runtimes_reset":
            vscode.window.showInformationMessage("fc2: Runtimes have been killed");
			fc2Command({
				command: "runtimes"
			});

			fc2Command({
				command: "configs"
			});
            break;
        case "reload":
            const reload = element as Reflection.Output.reload;
            if (reload.script === true) {
                vscode.window.showInformationMessage(`fc2: Reloaded all scripts`);
            } else {
                vscode.window.showInformationMessage(`fc2: Reloaded script ${reload.script}`);
            }
            break;
		case "session":
			const session = element as Reflection.Output.session;
			vscode.window.showInformationMessage(`fc2: Hello ${session.username}!`);
			fc2Command({
				command: "perks"
			});
			break;
        case "script_toggle":
            const script_toggle = element as Reflection.Output.script_toggle;
            vscode.window.showInformationMessage(`fc2: Script #${script_toggle.id} has been toggled`);
            fc2Command({
                command: "scripts"
            });
            break;
		case "config_update":
			const config_update = element as Reflection.Output.config_update;
			vscode.window.showInformationMessage(`fc2: Script '${config_update.script}' config has been update`);
			fc2Command({
				command: "configs"
			});
			break;
    }

    fc2Event.fire(element);
}

let fc2_queue: Reflection.Input.generic[] = [];
let fc2_queue_timer: NodeJS.Timeout = setInterval(() => {}, 1000);
function fc2Command(data: Reflection.Input.generic): Promise<Reflection.Output.generic | undefined> {
	if (!Reflection.active && data.command !== "version") {
		vscode.window.showErrorMessage("fc2: we couldn't confirm our versions, if this persists please contact the developer.");
        return Promise.resolve(undefined);
	}

    const config = vscode.workspace.getConfiguration("fc2.reflection");
    const config_port: number | undefined = config.get("port");
    const config_pipe: boolean | undefined = config.get("pipe");
    const config_input: string | undefined = config.get("input");

    if (config_pipe) {
        if (!config_input || !fs.existsSync(config_input)) {
            vscode.window.showErrorMessage("fc2: cannot execute due to invalid input pipe (see fc2.reflection.input in settings)");
            return Promise.resolve(undefined);
        }

		let config_interval: number | undefined = config.get("interval");
		if (config_interval !== undefined) {
			config_interval = config_interval / 1000;
		}

		fc2_queue.push(data);
		clearInterval(fc2_queue_timer);
		setInterval(() => {
			const config = vscode.workspace.getConfiguration("fc2.reflection");
			const config_pipe: boolean | undefined = config.get("pipe");

			if (!config_pipe) {
				return;
			}

			const config_input: string | undefined = config.get("input");

			if (!config_input || !fs.existsSync(config_input)) {
				return;
			}

			if (fc2_queue.length === 0) {
				return;
			}

			if (fs.statSync(config_input).size > 1) {
				return;
			}

			fs.writeFileSync(config_input, JSON.stringify(fc2_queue));
			fc2_queue = [];
		}, config_interval);

        return Promise.resolve(undefined);
    } else {
        if (!config_port) {
            vscode.window.showErrorMessage("fc2: cannot execute due to invalid port (see fc2.reflection.port in settings)");
            return Promise.resolve(undefined);
        }

        return http(config_port, data)
            .then((element: Reflection.Output.generic | undefined) => {
                if (!element) {
                    vscode.window.showErrorMessage(`fc2: cannot execute command [${data.command}] - invalid response`);
                    return Promise.resolve(undefined);
                }

                if (element.command === "error") {
                    const error = element as Reflection.Output.error;
                    vscode.window.showErrorMessage("fc2: ERROR - " + error.type + " - " + (error.reason || "unknown"));
                    return Promise.resolve(undefined);
                }

				fc2Handle(element);

                return Promise.resolve(element);
            })
            .catch((error: any) => {
                vscode.window.showErrorMessage("fc2: HTTP request failed: " + (error.message || error));
                return Promise.reject(error);
            });
    }
}

class fc2GenericItem extends vscode.TreeItem {
	public readonly metadata?: any = undefined;
	public readonly command?: vscode.Command = undefined;
	public readonly clipboard?: string = undefined;
	public readonly entry?: any = undefined;

	constructor(
		public readonly label: string,
		public readonly collapsibleState: vscode.TreeItemCollapsibleState,
		options?: { contextValue?: string; command?: vscode.Command; entry?: any; metadata?: any, clipboard?: string, icon?: string }
	) {
		super(label, collapsibleState);
		if (options) {
			this.contextValue = options.contextValue;
			this.entry = options.entry;
			this.metadata = options.metadata;
			this.command = options.command;
			this.clipboard = options.clipboard;
			this.iconPath = options.icon ? new vscode.ThemeIcon(options.icon) : this.iconPath;
		}
	}
}

class fc2ScriptsItem extends fc2GenericItem {
	constructor(
		public readonly label: string,
		public readonly collapsibleState: vscode.TreeItemCollapsibleState,
		options?: { contextValue?: string; command?: vscode.Command; entry?: any; metadata?: any, clipboard?: string, icon?: string }
	) {
		super(label, collapsibleState, options);

		if (!this.clipboard && this.metadata && (this.metadata as Reflection.script).enabled) {
			this.iconPath = new vscode.ThemeIcon('pass');
		}
	}
}

class fc2ScriptsTree implements vscode.TreeDataProvider<fc2ScriptsItem> {
	private _onDidChangeTreeData: vscode.EventEmitter<fc2ScriptsItem | undefined | void> =
		new vscode.EventEmitter<fc2ScriptsItem | undefined | void>();
	readonly onDidChangeTreeData: vscode.Event<fc2ScriptsItem | undefined | void> =
		this._onDidChangeTreeData.event;

	private scriptData: Reflection.script[] = [];

	update(data: Reflection.script[]): void {
		this.scriptData = data;
		this._onDidChangeTreeData.fire();
	}

	getTreeItem(element: fc2ScriptsItem): vscode.TreeItem {
		return element;
	}

	getChildren(element?: fc2ScriptsItem): fc2ScriptsItem[] {
		if (!element) {
			if (this.scriptData.length === 0) {
				return [
					new fc2ScriptsItem(`Loading...`, vscode.TreeItemCollapsibleState.None, {
						contextValue: 'fc2Generic',
						icon: 'sync'
					})
				];
			}

			return this.scriptData.map(
				(entry) => {
					return new fc2ScriptsItem(entry.name, vscode.TreeItemCollapsibleState.Collapsed, {
						contextValue: 'fc2ScriptEntry',
						metadata: entry
					});
				}
			);
		}
	
		if (element.contextValue === 'fc2ScriptEntry' || element.contextValue === 'fc2ScriptModuleEntry') {
			const is_modules = element.contextValue === 'fc2ScriptModuleEntry';
			const metadata = element.metadata as Reflection.script;
			const modules: Reflection.script[] = [];
			
			if (!is_modules) {
				const requirePattern = /require\s*\(?\s*(["'])(.*?)\1\s*\)?/g;
				let match: RegExpExecArray | null;
				while ((match = requirePattern.exec(metadata.script)) !== null) {
					const moduleName = match[2];
					const actual = 'lib_' + moduleName + '.lua';

					this.scriptData.map(
						(entry) => {
							if (entry.name === actual) {
								modules.push(entry);
							}
						}
					);
				}
			}

			const items = [
				new fc2GenericItem(`author: ${metadata.author}`, vscode.TreeItemCollapsibleState.None, {
					contextValue: 'fc2Detail',
					clipboard: metadata.author
				}),
				new fc2GenericItem(`library: ${metadata.library === '1' ? 'Yes' : 'No'}`, vscode.TreeItemCollapsibleState.None, {
					contextValue: 'fc2Detail',
					clipboard: metadata.library === '1' ? 'Yes' : 'No'
				}),
				new fc2GenericItem(`elapsed: ${metadata.elapsed}`, vscode.TreeItemCollapsibleState.None, {
					contextValue: 'fc2Detail',
					clipboard: metadata.library === '1' ? 'Yes' : 'No'
				}),
				new fc2GenericItem(`forums: ${metadata.forums}`, vscode.TreeItemCollapsibleState.None, {
					contextValue: 'fc2Detail',
					clipboard: metadata.forums
				}),
				new fc2GenericItem(`notes: ${metadata.update_notes}`, vscode.TreeItemCollapsibleState.None, {
					contextValue: 'fc2Detail',
					clipboard: metadata.update_notes
				}),
				new fc2GenericItem(`id: ${metadata.id}`, vscode.TreeItemCollapsibleState.None, {
					contextValue: 'fc2Detail',
					clipboard: metadata.id.toString()
				}),
			];

			if (!is_modules) {
				if (modules.length > 0) {
					const names: string[] = [];
					
					modules.map(
						(entry) => {
							names.push(entry.name);
						}
					);

					items.splice(0, 0, new fc2GenericItem(`modules: ${names.join(', ')}`, vscode.TreeItemCollapsibleState.Collapsed, {
						contextValue: 'fc2ScriptModulesEntry',
						metadata: modules,
						clipboard: names.join(', ')
					}));
				} else {
					items.splice(0, 0, new fc2GenericItem(`modules: None`, vscode.TreeItemCollapsibleState.None, {
						contextValue: 'fc2Generic'
					}));
				}
			}

			return items;
		} else if (element.contextValue === "fc2ScriptModulesEntry") {
			const scripts: Reflection.script[] = element.metadata as Reflection.script[];
			return scripts.map(
				(entry) => {
					return new fc2ScriptsItem(entry.name, vscode.TreeItemCollapsibleState.Collapsed, {
						contextValue: 'fc2ScriptModuleEntry',
						metadata: entry
					});
				}
			);
		}

		return [];
	}

	getData(): Reflection.script[] {
		return this.scriptData;
	}
}

class fc2RuntimeTree implements vscode.TreeDataProvider<fc2GenericItem> {
	private _onDidChangeTreeData: vscode.EventEmitter<fc2GenericItem | undefined | void> =
		new vscode.EventEmitter<fc2GenericItem | undefined | void>();
	readonly onDidChangeTreeData: vscode.Event<fc2GenericItem | undefined | void> =
		this._onDidChangeTreeData.event;

	private runtimeData: Reflection.runtime[] = [];

	update(data: Reflection.runtime[]): void {
		this.runtimeData = data;
		this._onDidChangeTreeData.fire();
	}

	getTreeItem(element: fc2GenericItem): vscode.TreeItem {
		return element;
	}

	getChildren(element?: fc2GenericItem): fc2GenericItem[] {
		if (!element) {
			if (this.runtimeData.length === 0) {
				return [
					new fc2GenericItem(`No Runtimes...`, vscode.TreeItemCollapsibleState.None, {
						contextValue: 'fc2Generic',
						icon: 'sync'
					})
				];
			}

			return this.runtimeData.map(
				(entry) =>
				new fc2GenericItem(entry.name, vscode.TreeItemCollapsibleState.Collapsed, {
					contextValue: 'fc2RuntimeEntry',
					entry: entry,
					metadata: entry
				})
			);
		}
	
		const entry = element.entry;
		if (entry) {
			return [
				new fc2GenericItem(`name: ${entry.name}`, vscode.TreeItemCollapsibleState.None, {
					contextValue: 'fc2Detail',
					metadata: entry,
					clipboard: entry.name
				}),
				new fc2GenericItem(`time: ${entry.time}`, vscode.TreeItemCollapsibleState.None, {
					contextValue: 'fc2Detail',
					metadata: entry,
					clipboard: entry.time.toString()
				}),
				new fc2GenericItem(`id: ${entry.id}`, vscode.TreeItemCollapsibleState.None, {
					contextValue: 'fc2Detail',
					metadata: entry,
					clipboard: entry.id.toString()
				}),
			];
		}

		return [];
	}

	getData(): Reflection.runtime[] {
		return this.runtimeData;
	}
}

class fc2SessionTree implements vscode.TreeDataProvider<fc2GenericItem> {
	private _onDidChangeTreeData: vscode.EventEmitter<fc2GenericItem | undefined | void> =
		new vscode.EventEmitter<fc2GenericItem | undefined | void>();
	readonly onDidChangeTreeData: vscode.Event<fc2GenericItem | undefined | void> =
		this._onDidChangeTreeData.event;

	private sessionData: Reflection.session | undefined;
	private perkData: Reflection.perk[] | undefined;

	update(data: Reflection.session | undefined, perks?: Reflection.perk[]): void {
		this.sessionData = data;
		this.perkData = perks;
		this._onDidChangeTreeData.fire();
	}

	getTreeItem(element: fc2GenericItem): vscode.TreeItem {
		return element;
	}

	getChildren(element?: fc2GenericItem): fc2GenericItem[] {
		const session = this.sessionData;
		if (!session) {
			return [
				new fc2GenericItem(`Loading...`, vscode.TreeItemCollapsibleState.None, {
					contextValue: 'fc2Generic',
					icon: 'sync'
				})
			];
		}

		if (!element) {
			let protection = 'Unknown';
			switch (session.protection) {
				case 1: protection = "Standard"; break;
				case 2: protection = "Kernel"; break;
				case 3: protection = "Zombie"; break;
			}

			let ranks: string[] = [];
			if (session.is_sdk === 1) {
				ranks.push("SDK");
			}

			if (session.is_media === 1) {
				ranks.push("Media");
			}

			if (session.superstar === 1) {
				ranks.push("Superstar!");
			}
			
			return [
				new fc2GenericItem(`username: ${session.username} #${session.uid}`, vscode.TreeItemCollapsibleState.None, {
					contextValue: 'fc2Detail',
					clipboard: `${session.username} #${session.uid}`,
					icon: "account"
				}),
				new fc2GenericItem(`score: ${session.score}`, vscode.TreeItemCollapsibleState.None, {
					contextValue: 'fc2Detail',
					clipboard: session.score.toString(),
					icon: "fold-up"
				}),
				new fc2GenericItem(`ranks: ${ranks.join(" & ")}`, vscode.TreeItemCollapsibleState.None, {
					contextValue: 'fc2Detail',
					clipboard: ranks.join(" & "),
					icon: "star"
				}),
				new fc2GenericItem(`os: ${session.os}`, vscode.TreeItemCollapsibleState.None, {
					contextValue: 'fc2Detail',
					clipboard: session.os,
					icon: "home"
				}),
				new fc2GenericItem(`protection: ${protection}`, vscode.TreeItemCollapsibleState.None, {
					contextValue: 'fc2Detail',
					clipboard: protection,
					icon: "shield"
				}),
				new fc2GenericItem(`perks`, vscode.TreeItemCollapsibleState.Collapsed, {
					contextValue: 'fc2SessionPerksEntry',
					icon: "book"
				}),
			];
		} else if (element.contextValue === "fc2SessionPerksEntry") {
			if (!this.perkData) {
				return [
					new fc2GenericItem(`Loading...`, vscode.TreeItemCollapsibleState.None, {
						contextValue: 'fc2Generic',
						icon: 'sync'
					})
				];
			}

			return this.perkData.map(
				(entry) => {
					return new fc2GenericItem(`${entry.name}`, vscode.TreeItemCollapsibleState.Collapsed, {
						contextValue: 'fc2SessionPerkEntry',
						clipboard: entry.name,
						metadata: entry,
						icon: (entry.enabled ? "pass" : undefined)
					});
				}
			);
		} else if (element.contextValue === "fc2SessionPerkEntry" && element.metadata) {
			const perk = element.metadata as Reflection.perk;
			return [
				new fc2GenericItem(`description: ${perk.description}`, vscode.TreeItemCollapsibleState.None, {
					contextValue: 'fc2Detail',
					clipboard: perk.description
				}),
				new fc2GenericItem(`id: ${perk.id}`, vscode.TreeItemCollapsibleState.None, {
					contextValue: 'fc2Detail',
					clipboard: perk.id.toString()
				})
			];
		}

		return [];
	}

	getData(): Reflection.session | undefined {
		return this.sessionData;
	}

	getSession(): Reflection.session | undefined {
		return this.sessionData;
	}

	getPerks(): Reflection.perk[] | undefined {
		return this.perkData;
	}
}

class fc2CommandTree implements vscode.TreeDataProvider<fc2GenericItem> {
	private _onDidChangeTreeData: vscode.EventEmitter<fc2GenericItem | undefined | void> =
		new vscode.EventEmitter<fc2GenericItem | undefined | void>();
	readonly onDidChangeTreeData: vscode.Event<fc2GenericItem | undefined | void> =
		this._onDidChangeTreeData.event;

	getTreeItem(element: fc2GenericItem): vscode.TreeItem {
		return element;
	}

	getChildren(element?: fc2GenericItem): fc2GenericItem[] {
		if (!element) {
			return [
				new fc2GenericItem(`Execute File`, vscode.TreeItemCollapsibleState.None, {
					contextValue: 'fc2Command',
					icon: "play",
					command: {
						command: "fc2.execute",
						arguments: [],
						title: "Execute File"
					}
				}),
				new fc2GenericItem(`Kill Runtimes`, vscode.TreeItemCollapsibleState.None, {
					contextValue: 'fc2Command',
					icon: "trash",
					command: {
						command: "fc2.reset",
						arguments: [],
						title: "Kill Runtimes"
					}
				}),
				new fc2GenericItem(`Reload Scripts`, vscode.TreeItemCollapsibleState.None, {
					contextValue: 'fc2Command',
					icon: 'sync',
					command: {
						command: "fc2.reload",
						arguments: [],
						title: "Reload Scripts"
					}
				}),
				new fc2GenericItem(`Reconnect & Authenticate`, vscode.TreeItemCollapsibleState.None, {
					contextValue: 'fc2Command',
					icon: 'sync',
					command: {
						command: "fc2.auth",
						arguments: [],
						title: "Reconnect/Authentication"
					}
				}),
			];
		}

		return [];
	}

	getData(): undefined {
		return undefined;
	}
}

class fc2ConfigTree implements vscode.TreeDataProvider<fc2GenericItem> {
	private _onDidChangeTreeData: vscode.EventEmitter<fc2GenericItem | undefined | void> =
		new vscode.EventEmitter<fc2GenericItem | undefined | void>();
	readonly onDidChangeTreeData: vscode.Event<fc2GenericItem | undefined | void> =
		this._onDidChangeTreeData.event;

	private configData: Reflection.configs | undefined;

	update(data: Reflection.configs | undefined): void {
		this.configData = data;
		this._onDidChangeTreeData.fire();
	}

	getTreeItem(element: fc2GenericItem): vscode.TreeItem {
		return element;
	}

	getChildren(element?: fc2GenericItem): fc2GenericItem[] {
		if (!element) {
			if (!this.configData) {
				return [
					new fc2GenericItem(`Loading...`, vscode.TreeItemCollapsibleState.None, {
						contextValue: 'fc2Generic',
						icon: 'sync'
					})
				];
			}

			const solution = this.configData.solution;
			const configuration = this.configData[solution] as Reflection.config | undefined;
			const reflection = this.configData.Reflection as Reflection.config | undefined;
			const built: fc2GenericItem[] = [];

			if (configuration) {
				built.push(
					new fc2GenericItem(solution, vscode.TreeItemCollapsibleState.Collapsed, {
						contextValue: 'fc2ConfigEntry',
						entry: configuration,
						clipboard: solution
					})
				);
			}

			if (reflection) {
				built.push(
					new fc2GenericItem('Reflection', vscode.TreeItemCollapsibleState.Collapsed, {
						contextValue: 'fc2ConfigEntry',
						entry: reflection,
						clipboard: 'Reflection'
					})
				);
			}

			if (built.length === 0) {
				return [
					new fc2GenericItem(`No Configurations`, vscode.TreeItemCollapsibleState.None, {
						contextValue: 'fc2Generic',
						icon: 'sync'
					})
				];
			}

			return built;
		}

		if (element && this.configData) {
			const entry: {[index: string]: boolean | number | string} = element.entry;
			if (element.contextValue === "fc2ConfigEntry") { // File
				const configuration = element.entry as Reflection.config | undefined;
				const built: fc2GenericItem[] = [];

				for (let script in configuration) {
					let store = configuration[script];
					
					built.push(
						new fc2GenericItem(script, vscode.TreeItemCollapsibleState.Collapsed, {
							contextValue: 'fc2ConfigFileEntry',
							entry: store,
							metadata: script,
							clipboard: script
						})
					);
				}

				if (built.length === 0) {
					return [
						new fc2GenericItem(`No Configurations`, vscode.TreeItemCollapsibleState.None, {
							contextValue: 'fc2Generic',
							icon: 'sync'
						})
					];
				}
				
				return built;
			} else if (element.contextValue === "fc2ConfigFileEntry") { // Script Config
				const configuration = element.entry as {
					[key: string]: boolean | number | string
				};

				const identity = element.metadata as string;
				let name = identity;
				let id = 0;
				let solution = this.configData.solution;
				
				if (/#\d+$/.exec(identity)) {
					const id_ = identity.split("#"); // NOTE: if this becomes a problem I'll switch it to regex captures if I can
					name = id_[0];
					id = Number(id_[1]);
					solution = "Reflection";
				}

				const built: fc2GenericItem[] = [];
				for (let key in configuration) {
					let value = configuration[key];
					
					let metadata: Reflection.Output.config_update = {
						command: "config_update",
						solution: solution,
						script: name,
						type: typeof value,
						runtime: id,
						key: key,
						value: value
					};

					built.push(
						new fc2GenericItem(`${key} = ${value}`, vscode.TreeItemCollapsibleState.None, {
							contextValue: 'fc2ConfigDataEntry',
							entry: metadata,
							clipboard: `${key} = ${value}`
						})
					);
				}

				if (built.length === 0) {
					return [
						new fc2GenericItem(`No Configuration`, vscode.TreeItemCollapsibleState.None, {
							contextValue: 'fc2Generic',
							icon: 'sync'
						})
					];
				}

				return built;
			}
		}

		return [];
	}

	getData(): Reflection.configs | undefined {
		return this.configData;
	}
}

let timeout: NodeJS.Timeout | undefined;
export function activate(context: vscode.ExtensionContext) {
	context.subscriptions.push(
		vscode.commands.registerCommand('fc2.copy', (entry: fc2ScriptsItem) => {
			if (!entry.clipboard) {return;}
			vscode.env.clipboard.writeText(entry.clipboard);
			vscode.window.showInformationMessage(`fc2: Copied to clipboard - ${entry.clipboard}`);
		})
	);
	
	// Panel - Commands
	const fc2CommandProvider = new fc2CommandTree();
	vscode.window.registerTreeDataProvider('fc2-command', fc2CommandProvider);
	
	// Panel - Configs
	const fc2ConfigProvider = new fc2ConfigTree();
	vscode.window.registerTreeDataProvider('fc2-config', fc2ConfigProvider);

	context.subscriptions.push(
		vscode.commands.registerCommand('fc2.configs.update', async (entry: fc2GenericItem) => {
			const dataset = entry.entry as Reflection.Output.config_update | undefined;
			if (!dataset) {return;}

			if (dataset.type === "boolean") {
				if (dataset.value === true) {
					dataset.value = false;
				} else {
					dataset.value = true;
				}
				fc2Command(dataset);
				return;
			}
			
			const input = await vscode.window.showInputBox({
				prompt: `Change - ${entry.label} [type: ${dataset.type}]`,
				placeHolder: `${dataset.value}`
			});

			if (!input || input.length === 0) {
				vscode.window.showErrorMessage(`fc2: Invalid configuration input datatype ${dataset.type}`);
				return;
			}

			switch (dataset.type) {
				case 'number':
					const number = Number(input);
					if (isNaN(number) || input.trim() === '') {
						vscode.window.showErrorMessage(`fc2: Invalid input for type ${dataset.type}, should be a valid number`);
						return;
					}
					dataset.value = number;
					fc2Command(dataset);
					return;
				case 'string':
					dataset.value = input;
					fc2Command(dataset);
					return;
			}

			vscode.window.showErrorMessage(`fc2: Unknown configuration datatype ${dataset.type}`);
		})
	);

	fc2Event.event((element: Reflection.Output.generic) => {
		switch (element.command) {
			case "configs":
				const configs = element as Reflection.Output.configs;
				fc2ConfigProvider.update(configs);
				break;
		}
    });
	
	// Panel - Runtimes
	const fc2RuntimeProvider = new fc2RuntimeTree();
	vscode.window.registerTreeDataProvider('fc2-runtime', fc2RuntimeProvider);

	fc2Event.event((element: Reflection.Output.generic) => {
		switch (element.command) {
			case "runtimes":
				const runtimes = element as Reflection.Output.runtimes;
				fc2RuntimeProvider.update(runtimes.list);
				break;
		}
    });

	context.subscriptions.push(
		vscode.commands.registerCommand('fc2.runtimes.open', (entry: fc2GenericItem) => {
			const metadata = entry.metadata as (Reflection.runtime | undefined);
			if (!metadata) {return;}
			vscode.workspace.openTextDocument({
				language: "lua",
				content: metadata.source
			}).then(doc => {
				vscode.window.showInformationMessage(`fc2: Opened - ${metadata.name}`);
				vscode.window.showTextDocument(doc);
			}, error => {
				vscode.window.showInformationMessage(`fc2: Failed to open ${metadata.name} - ${error}`);
			});
		})
	);

	context.subscriptions.push(
		vscode.commands.registerCommand('fc2.runtimes.kill', (entry: fc2GenericItem) => {
			const metadata = entry.metadata as (Reflection.runtime | undefined);
			if (!metadata) {return;}
			fc2Command({
				command: "runtime_kill",
				id: metadata.id
			});
		})
	);

	// Panel - Session
	const fc2SessionProvider = new fc2SessionTree();
	vscode.window.registerTreeDataProvider('fc2-session', fc2SessionProvider);

	fc2Event.event((element: Reflection.Output.generic) => {
		switch (element.command) {
			case "session":
				const session = element as Reflection.Output.session;
				fc2SessionProvider.update(session);
				break;
			case "perks":
				const perks = element as Reflection.Output.perks;
				fc2SessionProvider.update(fc2SessionProvider.getSession(), perks.list);
				break;
		}
    });

	// Panel - Scripts
	const fc2ScriptsProvider = new fc2ScriptsTree();
	vscode.window.registerTreeDataProvider('fc2-script', fc2ScriptsProvider);

	fc2Event.event((element: Reflection.Output.generic) => {
		switch (element.command) {
			case "scripts":
				const scripts = element as Reflection.Output.scripts;
				fc2ScriptsProvider.update(scripts.list);
				break;
		}
    });

	context.subscriptions.push(
		vscode.commands.registerCommand('fc2.scripts.open', (entry: fc2ScriptsItem) => {
			const metadata = entry.metadata;
			if (!metadata) {return;}
			vscode.workspace.openTextDocument({
				language: "lua",
				content: metadata.script
			}).then(doc => {
				vscode.window.showInformationMessage(`fc2: Opened - ${metadata.name}`);
				vscode.window.showTextDocument(doc);
			}, error => {
				vscode.window.showInformationMessage(`fc2: Failed to open ${metadata.name} - ${error}`);
			});
		})
	);

	context.subscriptions.push(
		vscode.commands.registerCommand('fc2.scripts.toggle', (entry: fc2ScriptsItem) => {
			const metadata = entry.metadata;
			if (!metadata) {return;}
			fc2Command({
				command: "script_toggle",
				id: metadata.id
			});
		})
	);

	// Commands
	context.subscriptions.push(
		vscode.commands.registerCommand('fc2.auth', () => {
			fc2SessionProvider.update(undefined);
			fc2RuntimeProvider.update([]);
			fc2ScriptsProvider.update([]);
			fc2ConfigProvider.update(undefined);
			fc2Command({
				command: "version",
			}).catch((error) => {
				vscode.window.showInformationMessage(`fc2: Failed to communicate with reflection - ${error}`);
				Reflection.active = false;
			});
		})
	);

	context.subscriptions.push(
		vscode.commands.registerCommand('fc2.execute', () => {
			const editor = vscode.window.activeTextEditor;
			if (editor) {
				const fileName = editor.document.fileName;
				const fileContents = editor.document.getText();

				fc2Command({
					command: "execute",
					name: fileName,
					source: fileContents
				});
			} else {
				vscode.window.showErrorMessage("fc2: you must be viewing a file currently to execute");
			}
		})
	);

	context.subscriptions.push(
		vscode.commands.registerCommand('fc2.reload', () => {
			fc2Command({
				command: "reload",
				script: true
			});
		})
	);

	context.subscriptions.push(
		vscode.commands.registerCommand('fc2.runtimes.reset', () => {
			fc2Command({
				command: "runtimes_reset"
			});
		})
	);

	context.subscriptions.push(
		vscode.commands.registerCommand('fc2.scripts', () => {
			fc2ScriptsProvider.update([]);
			fc2Command({
				command: "scripts"
			});
		})
	);

	context.subscriptions.push(
		vscode.commands.registerCommand('fc2.runtimes', () => {
			fc2RuntimeProvider.update([]);
			fc2Command({
				command: "runtimes"
			});
		})
	);

	context.subscriptions.push(
		vscode.commands.registerCommand('fc2.configs', () => {
			fc2ConfigProvider.update(undefined);
			fc2Command({
				command: "configs"
			});
		})
	);

	context.subscriptions.push(
		vscode.commands.registerCommand('fc2.perks', () => {
			fc2SessionProvider.update(fc2SessionProvider.getSession(), undefined);
			fc2Command({
				command: "perks"
			});
		})
	);

	const config = vscode.workspace.getConfiguration("fc2.reflection");
	let config_interval: number | undefined = config.get("interval");
	if (config_interval !== undefined) {
		config_interval = config_interval / 1000;
	}

	const output_callback = () => {
		const config = vscode.workspace.getConfiguration("fc2.reflection");
		const config_output: string | undefined = config.get("output");
		
		if (!config_output || !fs.existsSync(config_output)) {
			return;
		}

		if (fs.statSync(config_output).size < 2) {
			return;
		}

		const data = fs.readFileSync(config_output);
		fs.writeFileSync(config_output, "");

		if (!data) {
			return;
		}

		let response: Reflection.Output.generic[];
		try {
			response = JSON.parse(data.toString());
		} catch(e) {
			return;
		}

		response.forEach(fc2Handle);
	};

	// Pipe API
	timeout = setInterval(output_callback, config_interval);
	vscode.workspace.onDidChangeConfiguration((event) => {
		if (event.affectsConfiguration("fc2.reflection.interval")) {
			clearInterval(timeout);
			timeout = setInterval(output_callback, config_interval);
		}
	});
	
	fc2Command({
		command: "version"
	}).catch((error) => {
		vscode.window.showInformationMessage(`fc2: Failed to communicate with reflection - ${error}`);
		Reflection.active = false;
	});
}

export function deactivate() {
	clearInterval(timeout);
}
