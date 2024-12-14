import * as vscode from 'vscode';
import fs from "fs";

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

		console.log(JSON.stringify(data));

        if (!response.ok) {
            throw new Error(`Status: ${response.status}`);
        }

        return (await response.json()) as Reflection.Output.generic;
    } catch (error) {
		vscode.window.showErrorMessage("fc2: error making request to client - " + error);
    }
}

let timeout: NodeJS.Timeout | undefined;
export function activate(context: vscode.ExtensionContext) {
	context.subscriptions.push(vscode.commands.registerCommand('fc2.execute', () => {
		const config = vscode.workspace.getConfiguration("fc2.reflection");

		const config_port: number | undefined = config.get("port");
		const config_pipe: boolean | undefined = config.get("pipe");
		const config_input: string | undefined = config.get("input");

		const editor = vscode.window.activeTextEditor;
		if (editor) {
			const fileName = editor.document.fileName;
			const fileContents = editor.document.getText();

			if (config_pipe) {
				if (!config_input || !fs.existsSync(config_input)) {
					vscode.window.showErrorMessage("fc2: cannot execute due to invalid reflection pipe (see fc2.reflection.input in settings)");
					return;
				}
	
				fs.writeFileSync(config_input, JSON.stringify([
					{
						command: "execute",
						name: fileName,
						source: fileContents
					}
				]));
	
				vscode.window.showInformationMessage('Executing to fc2 via pipe: ' + fileName);
			} else {
				if (!config_port) {
					vscode.window.showErrorMessage("fc2: cannot execute due to invalid port (see fc2.reflection.port in settings)");
					return;
				}

				http(config_port, {
					command: "execute",
					name: fileName,
					source: fileContents
				}).then((element) => {
					if (!element) {
						vscode.window.showErrorMessage("fc2: cannot execute - invalid response");
						return;
					}

					switch (element.command) {
						case "error":
							const error = element as Reflection.Output.error;
							vscode.window.showErrorMessage("fc2: ERROR - " + error.type + " - " + (error.reason || "unknown"));
							break;
						case "execute":
							const execute= element as Reflection.Output.execute;
							vscode.window.showInformationMessage("fc2: Execution successful - " + execute.name);
							break;
					}
				});
			}
		} else {
			vscode.window.showErrorMessage("fc2: you must be viewing a file currently to execute");
		}
	}));

	context.subscriptions.push(vscode.commands.registerCommand('fc2.reset', () => {
		const config = vscode.workspace.getConfiguration("fc2.reflection");
		const config_port: number | undefined = config.get("port");
		const config_pipe: boolean | undefined = config.get("pipe");
		const config_input: string | undefined = config.get("input");
		
		if (config_pipe) {
			if (!config_input || !fs.existsSync(config_input)) {
				vscode.window.showErrorMessage("fc2: cannot execute due to invalid reflection pipe (see fc2.reflection.input in settings)");
				return;
			}

			fs.writeFileSync(config_input, JSON.stringify([
				{
					command: "reset"
				}
			]));

			vscode.window.showInformationMessage('Reset fc2 runtimes via pipe');
		} else {
			if (!config_port) {
				vscode.window.showErrorMessage("fc2: cannot execute due to invalid port (see fc2.reflection.port in settings)");
				return;
			}

			http(config_port, {
				command: "reset"
			}).then((element) => {
				if (!element) {
					vscode.window.showErrorMessage("fc2: cannot execute - invalid response");
					return;
				}

				switch (element.command) {
					case "error":
						const error = element as Reflection.Output.error;
						vscode.window.showErrorMessage("fc2: ERROR - " + error.type + " - " + (error.reason || "unknown"));
						break;
					case "reset":
						vscode.window.showInformationMessage("fc2: Cleared runtimes");
						break;
				}
			});
		}
	}));

	timeout = setInterval(() => {
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

		response.forEach(element => {
			switch (element.command) {
				case "error":
					const error = element as Reflection.Output.error;
					vscode.window.showErrorMessage("fc2: ERROR - " + error.type + " - " + (error.reason || "unknown"));
					break;
				case "execute":
					const execute= element as Reflection.Output.execute;
					vscode.window.showErrorMessage("fc2: Execution successful - " + execute.name);
					break;
				case "reset":
					vscode.window.showErrorMessage("fc2: Cleared runtimes");
					break;
			}
		});
	}, 1000);
}

export function deactivate() {
	clearInterval(timeout);
}
