extends RefCounted
# Original low-poly assets. All dimensions in metres; forward is -Z.
const SAND = Color("b77652")
const IVORY = Color("ded6c1")
const WHITE = Color("e8e3d8")
const DARK = Color("29343b")
const BLUE = Color("263c51")
const ORANGE = Color("ed9a54")
static var materials: Dictionary = {}
static func mat(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
 var key = str(color)+str(metallic)
 if not materials.has(key):
  var m = StandardMaterial3D.new()
  m.albedo_color=color;m.roughness=.86;m.metallic=metallic
  materials[key]=m
 return materials[key]
static func shape(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
 var n=MeshInstance3D.new();n.mesh=mesh;n.material_override=mat(color)
 parent.add_child(n);n.position=pos
 return n
static func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
 var m=BoxMesh.new();m.size=size
 return shape(parent,m,pos,color)
static func cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color, top: float = -1.0, seg: int = 12) -> MeshInstance3D:
 var m=CylinderMesh.new();m.bottom_radius=radius;m.top_radius=radius if top<0 else top;m.height=height;m.radial_segments=seg;m.rings=1
 return shape(parent,m,pos,color)
static func ball(parent: Node3D, radius: float, pos: Vector3, color: Color) -> MeshInstance3D:
 var m=SphereMesh.new();m.radius=radius;m.height=radius*2;m.radial_segments=12;m.rings=6
 return shape(parent,m,pos,color)
static func rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, color: Color) -> MeshInstance3D:
 var n=cylinder(parent,radius,a.distance_to(b),(a+b)/2,color,-1.0,6 if radius<.08 else 10)
 var up=(b-a).normalized()
 n.quaternion=Quaternion(Vector3.UP,up)
 return n
static func ring(parent: Node3D, radius: float, pos: Vector3, color: Color) -> MeshInstance3D:
 var m=TorusMesh.new();m.inner_radius=radius-.025;m.outer_radius=radius+.025;m.rings=32;m.ring_segments=6
 return shape(parent,m,pos,color)
const W := preload("res://scenes/b/world_art.gd")
static var _bevel_cache: Dictionary = {}
## Caja con las aristas biseladas (b = ancho del chaflán): atrapa el brillo en los bordes como una pieza metálica real.
static func bevel_mesh(size: Vector3, b: float) -> ArrayMesh:
 var key="%s_%s"%[size,b]
 if _bevel_cache.has(key):return _bevel_cache[key]
 var h=size/2.0
 var planos: Array[Plane]=[]
 for ax in range(3):
  for s in [-1.0,1.0]:
   var n=Vector3.ZERO;n[ax]=s
   planos.append(Plane(n,h[ax]))
 for a in range(3):
  for c in range(a+1,3):
   for s1 in [-1.0,1.0]:
    for s2 in [-1.0,1.0]:
     var n=Vector3.ZERO;n[a]=s1;n[c]=s2;n=n.normalized()
     planos.append(Plane(n,(h[a]+h[c]-b)/sqrt(2.0)))
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 W._add_polyhedron(st,planos,Vector3.ONE,Vector3.ZERO,false,RandomNumberGenerator.new())
 var mesh=st.commit()
 _bevel_cache[key]=mesh
 return mesh
static func rbox(parent: Node3D, size: Vector3, pos: Vector3, color: Color, b: float = .05) -> MeshInstance3D:
 return shape(parent,bevel_mesh(size,minf(b,minf(size.x,minf(size.y,size.z))*.45)),pos,color)
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
 var n=(c-a).cross(b-a).normalized()
 for p in [a,b,c]:
  st.set_normal(n);st.add_vertex(p)
