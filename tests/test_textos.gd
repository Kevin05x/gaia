extends GutTest
## Todos los textos que el código pide con tr("CLAVE") existen en español e inglés, y las dos tablas tienen las mismas claves.

const Catalogo := preload("res://scenes/b/i18n/catalog.gd")
const TextosMenu := preload("res://scenes/menu/menu_text.gd")


func _archivos(carpeta: String, salida: Array[String]) -> void:
	for f in DirAccess.get_files_at(carpeta):
		if f.ends_with(".gd"):
			salida.append(carpeta.path_join(f))
	for d in DirAccess.get_directories_at(carpeta):
		if d != "tests" and d != "addons" and not d.begins_with("."):
			_archivos(carpeta.path_join(d), salida)


func test_las_dos_tablas_tienen_las_mismas_claves() -> void:
	var es: Dictionary = Catalogo.TABLES["es"]
	var en: Dictionary = Catalogo.TABLES["en"]
	for clave in es:
		assert_true(en.has(clave), "falta en inglés: %s" % clave)
	for clave in en:
		assert_true(es.has(clave), "falta en español: %s" % clave)


func test_el_menu_tiene_las_mismas_claves_en_los_dos_idiomas() -> void:
	for clave in TextosMenu.TABLES["es"]:
		assert_true(TextosMenu.TABLES["en"].has(clave), "falta en inglés (menú): %s" % clave)
	for clave in TextosMenu.TABLES["en"]:
		assert_true(TextosMenu.TABLES["es"].has(clave), "falta en español (menú): %s" % clave)


func test_cada_clave_usada_en_el_codigo_existe() -> void:
	var es: Dictionary = Catalogo.TABLES["es"].duplicate()
	es.merge(TextosMenu.TABLES["es"])
	var archivos: Array[String] = []
	_archivos("res://scenes", archivos)
	_archivos("res://sim", archivos)
	var regex := RegEx.new()
	regex.compile("\\btr\\(\"([A-Z][A-Z0-9_]+)\"\\)")
	var faltan := {}
	for ruta in archivos:
		var texto := FileAccess.get_file_as_string(ruta)
		for m in regex.search_all(texto):
			var clave := m.get_string(1)
			if not es.has(clave):
				faltan[clave] = ruta
	assert_eq(faltan.size(), 0, "claves sin texto: %s" % [faltan])


func test_los_motivos_de_rechazo_tienen_texto() -> void:
	var es: Dictionary = Catalogo.TABLES["es"]
	var regex := RegEx.new()
	regex.compile("(?:\"reason\": |return |motivo = )\"([A-Z][A-Z0-9_]+)\"")
	var faltan := {}
	var archivos: Array[String] = []
	_archivos("res://sim", archivos)
	for ruta in archivos:
		for m in regex.search_all(FileAccess.get_file_as_string(ruta)):
			var clave := m.get_string(1)
			if not es.has(clave) and clave != "OK" and not clave.ends_with("_"):
				faltan[clave] = ruta.get_file()
	assert_eq(faltan.size(), 0, "motivos sin texto: %s" % [faltan])


func test_los_nombres_de_edificios_y_modulos_tienen_texto() -> void:
	var es: Dictionary = Catalogo.TABLES["es"]
	var regex := RegEx.new()
	regex.compile("\"(?:nombre_clave|clave)\"\\s*:\\s*\"([A-Z][A-Z0-9_]+)\"")
	for ruta in ["res://content/economia.json", "res://content/combate.json", "res://content/historia.json", "res://content/tutorial.json"]:
		for m in regex.search_all(FileAccess.get_file_as_string(ruta)):
			assert_true(es.has(m.get_string(1)), "%s: falta el texto %s" % [ruta.get_file(), m.get_string(1)])
