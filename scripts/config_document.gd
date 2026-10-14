class_name ConfigDocument
extends RefCounted

# The workbench edits this document and nothing else.
# data is the combined view Balance already serves to the form.
# Saving splits it into a layout override and a balance override.

var data: Dictionary = {}


func pull() -> void:
	data = Balance.editor_state()


func save() -> void:
	Balance.save_editor_state(data)
	pull()


func reset() -> void:
	Balance.reset_editor_state()
	pull()
