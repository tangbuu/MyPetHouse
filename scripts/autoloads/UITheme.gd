extends Node

var button_theme: String = "brown"

func btn(name: String) -> Texture2D:
	return load("res://assets/UI/buttons/" + button_theme + "/" + name + ".png")
