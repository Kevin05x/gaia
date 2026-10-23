extends RefCounted
const INK=Color("15252f")
const MUTED=Color("9bacad")
const TEXT=Color("e8e4d6")
const ORANGE=Color("eaa36d")
const GREEN=Color("a4cdb6")
static func style(color: Color, radius: int=12, margin: int=16) -> StyleBoxFlat:
 var s=StyleBoxFlat.new();s.bg_color=color
 s.corner_radius_top_left=radius;s.corner_radius_top_right=radius;s.corner_radius_bottom_left=radius;s.corner_radius_bottom_right=radius
 s.content_margin_left=margin;s.content_margin_right=margin;s.content_margin_top=margin;s.content_margin_bottom=margin
 return s
static func theme() -> Theme:
 var t=Theme.new();t.default_font_size=16
 t.set_color("font_color","Label",TEXT)
 t.set_color("font_color","Button",TEXT)
 t.set_color("font_disabled_color","Button",Color("6a7b80"))
 t.set_stylebox("panel","PanelContainer",style(Color(.055,.105,.14,.96)))
 t.set_stylebox("normal","Button",style(Color("283b43"),7,10))
 t.set_stylebox("hover","Button",style(Color("415456"),7,10))
 t.set_stylebox("pressed","Button",style(Color("8a573b"),7,10))
 t.set_stylebox("disabled","Button",style(Color("1c2a32"),7,10))
 var focus=style(Color(0,0,0,0),7,10);focus.border_color=ORANGE
 focus.border_width_left=2;focus.border_width_right=2;focus.border_width_top=2;focus.border_width_bottom=2
 t.set_stylebox("focus","Button",focus)
 t.set_stylebox("background","ProgressBar",style(Color("33454a"),3,0))
 t.set_stylebox("fill","ProgressBar",style(GREEN,3,0))
 return t
static func label(parent: Node, text: String, size: int=16, color: Color=TEXT) -> Label:
 var n=Label.new();n.text=text;n.add_theme_font_size_override("font_size",size);n.add_theme_color_override("font_color",color);parent.add_child(n)
 return n
static func button(parent: Node,text: String,callback: Callable) -> Button:
 var n=Button.new();n.text=text;n.custom_minimum_size.y=40;parent.add_child(n);n.pressed.connect(callback)
 return n
static func panel(parent: Node) -> VBoxContainer:
 var p=PanelContainer.new();parent.add_child(p)
 var v=VBoxContainer.new();v.add_theme_constant_override("separation",9);p.add_child(v)
 return v
