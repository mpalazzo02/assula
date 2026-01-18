#!/bin/bash

# Assula SketchyBar Plugin
# 
# This plugin displays the current Vim mode from Assula.
# 
# Installation:
# 1. Copy this file to ~/.config/sketchybar/plugins/assula.sh
# 2. Make it executable: chmod +x ~/.config/sketchybar/plugins/assula.sh
# 3. Add to your sketchybarrc:
#
#    sketchybar --add event assula_mode_change "app.assula.modeChanged"
#    sketchybar --add item assula left \
#               --set assula script="~/.config/sketchybar/plugins/assula.sh" \
#                           icon.drawing=off \
#                           label.font="JetBrainsMono Nerd Font:Bold:12.0" \
#                           background.color=0x44ffffff \
#                           background.corner_radius=4 \
#                           background.height=20 \
#                           padding_left=8 \
#                           padding_right=8 \
#               --subscribe assula assula_mode_change

# Get mode from environment variable (set by Assula trigger)
MODE=${MODE:-$INFO}

# Default to INSERT if no mode is set
if [ -z "$MODE" ]; then
    MODE="INSERT"
fi

# Colors (Catppuccin-inspired)
COLOR_NORMAL="0xff8aadf4"   # Blue
COLOR_INSERT="0xffa6da95"   # Green
COLOR_VISUAL="0xffeed49f"   # Yellow
COLOR_VISUAL_LINE="0xfff5a97f"  # Peach
COLOR_OPERATOR="0xffc6a0f6" # Mauve

case $MODE in
    "NORMAL")
        sketchybar --set assula label=" N " label.color=$COLOR_NORMAL
        ;;
    "INSERT")
        sketchybar --set assula label=" I " label.color=$COLOR_INSERT
        ;;
    "VISUAL")
        sketchybar --set assula label=" V " label.color=$COLOR_VISUAL
        ;;
    "VISUAL_LINE")
        sketchybar --set assula label="VL " label.color=$COLOR_VISUAL_LINE
        ;;
    "OPERATOR_PENDING")
        sketchybar --set assula label=" O " label.color=$COLOR_OPERATOR
        ;;
    *)
        sketchybar --set assula label=" ? " label.color="0xffffffff"
        ;;
esac
