# Texturas PBR procedurales de Marte, repetibles sin costuras (ruido periódico por FFT).
# Paleta medida en NASA PIA24542 (selfie del Perseverance en Jezero). No usa píxeles de fotos.
import bpy, numpy as np, os
N=1024; OUT=os.path.join(os.path.dirname(os.path.abspath(__file__)),"../../../") + r"assets/texturas"
rng=np.random.default_rng(2026)
def hexc(s): return np.array([int(s[i:i+2],16)/255 for i in (1,3,5)],dtype=np.float32)
def fbm(beta, lo=1.0, hi=None, seed=None):
    r=np.random.default_rng(seed) if seed is not None else rng
    f=np.fft.fftfreq(N)*N; fx,fy=np.meshgrid(f,f); k=np.sqrt(fx*fx+fy*fy); k[0,0]=1
    amp=k**(-beta/2); amp[k<lo]=0
    if hi: amp*=np.exp(-(k/hi)**2)
    ph=np.fft.fft2(r.standard_normal((N,N)))
    n=np.real(np.fft.ifft2(ph*amp)); n-=n.mean(); return n/(n.std()+1e-9)
def norm01(a): a=a-a.min(); return a/(a.max()+1e-9)
def normal_map(h, strength):
    dx=(np.roll(h,-1,1)-np.roll(h,1,1))*0.5*strength; dy=(np.roll(h,-1,0)-np.roll(h,1,0))*0.5*strength
    # imagen de arriba abajo: fila+1 = abajo; convención OpenGL (Y+ arriba) que usa Godot
    nx=-dx; ny=dy; nz=np.ones_like(h); l=np.sqrt(nx*nx+ny*ny+nz*nz)
    return np.stack([nx/l*0.5+0.5, ny/l*0.5+0.5, nz/l*0.5+0.5],-1)
def discos(n, rmin, rmax, seed):
    r=np.random.default_rng(seed); h=np.zeros((N,N),np.float32); m=np.zeros((N,N),np.float32)
    yy,xx=np.mgrid[0:N,0:N]
    for _ in range(n):
        cx,cy=r.uniform(0,N,2); rad=r.uniform(rmin,rmax); el=r.uniform(0.6,1.0); ang=r.uniform(0,np.pi)
        R=int(rad*1.6)+2; x0,y0=int(cx)-R,int(cy)-R
        ys=(np.arange(y0,y0+2*R))%N; xs=(np.arange(x0,x0+2*R))%N
        gy,gx=np.meshgrid(np.arange(y0,y0+2*R)-cy, np.arange(x0,x0+2*R)-cx, indexing='ij')
        u=(gx*np.cos(ang)+gy*np.sin(ang))/rad; v=(-gx*np.sin(ang)+gy*np.cos(ang))/(rad*el)
        d=np.sqrt(u*u+v*v); bump=np.clip(1-d*d,0,None)**0.6
        sub=h[np.ix_(ys,xs)]; h[np.ix_(ys,xs)]=np.maximum(sub,bump*rad/rmax)
        mm=m[np.ix_(ys,xs)]; m[np.ix_(ys,xs)]=np.maximum(mm,(d<1).astype(np.float32)*r.uniform(0.3,1.0))
    return h,m
def guardar(nombre, rgb, quality=92):
    img=bpy.data.images.new(nombre,N,N,alpha=False,float_buffer=False,is_data=True)
    px=np.ones((N,N,4),np.float32); px[...,:3]=np.clip(rgb if rgb.ndim==3 else rgb[...,None],0,1)
    img.pixels.foreach_set(px[::-1].ravel())
    sc=bpy.context.scene; s=sc.render.image_settings; s.file_format='JPEG'; s.quality=quality; s.color_mode='RGB'
    path=os.path.join(OUT,nombre+'.jpg'); img.save_render(path,scene=sc); print('ok',path)
    return path
lerp=lambda a,b,t: a+(b-a)*t[...,None]


def voronoi(npts, sx, sy, seed, warp=None, jitter_grid=None):
    """f1, f2 periódicos. jitter_grid=(gx,gy): semillas en rejilla con desplazamiento aleatorio (sin pares pegados).
    warp=(wx,wy): desplazamiento periódico de coordenadas para bordes irregulares."""
    r=np.random.default_rng(seed)
    if jitter_grid:
        gx,gy=jitter_grid; cx,cy=np.meshgrid((np.arange(gx)+0.5)/gx*N,(np.arange(gy)+0.5)/gy*N)
        P=np.stack([cx.ravel()+r.uniform(-0.35,0.35,gx*gy)*N/gx, cy.ravel()+r.uniform(-0.35,0.35,gx*gy)*N/gy],1)%N
    else:
        P=r.uniform(0,N,(npts,2))
    yy,xx=np.mgrid[0:N,0:N].astype(np.float32)
    if warp is not None: xx=xx+warp[0]; yy=yy+warp[1]
    f1=np.full((N,N),1e9,np.float32); f2=f1.copy(); cid=np.zeros((N,N),np.int32)
    for i,(px,py) in enumerate(P):
        dx=np.abs(xx-px)%N; dx=np.minimum(dx,N-dx)*sx; dy=np.abs(yy-py)%N; dy=np.minimum(dy,N-dy)*sy
        d=np.sqrt(dx*dx+dy*dy); m1=d<f1
        f2=np.where(m1,f1,np.minimum(f2,d)); cid=np.where(m1,i,cid); f1=np.where(m1,d,f1)
    return f1,f2,cid,len(P)

