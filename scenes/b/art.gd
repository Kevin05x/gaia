extends RefCounted
# Original low-poly assets. All dimensions in metres; forward is -Z.
const SAND = Color("b77652")
const IVORY = Color("ded6c1")
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
static func cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color, top: float = -1.0) -> MeshInstance3D:
 var m=CylinderMesh.new();m.bottom_radius=radius;m.top_radius=radius if top<0 else top;m.height=height;m.radial_segments=12
 return shape(parent,m,pos,color)
static func ball(parent: Node3D, radius: float, pos: Vector3, color: Color) -> MeshInstance3D:
 var m=SphereMesh.new();m.radius=radius;m.height=radius*2;m.radial_segments=12;m.rings=6
 return shape(parent,m,pos,color)
static func rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, color: Color) -> MeshInstance3D:
 var n=cylinder(parent,radius,a.distance_to(b),(a+b)/2,color)
 var up=(b-a).normalized()
 n.quaternion=Quaternion(Vector3.UP,up)
 return n
static func ring(parent: Node3D, radius: float, pos: Vector3, color: Color) -> MeshInstance3D:
 var m=TorusMesh.new();m.inner_radius=radius-.025;m.outer_radius=radius+.025;m.rings=32;m.ring_segments=6
 return shape(parent,m,pos,color)
static func rover(parent: Node3D) -> Dictionary:
 var v=Node3D.new();v.name="RoverVisual";parent.add_child(v)
 box(v,Vector3(1.5,.4,1.9),Vector3(0,.85,0),IVORY)
 box(v,Vector3(1.2,.12,1.6),Vector3(0,1.11,0),Color("c6a67e"))
 box(v,Vector3(.85,.25,.8),Vector3(0,1.25,.1),IVORY)
 box(v,Vector3(1.52,.08,.22),Vector3(0,.9,-.65),ORANGE)
 var wheels=[]
 for side in [-1,1]:
  rod(v,Vector3(side*.6,.9,-.65),Vector3(side*.95,.48,-.8),.065,DARK)
  rod(v,Vector3(side*.6,.9,.6),Vector3(side*.95,.48,.7),.065,DARK)
  rod(v,Vector3(side*.94,.5,-.8),Vector3(side*.94,.5,.7),.05,DARK)
  for z in [-.8,0,.8]:
   var pivot=Node3D.new();v.add_child(pivot);pivot.position=Vector3(side*.98,.4,z)
   var wheel=cylinder(pivot,.36,.25,Vector3.ZERO,DARK);wheel.rotation.z=PI/2
   var hub=cylinder(pivot,.14,.27,Vector3.ZERO,IVORY);hub.rotation.z=PI/2
   for angle in range(0,360,60):
    var tread=box(pivot,Vector3(.28,.05,.14),Vector3(0,sin(deg_to_rad(angle))*.35,cos(deg_to_rad(angle))*.35),Color("465052"))
    tread.rotation.x=-deg_to_rad(angle)
   wheels.append(pivot)
 rod(v,Vector3(-.3,1.2,-.5),Vector3(-.3,2.05,-.55),.065,IVORY)
 var head=box(v,Vector3(.65,.25,.25),Vector3(-.3,2.1,-.55),IVORY)
 for x in [-.48,-.16]:
  var lens=cylinder(v,.075,.08,Vector3(x,2.1,-.72),DARK);lens.rotation.x=PI/2
 var arm=Node3D.new();arm.name="ArmPivot";v.add_child(arm);arm.position=Vector3(.55,.95,-.8)
 rod(arm,Vector3.ZERO,Vector3(.15,-.25,-.55),.07,IVORY)
 rod(arm,Vector3(.15,-.25,-.55),Vector3(.05,-.55,-.8),.06,ORANGE)
 var drill=cylinder(arm,.12,.35,Vector3(.05,-.65,-.8),DARK,.04)
 var solar=Node3D.new();solar.name="SolarPanels";v.add_child(solar)
 for side in [-1,1]:
  box(solar,Vector3(.85,.045,1.5),Vector3(side*1.05,1.25,.2),BLUE)
  for z in range(5): box(solar,Vector3(.85,.008,.015),Vector3(side*1.05,1.28,-.5+z*.35),IVORY)
  rod(solar,Vector3(side*.5,1.1,.5),Vector3(side*1.1,1.22,.5),.025,DARK)
 var rtg=Node3D.new();rtg.name="RTG";v.add_child(rtg)
 cylinder(rtg,.25,.7,Vector3(.1,1.1,1.15),Color("797b79"))
 for y in range(7): cylinder(rtg,.36,.025,Vector3(.1,.8+y*.1,1.15),DARK)
 var radar=box(v,Vector3(.7,.08,.5),Vector3(0,.56,.3),BLUE)
 var spectrometer=ball(arm,.17,Vector3(.05,-.55,-.8),Color("a0bcb4"))
 var meteo=rod(v,Vector3(.5,1.2,.5),Vector3(.5,1.9,.5),.025,IVORY)
 ring(v,.2,Vector3(.5,1.75,.5),DARK)
 return {"visual":v,"wheels":wheels,"arm":arm,"solar":solar,"rtg":rtg,"drill":drill,"radar":radar,"spectrometer":spectrometer,"meteo":meteo,"head":head}
