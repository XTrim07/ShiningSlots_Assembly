#!/bin/bash
# build.sh - compile the game (like the other projects: gcc -no-pie)
cd ~/assembly_project/Slots
gcc -no-pie -o slots main.s -lSDL2 -Wall 2>&1
echo "exit: $?"
ls -l slots
