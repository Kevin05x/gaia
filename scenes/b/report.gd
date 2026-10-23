extends CanvasLayer
const UI=preload("res://scenes/b/ui_style.gd")
signal redesign_requested
var root: Control
var report: Dictionary={}
func _ready() -> void:
 layer=10
func show_report(data: Dictionary) -> void:
 report=data.duplicate(true);rebuild()
func rebuild() -> void:
 if is_instance_valid(root):remove_child(root);root.queue_free()
 root=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.theme=UI.theme();add_child(root)
 var bg=ColorRect.new();bg.color=Color(.025,.05,.07,.96);bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(bg)
 var margin=MarginContainer.new();root.add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,44)
 var scroll=ScrollContainer.new();margin.add_child(scroll)
 var col=VBoxContainer.new();col.size_flags_horizontal=Control.SIZE_EXPAND_FILL;col.add_theme_constant_override("separation",18);scroll.add_child(col)
 UI.label(col,"G A I A   /   "+tr("REPORT"),15,UI.ORANGE)
 UI.label(col,tr("WIN" if report.get("success",false) else "LOSE"),34)
 var stars=clampi(int(report.get("stars",0)),0,3)
 var star_view=preload("res://scenes/b/stars.gd").new();star_view.stars=stars;col.add_child(star_view)
 UI.label(col,tr("REPORT_STATS")%[report.get("sent",0),report.get("goal",100),report.get("sol",1)],18,UI.GREEN)
 var row=HBoxContainer.new();row.add_theme_constant_override("separation",32);col.add_child(row)
 var image_col=VBoxContainer.new();image_col.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(image_col)
 var texture=TextureRect.new();texture.custom_minimum_size=Vector2(380,240);texture.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 texture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;texture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 texture.texture=report.get("photo") if report.get("photo") is Texture2D else preload("res://scenes/b/assets/jezero.svg")
 image_col.add_child(texture)
 var credit=UI.label(image_col,str(report.get("photo_credit",tr("PHOTO_FALLBACK"))),12,UI.MUTED);credit.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 var source=str(report.get("photo_url",""))
 if source.begins_with("https://"):
  var link=LinkButton.new();link.text=tr("PHOTO_SOURCE");image_col.add_child(link);link.pressed.connect(func():OS.shell_open(source))
 var causes_col=VBoxContainer.new();causes_col.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(causes_col)
 UI.label(causes_col,tr("CAUSES"),12,UI.ORANGE)
 for entry in report.get("causes",[]):
  var text=tr(str(entry.get("key",""))) if entry is Dictionary else tr(str(entry))
  if entry is Dictionary and entry.has("values"):text=text%entry["values"]
  var cause=UI.label(causes_col,"• "+text,17);cause.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 UI.button(col,tr("REDESIGN"),func():redesign_requested.emit())
 var credits=UI.label(col,tr("CREDITS"),12,UI.MUTED);credits.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
func clear() -> void:
 if is_instance_valid(root):root.queue_free();root=null
 report.clear()
