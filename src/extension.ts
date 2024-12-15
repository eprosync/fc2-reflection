import * as vscode from 'vscode';
import fs from "fs";

export namespace Reflection {
	export const version = 0x001;
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

		export interface execute extends generic {
			name: string,
			source: string
		}
		export interface reset extends generic {}
		export interface reload extends generic {}

		export interface scripts extends generic {}
		export interface script_toggle extends generic {
			id: number
		}
	}

	export namespace Output {
		export interface generic {
			command: string,
			[key: string]: any
		}

		export interface version extends generic {
			version: number
		}
		
		export interface session extends generic, Reflection.session {}

		export interface error extends generic {
			name: string,
			type: string,
			reason: string
		}

		export interface execute extends generic {
			name: string
		}

		export interface reset extends generic {}

		export interface reload extends generic {
			script: string | boolean
		}

		export interface scripts extends generic {
			list: script[]
		}

		export interface script_toggle extends generic {
			id: number
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

// Create an EventEmitter to handle custom events
const fc2Event: vscode.EventEmitter<Reflection.Output.generic> = new vscode.EventEmitter<Reflection.Output.generic>();

function fc2Handle(element: Reflection.Output.generic) {
    switch (element.command) {
        case "version":
            const version = element as Reflection.Output.version;
            if (version.version === Reflection.version) {
                vscode.window.showInformationMessage("fc2: You are connected!");
                Reflection.active = true;

				fc2Command({
					command: "scripts"
				});

				fc2Command({
					command: "session"
				});
            } else {
                vscode.window.showErrorMessage(`fc2: Version Deviation (Extension: ${Reflection.version}, Lua: ${version.version})\nPlease update to access fc2`);
                Reflection.active = false;
            }
            break;
        case "error":
            const error = element as Reflection.Output.error;
            vscode.window.showErrorMessage("fc2: ERROR - " + error.type + " - " + (error.reason || "unknown"));
            break;
        case "execute":
            const execute = element as Reflection.Output.execute;
            vscode.window.showInformationMessage("fc2: Execution successful - " + execute.name);
            break;
        case "reset":
            vscode.window.showErrorMessage("fc2: Cleared runtimes");
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
			break;
        case "scripts":
            const scripts = element as Reflection.Output.scripts;
            vscode.window.showInformationMessage("fc2: Script database updated");
            break;
        case "script_toggle":
            const script_toggle = element as Reflection.Output.script_toggle;
            vscode.window.showInformationMessage(`fc2: Script #${script_toggle.id} has been toggled`);
            fc2Command({
                command: "scripts"
            });
            break;
    }

    fc2Event.fire(element);
}

let fc2_queue: Reflection.Input.generic[] = [];
let fc2_queue_timer: NodeJS.Timeout = setTimeout(() => {}, 0);
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
            vscode.window.showErrorMessage("fc2: cannot execute due to invalid reflection pipe (see fc2.reflection.input in settings)");
            return Promise.resolve(undefined);
        }

		fc2_queue.push(data);
		clearTimeout(fc2_queue_timer);
		setTimeout(() => {
			fs.writeFileSync(config_input, JSON.stringify(fc2_queue));
			fc2_queue = [];
		}, 500);

        vscode.window.showInformationMessage('fc2: Reloading fc2 scripts via pipe');
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

class fc2ScriptsItem extends vscode.TreeItem {
	public readonly metadata?: Reflection.script = undefined;
	public readonly command?: vscode.Command = undefined;
	public readonly clipboard?: string = undefined;

	constructor(
		public readonly label: string,
		public readonly collapsibleState: vscode.TreeItemCollapsibleState,
		public readonly entry?: Reflection.script,
		options?: { contextValue?: string; command?: vscode.Command; metadata?: Reflection.script, clipboard?: string, icon?: string }
	) {
		super(label, collapsibleState);
		if (options) {
			this.contextValue = options.contextValue;
			this.metadata = options.metadata;
			this.command = options.command;
			this.clipboard = options.clipboard;

			if (!this.clipboard) {
				this.iconPath = this.metadata?.enabled ? new vscode.ThemeIcon('pass') : undefined;
			}

			this.iconPath = options.icon ? new vscode.ThemeIcon(options.icon) : this.iconPath;
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
					new fc2ScriptsItem(`Loading...`, vscode.TreeItemCollapsibleState.None, undefined, {
						contextValue: 'fc2Detail',
						icon: "sync"
					})
				];
			}

			return this.scriptData.map(
				(entry) =>
				new fc2ScriptsItem(entry.name, vscode.TreeItemCollapsibleState.Collapsed, entry, {
					contextValue: 'fc2ScriptEntry',
					metadata: entry
				})
			);
		}
	
		const entry = element.entry;
		if (entry) {
			return [
				new fc2ScriptsItem(`author: ${entry.author}`, vscode.TreeItemCollapsibleState.None, entry, {
					contextValue: 'fc2Detail',
					metadata: entry,
					clipboard: entry.author
				}),
				new fc2ScriptsItem(`forums: ${entry.forums}`, vscode.TreeItemCollapsibleState.None, entry, {
					contextValue: 'fc2Detail',
					metadata: entry,
					clipboard: entry.forums
				}),
				new fc2ScriptsItem(`id: ${entry.id}`, vscode.TreeItemCollapsibleState.None, entry, {
					contextValue: 'fc2Detail',
					metadata: entry,
					clipboard: entry.id.toString()
				}),
			];
		}

		return [];
	}

	getData(): Reflection.script[] {
		return this.scriptData;
	}
}

