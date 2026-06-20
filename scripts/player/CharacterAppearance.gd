@tool
class_name CharacterAppearance
extends Resource

# Original colors sampled from player_idle_sheet.png
const DEFAULT_HAIR_COLOR  := Color(0.353, 0.588, 0.824) # #5A96D2
const DEFAULT_SKIRT_COLOR := Color(0.196, 0.392, 0.706) # #3264B4

@export var hair_color  : Color = DEFAULT_HAIR_COLOR
@export var skirt_color : Color = DEFAULT_SKIRT_COLOR

# How tightly the shader matches pixels to the source color.
# Lower = only exact matches replaced (safer). Higher = more area covered.
@export_range(0.0, 0.5, 0.01) var threshold : float = 0.12