static func station(parent: Node3D) -> Array:
 cylinder(parent,2.1,.18,Vector3(0,.09,0),DARK)
 for x in [-.8,.8]:
  box(parent,Vector3(.12,.7,.12),Vector3(x,.5,0),IVORY)
 cylinder(parent,1.05,1.0,Vector3(0,.9,0),IVORY)
 cylinder(parent,1.15,.12,Vector3(0,1.45,0),ORANGE)
 ball(parent,.65,Vector3(0,1.43,0),IVORY).scale=Vector3(1,.5,1)
 box(parent,Vector3(.65,.5,.07),Vector3(0,1.05,-1.05),BLUE)
 for side in [-1,1]:
  box(parent,Vector3(1.4,.07,1.5),Vector3(side*2,.55,.4),BLUE)
  rod(parent,Vector3(side*.8,.4,.4),Vector3(side*2,.5,.4),.04,IVORY)
 var levels=[]
 for level in range(1,4):
  var n=Node3D.new();n.name="AntennaLevel%d"%level;parent.add_child(n)
  rod(n,Vector3(.6,1.5,.2),Vector3(.6,1.8+level*.5,.2),.05,DARK)
  var dish=cylinder(n,.35+level*.18,.16,Vector3(.6,1.85+level*.5,.2),IVORY,.12)
  dish.rotation_degrees.z=35
  rod(n,Vector3(.6,2+level*.5,.2),Vector3(.6,2.4+level*.5,.2),.02,ORANGE)
  for j in range(level-1): box(n,Vector3(.6,.05,.12),Vector3(.6,1.7+j*.3,.2),ORANGE)
  levels.append(n)
 return levels
static func drone(parent: Node3D) -> Dictionary:
 box(parent,Vector3(.4,.25,.5),Vector3.ZERO,Color("cba663"))
 for side in [-1,1]:
  rod(parent,Vector3(side*.12,-.05,0),Vector3(side*.5,-.45,.35),.018,DARK)
  rod(parent,Vector3(side*.12,-.05,0),Vector3(side*.5,-.45,-.35),.018,DARK)
 box(parent,Vector3(.6,.025,.4),Vector3(0,.35,0),BLUE)
 var rotors=[]
 for y in [.45,.6]:
  var r=box(parent,Vector3(2,.025,.09),Vector3(0,y,0),DARK);rotors.append(r)
 rod(parent,Vector3.ZERO,Vector3(0,.65,0),.02,IVORY)
 return {"rotors":rotors}
static func companion(parent: Node3D) -> Dictionary:
 var body=ball(parent,.42,Vector3(0,.6,0),Color("577a80"));body.scale=Vector3(1,1.3,.8)
 for side in [-1,1]:
  ball(parent,.08,Vector3(side*.15,.8,-.32),Color("e9dcad"))
  rod(parent,Vector3(side*.25,.35,0),Vector3(side*.38,.07,-.12),.09,DARK)
  box(parent,Vector3(.22,.12,.3),Vector3(side*.38,.06,-.17),DARK)
 rod(parent,Vector3(0,1,0),Vector3(.1,1.4,0),.025,ORANGE)
 ball(parent,.07,Vector3(.1,1.4,0),ORANGE)
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