class fc2SessionItem extends vscode.TreeItem {
	public readonly metadata?: Reflection.session = undefined;
	public readonly command?: vscode.Command = undefined;
	public readonly clipboard?: string = undefined;

	constructor(
		public readonly label: string,
		public readonly collapsibleState: vscode.TreeItemCollapsibleState,
		public readonly entry?: Reflection.session,
		options?: { contextValue?: string; command?: vscode.Command; metadata?: Reflection.session, clipboard?: string, icon?: string }
	) {
		super(label, collapsibleState);
		if (options) {
			this.contextValue = options.contextValue;
			this.metadata = options.metadata;
			this.command = options.command;
			this.clipboard = options.clipboard;
			this.iconPath = options.icon ? new vscode.ThemeIcon(options.icon) : undefined;
		}
	}
}

class fc2SessionTree implements vscode.TreeDataProvider<fc2SessionItem> {
	private _onDidChangeTreeData: vscode.EventEmitter<fc2SessionItem | undefined | void> =
		new vscode.EventEmitter<fc2SessionItem | undefined | void>();
	readonly onDidChangeTreeData: vscode.Event<fc2SessionItem | undefined | void> =
		this._onDidChangeTreeData.event;

	private sessionData: Reflection.session | undefined;

	update(data: Reflection.session): void {
		this.sessionData = data;
		this._onDidChangeTreeData.fire();
	}

	getTreeItem(element: fc2SessionItem): vscode.TreeItem {
		return element;
	}

	getChildren(element?: fc2SessionItem): fc2SessionItem[] {
		const session = this.sessionData;
		if (!session) {
			return [
				new fc2SessionItem(`Loading...`, vscode.TreeItemCollapsibleState.None, session, {
					contextValue: 'fc2Detail',
					icon: "sync"
				})
			];
		}

		if (!element) {
			return [
				new fc2SessionItem(`username: ${session.username}`, vscode.TreeItemCollapsibleState.None, session, {
					contextValue: 'fc2Detail',
					metadata: session,
					clipboard: session.username,
					icon: "account"
				}),
				new fc2SessionItem(`os: ${session.os}`, vscode.TreeItemCollapsibleState.None, session, {
					contextValue: 'fc2Detail',
					metadata: session,
					clipboard: session.os,
					icon: "home"
				}),
				new fc2SessionItem(`protection: ${session.protection}`, vscode.TreeItemCollapsibleState.None, session, {
					contextValue: 'fc2Detail',
					metadata: session,
					clipboard: session.protection.toString(),
					icon: "lock"
				}),
			];
		}

		return [];
	}

	getData(): Reflection.session | undefined {
		return this.sessionData;
	}
}

class fc2RuntimeItem extends vscode.TreeItem {
	public readonly metadata?: Reflection.session = undefined;
	public readonly command?: vscode.Command = undefined;
	public readonly clipboard?: string = undefined;

