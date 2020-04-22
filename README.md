# Evtx-To-MalwLess

Evtx-To-Malwless is a PowerShell script that allows you to convert .evtx events to a [MalwLess](https://github.com/n0dec/MalwLess) configuration file.

This allows other people to use intrustion detection logs to test their defenses without having to manually write the MalwLess configuration.

## Usage

`.\Evtx-To-MalwLess.ps1 -EventFile C:\path\to\events.evtx -OutputFile C:\path\to\output.json`