## Parábola de revolución (antena): cara interior y cara posterior, abierta hacia +Y.
static func dish_mesh(radius: float, depth: float, segs: int = 16, rings: int = 4) -> ArrayMesh:
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var grosor=.035
 for s in range(segs):
  var a0=TAU*s/segs;var a1=TAU*(s+1)/segs
  for i in range(rings):
   var t0=float(i)/rings;var t1=float(i+1)/rings
   var p00=Vector3(cos(a0)*radius*t0,depth*t0*t0,sin(a0)*radius*t0)
   var p01=Vector3(cos(a1)*radius*t0,depth*t0*t0,sin(a1)*radius*t0)
   var p10=Vector3(cos(a0)*radius*t1,depth*t1*t1,sin(a0)*radius*t1)
   var p11=Vector3(cos(a1)*radius*t1,depth*t1*t1,sin(a1)*radius*t1)
   _tri(st,p00,p10,p01);_tri(st,p01,p10,p11)
   var d=Vector3(0,-grosor,0)
   _tri(st,p00+d,p01+d,p10+d);_tri(st,p01+d,p11+d,p10+d)
  var borde=Vector3(cos(a0)*radius,depth,sin(a0)*radius);var borde2=Vector3(cos(a1)*radius,depth,sin(a1)*radius)
  var d2=Vector3(0,-grosor,0)
  _tri(st,borde,borde2,borde+d2);_tri(st,borde2,borde2+d2,borde+d2)
 return st.commit()
static func panel(parent: Node3D, size: Vector3, pos: Vector3, filas: int, columnas: int) -> Node3D:
 var n=Node3D.new();n.set_meta("fusionable",true);parent.add_child(n);n.position=pos
 box(n,Vector3(size.x+.06,size.y,size.z+.06),Vector3.ZERO,Color("cfc8b8"))
 box(n,Vector3(size.x,size.y+.012,size.z),Vector3(0,.002,0),Color("27456f"))
 for c in range(1,columnas):
  box(n,Vector3(.012,size.y+.02,size.z),Vector3(-size.x/2+size.x*c/columnas,.003,0),Color("8d96a0"))
 for f in range(1,filas):
  box(n,Vector3(size.x,size.y+.02,.012),Vector3(0,.003,-size.z/2+size.z*f/filas),Color("8d96a0"))
 return n
