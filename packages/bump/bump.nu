#!/usr/bin/env nu

let metadata = nix flake metadata --json | from json;
let flake_inputs = $metadata.locks.nodes.root.inputs | transpose | get column0;

# A wrapper utility tool to update nix flake inputs
def main [...args: string] {
    nix flake update
}

def "main except" [...args: string] {
    echo "except: ($args)"
    let inputs = $flake_inputs | filter { |i| $i not-in $args }
    update $inputs
}

def "main selected" [...args: string] {
    update $args
}

def "main list" [] {
    let inputs = $flake_inputs | input list --multi 'select the inputs to update'
    update $inputs
}

def update [inputs: list<string>] {
    echo $"updating following inputs: ($inputs)"

    let args = $inputs | each { || prepend "--update-input" } | flatten
    nix flake lock $args
}
