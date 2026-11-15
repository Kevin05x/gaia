#!/usr/bin/env python3
"""Quita de un .glb los nodos cuyo nombre empiece por alguno de los prefijos dados y compacta el archivo
(mallas, materiales, texturas, accesores y bufferViews que ya nadie usa). Solo biblioteca estándar."""
import json, struct, sys

def leer(p):
    d = open(p, 'rb').read()
    lj = struct.unpack('<I', d[12:16])[0]
    j = json.loads(d[20:20 + lj])
    off = 20 + lj
    lb = struct.unpack('<I', d[off:off + 4])[0]
    assert d[off + 4:off + 8] == b'BIN\x00'
    return j, d[off + 8:off + 8 + lb]

def escribir(p, j, binario):
    js = json.dumps(j, separators=(',', ':')).encode()
    js += b' ' * (-len(js) % 4)
    binario += b'\x00' * (-len(binario) % 4)
    total = 12 + 8 + len(js) + 8 + len(binario)
    with open(p, 'wb') as f:
        f.write(b'glTF' + struct.pack('<II', 2, total))
        f.write(struct.pack('<I', len(js)) + b'JSON' + js)
        f.write(struct.pack('<I', len(binario)) + b'BIN\x00' + binario)

def main(entrada, salida, prefijos):
    j, b = leer(entrada)
    quitar = {i for i, n in enumerate(j['nodes']) if any(n.get('name', '').startswith(f) for f in prefijos)}
    # nodos que quedan, con nuevo índice
    quedan = [i for i in range(len(j['nodes'])) if i not in quitar]
    nuevo_nodo = {v: k for k, v in enumerate(quedan)}
    nodos = []
    for i in quedan:
        n = dict(j['nodes'][i])
        if 'children' in n:
            n['children'] = [nuevo_nodo[c] for c in n['children'] if c in nuevo_nodo]
        nodos.append(n)
    # mallas usadas
    mallas_usadas = sorted({n['mesh'] for n in nodos if 'mesh' in n})
    nueva_malla = {v: k for k, v in enumerate(mallas_usadas)}
    for n in nodos:
        if 'mesh' in n: n['mesh'] = nueva_malla[n['mesh']]
    mallas = [json.loads(json.dumps(j['meshes'][m])) for m in mallas_usadas]
    # materiales usados
    mats_usados = sorted({p['material'] for m in mallas for p in m['primitives'] if 'material' in p})
    nuevo_mat = {v: k for k, v in enumerate(mats_usados)}
    materiales = [json.loads(json.dumps(j['materials'][m])) for m in mats_usados]
    for m in mallas:
        for p in m['primitives']:
            if 'material' in p: p['material'] = nuevo_mat[p['material']]
    # texturas e imágenes usadas por los materiales
    def texturas_de(mat):
        r = []
        def rec(o):
            if isinstance(o, dict):
                if 'index' in o and isinstance(o['index'], int) and len(o) <= 3 and ('texCoord' in o or len(o) == 1 or 'scale' in o or 'strength' in o):
                    r.append(o)
                for v in o.values(): rec(v)
            elif isinstance(o, list):
                for v in o: rec(v)
        rec(mat); return r
    refs = [t for m in materiales for t in texturas_de(m)]
    tex_usadas = sorted({t['index'] for t in refs})
    nueva_tex = {v: k for k, v in enumerate(tex_usadas)}
    for t in refs: t['index'] = nueva_tex[t['index']]
    texturas = [dict(j['textures'][t]) for t in tex_usadas]
    img_usadas = sorted({t['source'] for t in texturas if 'source' in t})
    nueva_img = {v: k for k, v in enumerate(img_usadas)}
    for t in texturas:
        if 'source' in t: t['source'] = nueva_img[t['source']]
    imagenes = [dict(j['images'][i]) for i in img_usadas]
    # accesores y bufferViews usados
    acc_usados = set()
    for m in mallas:
        for p in m['primitives']:
            acc_usados.update(p['attributes'].values())
            if 'indices' in p: acc_usados.add(p['indices'])
    acc_usados = sorted(acc_usados)
    nuevo_acc = {v: k for k, v in enumerate(acc_usados)}
    for m in mallas:
        for p in m['primitives']:
            p['attributes'] = {k: nuevo_acc[v] for k, v in p['attributes'].items()}
            if 'indices' in p: p['indices'] = nuevo_acc[p['indices']]
    accesores = [dict(j['accessors'][a]) for a in acc_usados]
    bv_usados = sorted({a['bufferView'] for a in accesores if 'bufferView' in a} | {im['bufferView'] for im in imagenes if 'bufferView' in im})
    nuevo_bv = {v: k for k, v in enumerate(bv_usados)}
    nb = bytearray(); bvs = []
    for v in bv_usados:
        o = dict(j['bufferViews'][v])
        nb += b'\x00' * (-len(nb) % 4)
        ini = o.get('byteOffset', 0)
        nuevo_off = len(nb)
        nb += b[ini:ini + o['byteLength']]
        o['byteOffset'] = nuevo_off; o['buffer'] = 0
        bvs.append(o)
    for a in accesores:
        if 'bufferView' in a: a['bufferView'] = nuevo_bv[a['bufferView']]
    for im in imagenes:
        if 'bufferView' in im: im['bufferView'] = nuevo_bv[im['bufferView']]
    salida_j = {k: v for k, v in j.items() if k not in ('nodes', 'meshes', 'materials', 'textures', 'images', 'accessors', 'bufferViews', 'buffers', 'scenes')}
    salida_j.update(nodes=nodos, meshes=mallas, materials=materiales, accessors=accesores, bufferViews=bvs,
                    buffers=[{'byteLength': len(nb)}])
    if texturas: salida_j['textures'] = texturas
    if imagenes: salida_j['images'] = imagenes
    # escenas: raíces que queden
    escenas = []
    for s in j['scenes']:
        s2 = dict(s); s2['nodes'] = [nuevo_nodo[n] for n in s.get('nodes', []) if n in nuevo_nodo]; escenas.append(s2)
    salida_j['scenes'] = escenas
    escribir(salida, salida_j, bytes(nb))
    print("nodos quitados:", len(quitar), "| mallas", len(j['meshes']), "->", len(mallas), "| materiales", len(j['materials']), "->", len(materiales),
          "| texturas", len(j.get('textures', [])), "->", len(texturas), "| bytes", len(b), "->", len(nb))

if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], sys.argv[3:])