static func rover(parent: Node3D) -> Dictionary:
 var v=Node3D.new();v.name="RoverVisual";parent.add_child(v)
 var gris=Color("5b6166")
 rbox(v,Vector3(1.5,.44,1.95),Vector3(0,.88,0),WHITE,.07)
 rbox(v,Vector3(1.28,.2,1.75),Vector3(0,.62,0),gris,.05)
 rbox(v,Vector3(1.38,.1,1.8),Vector3(0,1.14,.02),Color("3b434a"),.03)
 rbox(v,Vector3(1.54,.07,.2),Vector3(0,1.04,-.7),ORANGE,.025)
 rbox(v,Vector3(.9,.26,.5),Vector3(0,1.3,-.55),WHITE,.05)
 for side in [-1,1]:
  for k in range(3):box(v,Vector3(.03,.2,.07),Vector3(side*.76,.92,-.4+k*.2),Color("2b3238"))
  box(v,Vector3(.03,.1,.5),Vector3(side*.76,1.0,.55),Color("8d9399"))
  box(v,Vector3(.12,.1,.06),Vector3(side*.45,.9,-.985),DARK)
 var wheels=[]
 for side in [-1,1]:
  rod(v,Vector3(side*.6,.9,-.65),Vector3(side*.95,.5,-.8),.075,DARK)
  rod(v,Vector3(side*.6,.9,.6),Vector3(side*.95,.5,.7),.075,DARK)
  rod(v,Vector3(side*.94,.5,-.8),Vector3(side*.94,.5,.7),.055,Color("8f969b"))
  rod(v,Vector3(side*.6,.9,-.65),Vector3(side*.6,.9,.6),.04,Color("8f969b"))
  ball(v,.09,Vector3(side*.6,.9,-.65),Color("8f969b"));ball(v,.09,Vector3(side*.6,.9,.6),Color("8f969b"))
  for z in [-.8,0,.8]:
   var pivot=Node3D.new();v.add_child(pivot);pivot.position=Vector3(side*1.0,.45,z)
   var wheel=cylinder(pivot,.41,.3,Vector3.ZERO,Color("22272a"),-1.0,16);wheel.rotation.z=PI/2
   var rim=cylinder(pivot,.29,.34,Vector3.ZERO,Color("8a9196"),-1.0,10);rim.rotation.z=PI/2
   var hub=cylinder(pivot,.14,.38,Vector3.ZERO,Color("b3b8b9"),-1.0,8);hub.rotation.z=PI/2
   for angle in range(0,360,30):
    var tread=box(pivot,Vector3(.3,.045,.16),Vector3(0,sin(deg_to_rad(angle))*.415,cos(deg_to_rad(angle))*.415),Color("2a3033"))
    tread.rotation.x=-deg_to_rad(angle)
   for angle in range(0,360,90):
    var spoke=box(pivot,Vector3(.05,.03,.26),Vector3(side*.15,0,0),Color("8f969b"))
    spoke.rotation.x=-deg_to_rad(angle)
   wheels.append(pivot)
 rod(v,Vector3(.4,1.38,-.55),Vector3(.4,2.1,-.6),.055,IVORY)
 rod(v,Vector3(.4,1.38,-.55),Vector3(.4,1.62,-.55),.09,WHITE)
 var head=rbox(v,Vector3(.5,.3,.34),Vector3(.4,2.2,-.6),WHITE,.05)
 for x in [-.13,.13]:
  var lens=cylinder(head,.07,.08,Vector3(x,.0,-.2),DARK);lens.rotation.x=PI/2
  ball(head,.045,Vector3(x,0,-.245),Color("3a5a78"))
 box(head,Vector3(.2,.12,.2),Vector3(0,.2,0),Color("9aa0a3"))
 cylinder(head,.05,.1,Vector3(0,.3,0),DARK)
 rod(v,Vector3(.7,1.18,.9),Vector3(.7,2.05,.9),.016,DARK)
 var hga=Node3D.new();hga.name="HighGain";v.add_child(hga);hga.position=Vector3(-.58,1.3,.9)
 rod(hga,Vector3(0,-.12,0),Vector3(0,.22,0),.03,gris)
 var plato=shape(hga,dish_mesh(.24,.06,10,2),Vector3(0,.22,0),WHITE);plato.rotation_degrees=Vector3(-35,0,0)
 rod(hga,plato.position,plato.position+plato.basis*Vector3(0,.16,0),.01,DARK)
 var arm=Node3D.new();arm.name="ArmPivot";v.add_child(arm);arm.position=Vector3(.55,.95,-.8)
 cylinder(arm,.14,.14,Vector3.ZERO,gris)
 ball(arm,.08,Vector3(.15,-.25,-.55),IVORY)
 rod(arm,Vector3.ZERO,Vector3(.15,-.25,-.55),.07,IVORY)
 rod(arm,Vector3(.15,-.25,-.55),Vector3(.05,-.55,-.8),.06,ORANGE)
 var turret=cylinder(arm,.17,.16,Vector3(.05,-.62,-.82),gris);turret.rotation.x=PI/2
 var drill=cylinder(arm,.1,.38,Vector3(.05,-.7,-.82),DARK,.035)
 var solar=Node3D.new();solar.name="SolarPanels";v.add_child(solar)
 for fila in range(2):
  for col in range(2):
   var p=panel(solar,Vector3(.76,.04,.72),Vector3(-.4+col*.8,1.24+fila*.0,.18+fila*.74-.4),3,3)
   p.rotation_degrees.x=4
 for side in [-1,1]:
  rod(solar,Vector3(side*.6,1.14,-.1),Vector3(side*.6,1.23,-.1),.02,DARK)
  rod(solar,Vector3(side*.6,1.14,.85),Vector3(side*.6,1.23,.85),.02,DARK)
 var rtg=Node3D.new();rtg.name="RTG";v.add_child(rtg)
 rbox(rtg,Vector3(.5,.12,.7),Vector3(0,.88,1.25),gris,.03)
 var cuerpo=cylinder(rtg,.2,.8,Vector3(0,1.05,1.3),Color("797b79"));cuerpo.rotation.x=PI/2
 for z in range(7):
  var aleta=cylinder(rtg,.31,.025,Vector3(0,1.05,.96+z*.11),DARK,-1.0,10);aleta.rotation.x=PI/2
 var radar=box(v,Vector3(.7,.08,.5),Vector3(0,.48,.3),BLUE)
 var spectrometer=ball(arm,.15,Vector3(.15,-.6,-.9),Color("a0bcb4"))
 var meteo=rod(v,Vector3(-.65,1.18,.1),Vector3(-.65,1.95,.1),.025,IVORY)
 ring(v,.2,Vector3(-.65,1.8,.1),DARK)
 return {"visual":v,"wheels":wheels,"arm":arm,"solar":solar,"rtg":rtg,"drill":drill,"radar":radar,"spectrometer":spectrometer,"meteo":meteo,"head":head}