# ---------------- regolito (tono pardo-rojizo: medido en PIA24542 y algo más cálido para la luz del juego)
OSC,MED,CLA=hexc('#64523F'),hexc('#745F49'),hexc('#86705A')
ROCA_M,ROCA_C,GRIS=hexc('#A08368'),hexc('#C29E7E'),hexc('#544A40')
grande=fbm(2.6,lo=1,hi=40,seed=1); medio=fbm(2.0,lo=4,hi=200,seed=2); grano=fbm(0.4,lo=60,seed=3)
t=norm01(grande*0.7+medio*0.3)
col=lerp(lerp(OSC,MED,np.clip(t*1.6,0,1)),CLA,np.clip(t*1.6-0.6,0,1))
# ondulaciones de arena muy suaves
yy,xx=np.mgrid[0:N,0:N].astype(np.float32)
rip=np.sin((xx*0.8+yy)/N*2*np.pi*22+grande*2.5)*0.5+0.5
peb_h,peb_m=discos(1600,1.2,4,seed=4)       # gravilla oscura
# cantos claros angulosos: celdas de Voronoi recortadas por ruido (formas irregulares, aristas rectas)
f1,f2,cid,_=voronoi(70,1.0,1.0,seed=5)
rr=np.random.default_rng(6); keep=rr.uniform(0,1,70)<0.55; size=rr.uniform(9,26,70)
forma=fbm(1.4,lo=6,hi=160,seed=7)
roc_m=(keep[cid] & (f1 < size[cid]*(1+0.35*forma))).astype(np.float32)
roc_h=np.clip(1-f1/(size[cid]*1.3),0,1)**0.5*roc_m
col=lerp(col,GRIS*(0.9+0.2*norm01(medio)[...,None]),np.clip(peb_m,0,1)*0.8)
col=lerp(col,lerp(ROCA_M,ROCA_C,np.clip(roc_h*1.3,0,1)),roc_m*0.95)
borde=np.clip(roc_m - np.clip(roc_h*4,0,1),0,1)
col*=(1-0.25*borde)[...,None]
col*= (1+0.07*grano)[...,None]*(0.97+0.06*rip)[...,None]
h=0.35*grande+0.25*medio+0.06*grano+0.08*rip+1.0*peb_h+1.6*roc_h
rough=np.clip(0.92+0.04*grano-0.15*roc_m-0.06*np.clip(peb_m,0,1),0,1)
guardar('marte_regolito_color',col); guardar('marte_regolito_normal',normal_map(h,3.0),90); guardar('marte_regolito_rugosidad',rough,88)
print('regolito media','#%02X%02X%02X'%tuple(int(v*255) for v in col.reshape(-1,3).mean(0)))

# ---------------- roca con estratos (afloramiento sedimentario del delta de Jezero)
CAPAS=[hexc('#A08368'),hexc('#B08F72'),hexc('#8A7058'),hexc('#C29E7E'),hexc('#957A60'),hexc('#7C6450')]
NL=26
warp=fbm(3.2,lo=1,hi=8,seed=10); warp2=fbm(2.4,lo=3,hi=60,seed=11)
s=yy/N*NL + warp*0.45 + warp2*0.06
idx=np.floor(s).astype(int)%NL; fr=s-np.floor(s)
r=np.random.default_rng(12); dureza=r.uniform(0,1,NL); colidx=r.integers(0,len(CAPAS),NL)
d=dureza[idx]
perfil=np.where(fr<0.15, (fr/0.15)**0.7, 1.0-0.25*(fr-0.15))*(0.35+0.65*d)
# bloques: Voronoi estirado en horizontal (losas rotas por fracturas casi verticales)
wv=(fbm(2.6,lo=2,hi=22,seed=17)*22, fbm(2.6,lo=2,hi=22,seed=18)*14)
f1,f2,cid,nc=voronoi(0,0.6,1.0,seed=13,warp=wv,jitter_grid=(5,7))
ancho=2.2+1.6*norm01(fbm(1.5,lo=3,hi=60,seed=19))
corte=np.clip((fbm(1.8,lo=2,hi=40,seed=20)+0.55)*2.5,0,1)   # juntas discontinuas
junta=(np.clip(1-(f2-f1)/ancho,0,1)**1.5)*corte
blk=np.random.default_rng(14).uniform(-1,1,nc)[cid]
grano=fbm(0.5,lo=50,seed=15); det=fbm(1.8,lo=8,hi=300,seed=16)
col=np.stack(CAPAS)[colidx[idx]]
col*=(0.94+0.08*norm01(det))[...,None]*(1+0.05*grano)[...,None]*(1+0.04*blk)[...,None]
polvo=np.clip((1-perfil)*0.9+junta*0.7,0,1)
col=lerp(col,hexc('#745F49'),polvo*0.5)
col*=(1-0.45*junta)[...,None]
h=perfil*1.0+0.12*det+0.04*grano+0.10*blk-1.0*junta
rough=np.clip(0.80+0.08*grano+0.10*polvo-0.06*d,0,1)
guardar('marte_roca_estratos_color',col); guardar('marte_roca_estratos_normal',normal_map(h,6.0),90); guardar('marte_roca_estratos_rugosidad',rough,88)
print('roca media','#%02X%02X%02X'%tuple(int(v*255) for v in col.reshape(-1,3).mean(0)))
