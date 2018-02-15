'use strict';
// The module 'vscode' contains the VS Code extensibility API
// Import the module and reference it with the alias vscode in your code below
import * as vscode from 'vscode';
import * as net from 'net';
import * as path from 'path';

import { workspace, Disposable, ExtensionContext } from 'vscode';
import { LanguageClient, LanguageClientOptions, ServerOptions } from 'vscode-languageclient';

// this method is called when your extension is activated
// your extension is activated the very first time the command is executed
export function activate(context: ExtensionContext) {
    const executablExt = process.platform == 'win32' ? '.exe' : '';
	const executable = 'vls' + executablExt;
    const command = context.asAbsolutePath(executable);
    const serverOptions = { command };
    
    // Options to control the language client
    const clientOptions: LanguageClientOptions = {
        // Register the server for plain text documents
        documentSelector: ['volt'],
        synchronize: {
            // Synchronize the setting section 'languageServerExample' to the server
            configurationSection: 'volt',
            // Notify the server about file changes to '.clientrc files contain in the workspace
            fileEvents: workspace.createFileSystemWatcher('**/*.volt')
        }
    }
	
	// Create the language client and start the client.
	const disposable = new LanguageClient('Volt Language Server', serverOptions, clientOptions).start();
	
	// Push the disposable to the context's subscriptions so that the 
	// client can be deactivated on extension deactivation
    context.subscriptions.push(disposable);
}

// this method is called when your extension is deactivated
export function deactivate() {
}