static func station(parent: Node3D) -> Array:
 cylinder(parent,2.5,.14,Vector3(0,.07,0),Color("85766c"))
 cylinder(parent,2.2,.2,Vector3(0,.1,0),Color("94847a"))
 for x in [-.8,.8]:
  box(parent,Vector3(.12,.5,.12),Vector3(x,.35,.1),IVORY)
 rbox(parent,Vector3(2.3,1.05,1.7),Vector3(0,.8,0),WHITE,.08)
 rbox(parent,Vector3(2.4,.1,1.8),Vector3(0,1.38,0),IVORY,.04)
 rbox(parent,Vector3(2.42,.06,.14),Vector3(0,1.37,.9),ORANGE,.02)
 rbox(parent,Vector3(.45,.75,.06),Vector3(-.55,.62,.87),DARK,.02)
 rbox(parent,Vector3(.9,.2,.05),Vector3(.55,.95,.87),Color("2c4a66"),.02)
 for k in range(4):box(parent,Vector3(.06,.26,.05),Vector3(.85+k*.1,.4,.87),Color("c8c2b4"))
 rbox(parent,Vector3(1.3,.85,1.15),Vector3(-2.0,.62,-.2),WHITE,.07)
 rbox(parent,Vector3(1.34,.08,1.19),Vector3(-2.0,1.08,-.2),IVORY,.03)
 var tubo=cylinder(parent,.22,.9,Vector3(-1.3,.6,-.2),Color("b8b2a4"));tubo.rotation.z=PI/2
 ball(parent,.55,Vector3(.2,1.5,-.3),WHITE).scale=Vector3(1,.5,1)
 rbox(parent,Vector3(.65,.5,.07),Vector3(0,1.05,-.9),BLUE,.02)
 for z in [-1.0,-.4]:
  var tanque=cylinder(parent,.27,1.0,Vector3(1.95,.4,z),Color("c3beb2"));tanque.rotation.z=PI/2
 rbox(parent,Vector3(.7,.45,.5),Vector3(1.5,.35,1.2),Color("a8a396"),.04)
 rbox(parent,Vector3(.7,.45,.5),Vector3(2.2,.35,1.2),Color("a8a396"),.04)
 for side in [-1,1]:
  panel(parent,Vector3(1.4,.07,1.5),Vector3(side*2.0,.6,.4),3,4)
  rod(parent,Vector3(side*.8,.4,.4),Vector3(side*2,.55,.4),.04,IVORY)
 # Torre de celosía con baliza
 for lx in [-1,1]:
  for lz in [-1,1]:
   rod(parent,Vector3(-2.9+lx*.22,.1,1.2+lz*.22),Vector3(-2.9+lx*.07,3.6,1.2+lz*.07),.03,IVORY)
 for k in range(7):
  var y=.4+k*.46;var s=.22-(.15*(y-.1)/3.5)
  rod(parent,Vector3(-2.9-s,y,1.2-s),Vector3(-2.9+s,y+.35,1.2-s),.015,IVORY)
  rod(parent,Vector3(-2.9+s,y,1.2+s),Vector3(-2.9-s,y+.35,1.2+s),.015,IVORY)
 ball(parent,.07,Vector3(-2.9,3.7,1.2),ORANGE)
 var levels=[]
 for level in range(1,4):
  var n=Node3D.new();n.name="AntennaLevel%d"%level;parent.add_child(n)
  antenna(n,level)
  levels.append(n)
 return levels