	constructor(
		public readonly label: string,
		public readonly collapsibleState: vscode.TreeItemCollapsibleState,
		options?: { contextValue?: string; command?: vscode.Command; metadata?: Reflection.session, clipboard?: string, icon?: string }
	) {
		super(label, collapsibleState);
		if (options) {
			this.contextValue = options.contextValue;
			this.metadata = options.metadata;
			this.command = options.command;
			this.clipboard = options.clipboard;
			this.iconPath = options.icon ? new vscode.ThemeIcon(options.icon) : undefined;
		}
	}
}

class fc2RuntimeTree implements vscode.TreeDataProvider<fc2RuntimeItem> {
	private _onDidChangeTreeData: vscode.EventEmitter<fc2RuntimeItem | undefined | void> =
		new vscode.EventEmitter<fc2RuntimeItem | undefined | void>();
	readonly onDidChangeTreeData: vscode.Event<fc2RuntimeItem | undefined | void> =
		this._onDidChangeTreeData.event;

	getTreeItem(element: fc2RuntimeItem): vscode.TreeItem {
		return element;
	}

	getChildren(element?: fc2RuntimeItem): fc2RuntimeItem[] {
		if (!element) {
			return [
				new fc2RuntimeItem(`Execute File`, vscode.TreeItemCollapsibleState.None, {
					contextValue: 'fc2Command',
					icon: "play",
					command: {
						command: "fc2.execute",
						arguments: [],
						title: "Execute"
					}
				}),
				new fc2RuntimeItem(`Clear Runtimes`, vscode.TreeItemCollapsibleState.None, {
					contextValue: 'fc2Command',
					icon: "play",
					command: {
						command: "fc2.reset",
						arguments: [],
						title: "Clear Runtimes"
					}
				}),
				new fc2RuntimeItem(`Reload Lua Files`, vscode.TreeItemCollapsibleState.None, {
					contextValue: 'fc2Command',
					icon: "play",
					command: {
						command: "fc2.reload",
						arguments: [],
						title: "Reload Lua Files"
					}
				})
			];
		}

		return [];
	}

	getData(): undefined {
		return undefined;
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
	// Panel - Runtimes
	const fc2RuntimeProvider = new fc2RuntimeTree();
	vscode.window.registerTreeDataProvider('fc2-runtime', fc2RuntimeProvider);

	// Panel - Session
	const fc2SessionProvider = new fc2SessionTree();
	vscode.window.registerTreeDataProvider('fc2-session', fc2SessionProvider);

	fc2Event.event((element: Reflection.Output.generic) => {
		switch (element.command) {
			case "session":
				const session = element as Reflection.Output.session;
				fc2SessionProvider.update(session);
				break;
		}
    });

	// Panel - Scripts
	const fc2ScriptsProvider = new fc2ScriptsTree();
	vscode.window.registerTreeDataProvider('fc2-scripts', fc2ScriptsProvider);

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

	fc2Event.event((element: Reflection.Output.generic) => {
		switch (element.command) {
			case "scripts":
				const scripts = element as Reflection.Output.scripts;
				fc2ScriptsProvider.update(scripts.list);
				break;
		}
    });

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
		vscode.commands.registerCommand('fc2.reset', () => {
			fc2Command({
				command: "reset",
				script: true
			});
		})
	);

	context.subscriptions.push(
		vscode.commands.registerCommand('fc2.scripts', () => {
			fc2Command({
				command: "scripts",
				script: true
			}).then((element) => {
				if (!element) {return;}
				switch (element.command) {
					case "scripts":
						const scripts = element as Reflection.Output.scripts;
						fc2ScriptsProvider.update(scripts.list);
						break;
				}
			});
		})
	);

	// Pipe API
	timeout = setInterval(() => {
		if (!Reflection.active) {return;}

		const config = vscode.workspace.getConfiguration("fc2.reflection");
		const config_pipe: boolean | undefined = config.get("pipe");

		if (!config_pipe) {return;}

		const config_output: string | undefined = config.get("output");
		
		if (!config_output || !fs.existsSync(config_output)) {
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
	}, 1000);
	
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
