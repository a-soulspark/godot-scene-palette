@tool
extends Control

@export var subpalette_scene:PackedScene
@export var scene_drop_scene:PackedScene
@export var fav_button_scene:PackedScene
#@onready var subpalette_container = %SubPaletteContainer # TODO can delete
@onready var file_dialog = %FileDialog
@onready var choose_directory_button = %ChooseDirectoryButton
var top_level_sub_palette:PalettePluginSubPalette
@onready var favorites_bar = %FavoritesBar
@onready var save_dir_to_favorites = %SaveDirToFavorites
@onready var favorites_settings = %FavoritesSettings
@onready var instantiate_for_preview_button = %UsePreviewCheckButton
@onready var scroll_container = %ScrollContainer
@onready var settings_container = %SettingsContainer

const save_data_dir = "res://addons/scene_palette/save_data/"
const save_data_path = save_data_dir + "save_data.tres"

var pp = 'ScenePalettePlugin: '

var _current_dir:
	set(value):
		_current_dir = value
		
		# clear visible pallets
		for child in scroll_container.get_children():
			child.queue_free()
		
		# create new top level palette
		top_level_sub_palette = subpalette_scene.instantiate()
		scroll_container.add_child(top_level_sub_palette)
		var palette_title = _current_dir.split('/')[-1]
		top_level_sub_palette.set_title(palette_title)
		top_level_sub_palette.expandable = false
		
		# if we are navigating to a favorite, load any saved settings for it
		var toggle_on:bool = false
		if _current_dir_in_favorites():
			var save_data:PalettePluginSaveData = _get_save_data()
			top_level_sub_palette.set_color(save_data.favorites[_current_dir].color)
			toggle_on = save_data.favorites[_current_dir].instantiate_scenes_for_previews 
		
		instantiate_for_preview_button.button_pressed = toggle_on
		_populate_scenes(top_level_sub_palette, value)


## Recursively create subpalettes for the specified directory
func _populate_scenes(sub_palette:PalettePluginSubPalette, dir_path:String):
	var dir = DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				var new_sub_palette:PalettePluginSubPalette = subpalette_scene.instantiate()
				#subpalette_container.add_child(new_sub_palette)
				sub_palette.add_subpalette(new_sub_palette)
				new_sub_palette.set_title(file_name)
				_populate_scenes(new_sub_palette, dir_path + '/' + file_name)
			else:
				if file_name.split('.')[-1] == 'tscn':
					var scene_drop:PalettePluginSceneDrop = scene_drop_scene.instantiate()
					sub_palette.add_item(scene_drop)
					scene_drop.instantiate_scene_preview = instantiate_for_preview_button.button_pressed
					scene_drop.set_scene(dir_path +'/' + file_name)
			file_name = dir.get_next()
	else:
		print(pp, 'No directory found for ', dir_path)

func _ready():
	save_dir_to_favorites.hide()
	settings_container.hide()
	_populate_favorites_tab_bar()
	if not FileAccess.file_exists(save_data_path):
		_create_new_save_data()

func _create_new_save_data():
	var data = PalettePluginSaveData.new()
	ResourceSaver.save(data, save_data_path)

func _get_save_data() -> PalettePluginSaveData:
	if not FileAccess.file_exists(save_data_path):
		# This only happens if a user manually deletes the save_data while the plugin is enabled
		print(pp, 'favorites data was removed. Creating new save data.')
		_create_new_save_data()
		_populate_favorites_tab_bar()
	return ResourceLoader.load(save_data_path)

func _save_data(data:PalettePluginSaveData):
	ResourceSaver.save(data, save_data_path)

func _on_choose_directory_button_pressed():
	file_dialog.show()

func _on_file_dialog_dir_selected(dir):
	_current_dir = dir
	choose_directory_button.text = dir #.split('/')[-1]
	if not _current_dir_in_favorites():
		save_dir_to_favorites.show()
	else:
		save_dir_to_favorites.hide()

func _on_use_preview_check_button_toggled(toggled_on):
	top_level_sub_palette.instantiate_previews(toggled_on)
	if _current_dir_in_favorites():
		var save_data = _get_save_data()
		save_data.favorites[_current_dir].instantiate_scenes_for_previews = toggled_on
		_save_data(save_data)

## Load favorites buttons
func _populate_favorites_tab_bar():
	var data:PalettePluginSaveData = _get_save_data()
	
	# clear existing buttons
	for child in favorites_bar.get_children():
		child.queue_free()
	# add new buttons
	for dir in data.favorites:
		var btn:PalettePluginFavoriteButton = fav_button_scene.instantiate()
		btn.favorite_selected.connect(_on_new_favorite_selected)
		btn.favorite_removed.connect(_on_favorite_removed)
		btn.favorite_color_changed.connect(_on_favorite_color_changed)
		favorites_bar.add_child(btn)
		btn.directory = dir
		btn.set_color(data.favorites[dir].color)
		btn.set_settings_visibility(favorites_settings.button_pressed)

func _on_new_favorite_selected(dir:String):
	_on_file_dialog_dir_selected(dir)

func _on_favorite_removed(dir:String):
	var save_data:PalettePluginSaveData = _get_save_data()
	save_data.favorites.erase(dir)
	_save_data(save_data)
	_populate_favorites_tab_bar()
	
	# show button to add to favorite again if we removed the current dir
	if dir == _current_dir:
		save_dir_to_favorites.show()

func _on_favorite_color_changed(dir:String, color:Color):
	var save_data:PalettePluginSaveData = _get_save_data()
	save_data.favorites[dir].color = color
	_save_data(save_data)

func _on_save_dir_to_favorites_pressed():
	var save_data:PalettePluginSaveData = _get_save_data()
	
	if _current_dir_in_favorites():
			print(pp, _current_dir, ' is already in favorites')
	else:
		save_data.add_favorite(_current_dir, instantiate_for_preview_button.button_pressed)
		_save_data(save_data)
		_populate_favorites_tab_bar()
		save_dir_to_favorites.hide()

func _current_dir_in_favorites() -> bool:
	var save_data:PalettePluginSaveData = _get_save_data()
	return _current_dir in save_data.favorites


## toggle visibility of configuration options
func _on_favorites_settings_toggled(toggled_on):
	for btn in favorites_bar.get_children():
		if btn is PalettePluginFavoriteButton:
			btn.set_settings_visibility(toggled_on)
	settings_container.visible = toggled_on


func _on_show_scene_label_button_toggled(toggled_on):
	pass # Replace with function body.