## Antena de la estación en tres niveles; cada mejora añade módulos nuevos y se nota a distancia.
## 1 = plato pequeño con receptor y látigo.
## 2 = plato mediano con horquilla y alimentador de trípode, plato de relé, armario amplificador y panel solar propio.
## 3 = plato de espacio profundo sobre pedestal giratorio con alimentador de cuatro patas, dos relés, búnker de
## comunicaciones, radomo, panel de matriz de fase, conductos y balizas.
static func antenna(n: Node3D, level: int) -> void:
 var gris=Color("5b6166");var claro=Color("9aa1a7");var teal=Color("9AD7C6");var base=Vector3(.6,1.43,.2)
 var cfg=[[.5,.18,1.55],[.8,.28,2.05],[1.1,.4,2.35]][level-1]
 var radio: float=cfg[0];var fondo: float=cfg[1];var altura: float=cfg[2]
 var eje=Vector3(1,0,-1).normalized()
 var tilt=Basis(eje,deg_to_rad(52.0))
 var centro=Vector3(base.x,base.y+altura,base.z)
 # --- Mástil, pedestal y plato principal
 cylinder(n,.16+level*.03,.1,base+Vector3(0,.05,0),gris)
 if level>=2:rbox(n,Vector3(.34+level*.08,.22,.34+level*.08),base+Vector3(0,.2,0),claro,.04)
 if level==3:
  cylinder(n,.34,.3,base+Vector3(0,.5,0),claro,-1.0,16)
  cylinder(n,.37,.05,base+Vector3(0,.67,0),ORANGE,-1.0,16)
 rod(n,base+Vector3(0,.3,0),centro-Vector3(0,.14,0),.035+level*.012,IVORY)
 var plato=shape(n,dish_mesh(radio,fondo,16,4),centro,IVORY);plato.basis=tilt
 var respaldo=cylinder(n,.08+level*.03,.12,centro+tilt*Vector3(0,-.11,0),gris,-1.0,8);respaldo.basis=tilt
 if level==3:
  # Aro naranja en el borde del plato (segmentos finos, el plato queda abierto)
  for k in range(16):
   var a0=TAU*k/16;var a1=TAU*(k+1)/16
   rod(n,centro+tilt*Vector3(cos(a0)*radio,fondo,sin(a0)*radio),centro+tilt*Vector3(cos(a1)*radio,fondo,sin(a1)*radio),.03,ORANGE)
 # --- Horquilla de elevación (2 y 3)
 if level>=2:
  var lado=tilt*Vector3(1,0,0);var cruce=Vector3(base.x,centro.y-.5,base.z)
  for sgn in [-1.0,1.0]:
   rod(n,cruce,centro+lado*sgn*(radio*.36)+tilt*Vector3(0,-.05,0),.03,gris)
 # --- Alimentador: poste (1), trípode (2), cuatro patas con subreflector (3)
 var focal=centro+tilt*Vector3(0,fondo+radio*.5,0)
 if level==1:rod(n,centro,focal,.02,DARK)
 else:
  var m=3 if level==2 else 4
  for k in range(m):
   var ang=TAU*k/m+PI/4
   rod(n,centro+tilt*Vector3(cos(ang)*radio*.96,fondo,sin(ang)*radio*.96),focal,.016,DARK)
 ball(n,.05+level*.018,focal,ORANGE if level<3 else Color("e4dfd2"))
 # --- Nivel 1: receptor y látigo en el techo
 if level==1:
  rbox(n,Vector3(.42,.2,.3),Vector3(-.8,1.53,.5),gris,.03)
  rod(n,Vector3(-.95,1.43,.5),Vector3(-.95,2.3,.5),.012,DARK)
  ball(n,.03,Vector3(-.95,2.3,.5),ORANGE)
 # --- Nivel 2 y 3: plato de relé, látigo, baliza
 if level>=2:
  var pol=Vector3(-.85,1.43,.5)
  rod(n,pol,pol+Vector3(0,.75,0),.025,IVORY)
  var rele=shape(n,dish_mesh(.28,.1,10,3),pol+Vector3(0,.78,0),IVORY);rele.basis=Basis(eje,deg_to_rad(58.0))
  rod(n,pol+Vector3(0,.78,0),pol+Vector3(0,.78,0)+rele.basis*Vector3(0,.22,0),.01,DARK)
  rod(n,Vector3(.95,1.43,-.55),Vector3(.95,2.4,-.55),.012,DARK)
  ball(n,.035,Vector3(.95,2.4,-.55),ORANGE)
 # --- Nivel 2: armario amplificador y panel solar propio en el suelo
 if level==2:
  rbox(n,Vector3(.7,.62,.42),Vector3(-.35,.51,1.8),Color("b9b4a6"),.04)
  for k in range(4):box(n,Vector3(.5,.03,.02),Vector3(-.35,.34+k*.1,2.02),DARK)
  ball(n,.035,Vector3(-.15,.76,2.02),teal)
  rod(n,Vector3(-.35,.82,1.8),Vector3(-.35,1.2,.95),.018,DARK)
  var solar=panel(n,Vector3(.9,.05,.6),Vector3(.95,.72,1.95),2,3);solar.rotation_degrees=Vector3(-28,0,0)
  rod(n,Vector3(.7,.2,1.95),Vector3(.7,.62,1.88),.03,IVORY)
  rod(n,Vector3(1.2,.2,1.95),Vector3(1.2,.62,1.88),.03,IVORY)
 # --- Nivel 3: segundo relé, búnker, radomo, matriz de fase, conductos y balizas
 if level==3:
  var pol2=Vector3(.95,1.43,.7)
  rod(n,pol2,pol2+Vector3(0,.7,0),.025,IVORY)
  var rele2=shape(n,dish_mesh(.24,.09,10,3),pol2+Vector3(0,.73,0),IVORY);rele2.basis=Basis(eje,deg_to_rad(60.0))
  rod(n,pol2+Vector3(0,.73,0),pol2+Vector3(0,.73,0)+rele2.basis*Vector3(0,.2,0),.01,DARK)
  # Búnker de comunicaciones
  rbox(n,Vector3(1.3,.64,.66),Vector3(-.5,.52,1.85),Color("c9c4b6"),.05)
  rbox(n,Vector3(1.34,.06,.7),Vector3(-.5,.86,1.85),IVORY,.02)
  box(n,Vector3(1.32,.05,.68),Vector3(-.5,.64,1.85),ORANGE)
  rbox(n,Vector3(.3,.46,.04),Vector3(-.15,.46,2.19),DARK,.015)
  for k in range(5):box(n,Vector3(.5,.025,.02),Vector3(-.78,.4+k*.08,2.19),DARK)
  for k in range(3):ball(n,.028,Vector3(-.95+k*.1,.78,2.19),teal)
  for k in range(3):cylinder(n,.05,.1,Vector3(-.95+k*.3,.94,1.7),gris)
  # Radomo sobre torre
  rod(n,Vector3(-1.75,.2,1.45),Vector3(-1.75,1.0,1.45),.07,gris)
  cylinder(n,.2,.08,Vector3(-1.75,1.02,1.45),claro,-1.0,12)
  ball(n,.5,Vector3(-1.75,1.5,1.45),Color("f1ede2"))
  cylinder(n,.505,.04,Vector3(-1.75,1.5,1.45),ORANGE,-1.0,16)
  ball(n,.045,Vector3(-1.75,2.04,1.45),Color("ff6b4f"))
  # Matriz de fase en el frente derecho
  rod(n,Vector3(1.1,.2,1.95),Vector3(1.1,.95,1.95),.05,IVORY)
  var matriz=Node3D.new();matriz.position=Vector3(1.1,1.3,1.95);matriz.rotation_degrees=Vector3(-12,0,0);n.add_child(matriz)
  rbox(matriz,Vector3(1.0,.7,.07),Vector3.ZERO,Color("d7d2c4"),.025)
  for fx in range(5):
   for fy in range(3):
    box(matriz,Vector3(.13,.13,.03),Vector3(-.4+fx*.2,-.22+fy*.22,.05),Color("27456f"))
  # Conductos hacia la estación y balizas
  rod(n,Vector3(-.5,.25,1.5),Vector3(-.4,.25,.95),.035,DARK)
  rod(n,Vector3(1.1,.25,1.9),Vector3(.5,.25,1.0),.035,DARK)
  rod(n,Vector3(-1.4,.25,1.45),Vector3(-1.1,.25,1.6),.035,DARK)
  rod(n,Vector3(.6,2.6,.2),Vector3(.6,3.0,.2),.012,DARK)
  ball(n,.05,Vector3(.6,3.0,.2),Color("ff6b4f"))
