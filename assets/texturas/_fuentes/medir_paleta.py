import bpy, numpy as np, sys, os
def load(p):
    im=bpy.data.images.load(p); im.colorspace_settings.name='Non-Color'
    w,h=im.size; a=np.array(im.pixels[:],dtype=np.float32).reshape(h,w,4)[::-1,:,:3]  # top-down
    return a
def hx(c): c=np.clip(c,0,1); return '#%02X%02X%02X'%tuple(int(round(v*255)) for v in c)
a=load(os.path.join(os.path.dirname(os.path.abspath(__file__)),"../../../") + r"assets/nasa/selfie.jpg"); h,w,_=a.shape
print('size',w,h)
Y=lambda p:(p*[0.2126,0.7152,0.0722]).sum(-1)
sky=a[int(.02*h):int(.18*h)].reshape(-1,3); print('cielo_alto',hx(np.median(a[int(.01*h):int(.06*h)].reshape(-1,3),0)),'cielo_horizonte',hx(np.median(a[int(.19*h):int(.23*h)].reshape(-1,3),0)))
hills=a[int(.235*h):int(.25*h), :int(.55*w)].reshape(-1,3); print('colinas',hx(np.median(hills,0)))
g=np.concatenate([a[int(.30*h):, :int(.58*w)].reshape(-1,3), a[int(.78*h):, int(.58*w):].reshape(-1,3)])
L=Y(g); q=np.percentile(L,[10,30,50,70,90,97])
sel=lambda lo,hi: hx(np.median(g[(L>=lo)&(L<hi)],0))
print('regolito_sombra(<p10)',sel(0,q[0])); print('regolito_oscuro(p10-30)',sel(q[0],q[1])); print('regolito_medio(p30-70)',sel(q[1],q[3])); print('regolito_claro(p70-90)',sel(q[3],q[4])); print('roca_clara(>p97)',sel(q[5],9)); print('roca_media(p90-97)',sel(q[4],q[5]))
print('media_suelo',hx(g.mean(0)))