static func drone(parent: Node3D) -> Dictionary:
 var gris=Color("5b6166")
 var cuerpo=Color("e4dcc8")
 rbox(parent,Vector3(.36,.3,.34),Vector3.ZERO,cuerpo,.05)
 rbox(parent,Vector3(.38,.07,.36),Vector3(0,-.04,0),Color("c79a52"),.02)
 rbox(parent,Vector3(.3,.1,.28),Vector3(0,-.2,0),gris,.03)
 var lente=cylinder(parent,.05,.06,Vector3(0,-.27,-.06),DARK);lente.rotation.x=PI
 cylinder(parent,.05,.05,Vector3(0,.2,0),gris)
 panel(parent,Vector3(.7,.025,.46),Vector3(0,.3,0),2,4)
 for side in [-1,1]:
  for f in [-1,1]:
   var a=Vector3(side*.13,-.18,f*.12);var b=Vector3(side*.5,-.5,f*.38)
   rod(parent,a,b,.018,DARK)
   box(parent,Vector3(.13,.02,.07),b+Vector3(side*.03,-.01,0),DARK)
 rod(parent,Vector3(.12,.15,.1),Vector3(.12,.62,.1),.012,IVORY)
 rod(parent,Vector3(0,.32,0),Vector3(0,.42,0),.025,gris)
 var rotors=[]
 for k in range(2):
  var r=Node3D.new();parent.add_child(r);r.position=Vector3(0,.46+k*.12,0)
  cylinder(r,.045,.04,Vector3.ZERO,gris)
  box(r,Vector3(1.8,.012,.1),Vector3.ZERO,DARK)
  if k==1:r.rotation.y=PI/2
  rotors.append(r)
 return {"rotors":rotors}
static func companion(parent: Node3D) -> Dictionary:
 var verde=Color("5f8a8c")
 var body=rbox(parent,Vector3(.62,.36,.86),Vector3(0,.5,0),WHITE,.08)
 rbox(parent,Vector3(.64,.1,.6),Vector3(0,.4,.05),verde,.03)
 for side in [-1,1]:
  rbox(parent,Vector3(.16,.26,1.0),Vector3(side*.42,.28,0),Color("23282b"),.07)
  for z in [-.3,0,.3]:
   var rueda=cylinder(parent,.12,.18,Vector3(side*.42,.15,z),Color("3a4044"),-1.0,8);rueda.rotation.z=PI/2
   var eje=cylinder(parent,.05,.2,Vector3(side*.42,.15,z),Color("a9aeb0"),-1.0,6);eje.rotation.z=PI/2
 rbox(parent,Vector3(.4,.22,.34),Vector3(0,.78,-.12),WHITE,.06)
 box(parent,Vector3(.3,.1,.04),Vector3(0,.8,-.3),Color("2c4a66"))
 ball(parent,.05,Vector3(-.08,.8,-.325),Color("d9eef0"));ball(parent,.05,Vector3(.08,.8,-.325),Color("d9eef0"))
 rod(parent,Vector3(.14,.88,-.05),Vector3(.18,1.3,-.05),.016,DARK)
 ball(parent,.045,Vector3(.18,1.3,-.05),ORANGE)
 panel(parent,Vector3(.5,.03,.4),Vector3(0,.7,.28),2,3)
 rod(parent,Vector3(-.12,.62,-.4),Vector3(-.12,.5,-.7),.04,IVORY)
 rod(parent,Vector3(.12,.62,-.4),Vector3(.12,.5,-.7),.04,IVORY)
 box(parent,Vector3(.1,.05,.14),Vector3(-.14,.46,-.78),DARK);box(parent,Vector3(.1,.05,.14),Vector3(.14,.46,-.78),DARK)
 return {"body":body}
static func rock(parent: Node3D, pos: Vector3, scale_value: Vector3, color: Color) -> MeshInstance3D:
 var m=PrismMesh.new();m.size=Vector3.ONE
 var n=shape(parent,m,pos,color);n.scale=scale_value
 return n
static func dust(parent: Node3D, count: int, extent: Vector3) -> CPUParticles3D:
 var p=CPUParticles3D.new();p.emitting=false;p.amount=count;p.lifetime=2.5
 p.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX;p.emission_box_extents=extent
 p.direction=Vector3(1,.05,.2);p.spread=12;p.gravity=Vector3.ZERO
 p.initial_velocity_min=3;p.initial_velocity_max=6
 var mesh=SphereMesh.new();mesh.radius=.035;mesh.height=.07;mesh.radial_segments=4;mesh.rings=2
 p.mesh=mesh;p.color=Color("c9a784");parent.add_child(p)
 return p

# ---- Fusión de mallas (menos llamadas de dibujo): las piezas primitivas de un nodo pasan a una sola malla con
# color por vértice. Las piezas que se animan o se muestran/ocultan por separado se excluyen con `skip`.
static var _merged_material: StandardMaterial3D
static func merged_material() -> StandardMaterial3D:
 if _merged_material == null:
  _merged_material=StandardMaterial3D.new()
  _merged_material.vertex_color_use_as_albedo=true
  _merged_material.vertex_color_is_srgb=true
  _merged_material.roughness=.86
 return _merged_material
static func _collect(node: Node, xf: Transform3D, skip: Callable, out: Array, victims: Array) -> void:
 for c in node.get_children():
  if c is MeshInstance3D and (c.mesh is PrimitiveMesh or c.mesh is ArrayMesh):
   if skip.is_valid() and skip.call(c):continue
   out.append([c,xf*c.transform]);victims.append(c)
  elif c is Node3D and not (c is MeshInstance3D) and c.has_meta("fusionable"):
   # Grupo estático (panel solar): sus piezas se funden con las del padre y el grupo desaparece.
   _collect(c,xf*c.transform,skip,out,[])
   victims.append(c)
static func merged(parent: Node, skip: Callable = Callable()) -> void:
 if parent==null:return
 var verts=PackedVector3Array();var norms=PackedVector3Array();var cols=PackedColorArray();var idx=PackedInt32Array()
 var victims: Array=[];var piezas: Array=[]
 _collect(parent,Transform3D.IDENTITY,skip,piezas,victims)
 for par in piezas:
  var c: MeshInstance3D=par[0]
  var arrays: Array=c.mesh.get_mesh_arrays() if c.mesh is PrimitiveMesh else c.mesh.surface_get_arrays(0)
  var v: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var n: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
  var ind: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
  if ind.is_empty():
   for k in range(v.size()):ind.append(k)
  var col=Color.WHITE
  if c.material_override is StandardMaterial3D:col=c.material_override.albedo_color
  var xf: Transform3D=par[1]
  var nb: Basis=xf.basis.inverse().transposed()
  var base=verts.size()
  for k in range(v.size()):
   verts.append(xf*v[k]);norms.append((nb*n[k]).normalized());cols.append(col)
  for k in ind:idx.append(k+base)
 if piezas.is_empty():return
 var arr=[];arr.resize(Mesh.ARRAY_MAX)
 arr[Mesh.ARRAY_VERTEX]=verts;arr[Mesh.ARRAY_NORMAL]=norms;arr[Mesh.ARRAY_COLOR]=cols;arr[Mesh.ARRAY_INDEX]=idx
 var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr)
 var mi=MeshInstance3D.new();mi.name="Merged";mi.mesh=mesh;mi.material_override=merged_material()
 for c in victims:
  c.get_parent().remove_child(c);c.queue_free()
 parent.add_child(mi)
static func optimize_rover(r: Node) -> void:
 var vis=r.get_node("RoverVisual")
 for w in range(6):merged(vis.find_child("Wheel%d"%w,true,false))
 merged(vis.find_child("arm",true,false),func(c): return c.name in ["drill","spectrometer"])
 merged(vis.find_child("solar",true,false));merged(vis.find_child("rtg",true,false))
 merged(vis.find_child("head",true,false));merged(vis.find_child("HighGain",true,false))
 merged(vis,func(c): return c.name in ["head","radar","meteo"] or c.mesh is TorusMesh)
static func optimize_station(st: Node) -> void:
 for i in range(1,4):merged(st.get_node_or_null("AntennaLevel%d"%i))
 merged(st)
static func optimize_drone(d: Node) -> void:
 for i in range(2):merged(d.get_node_or_null("Rotor%d"%i))
 merged(d,func(c): return str(c.name).begins_with("Rotor"))
static func optimize_companion(c: Node) -> void:
 merged(c,func(m): return m.name=="Body")
