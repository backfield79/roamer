#!/usr/bin/env python3
import json,os,sys,re
DB=os.environ['MOCK_STATE']+'/live.json'; d=json.load(open(DB))
a=sys.argv[1:]; q=False
if a and a[0]=='-q': q=True; a=a[1:]
cmd,args=a[0],a[1:]
def resolve(k):
    m=re.match(r'^(\w+)\.@(\w+)\[(\d+)\](.*)$',k)
    if m:
        c,t,i,rest=m.groups(); secs=[s for s in d['order'] if s.startswith(c+'.') and d['t'][s]==t]
        return secs[int(i)]+rest
    return k
def save(): json.dump(d,open(DB,'w'))
if cmd=='show':
    p=args[0] if args else ''
    p=resolve(p)
    for s in d['order']:
        if not s.startswith(p.split('.')[0]+'.') : continue
        c=s.split('.')[0]; anon=d.get('anon',{}).get(s)
        name=anon or s
        if p.count('.')>=1 and not (p==s or p.startswith(s+'.')): continue
        if p.count('.')<2: print(f"{name}={d['t'][s]}")
        for k,v in d['o'].get(s,{}).items():
            if p.count('.')==2 and p!=s+'.'+k: continue
            print(f"{name}.{k}="+(' '.join(f"'{x}'" for x in v) if isinstance(v,list) else f"'{v}'"))
elif cmd=='get':
    k=resolve(args[0])
    if k.count('.')==1:
        if k in d['t']: print(d['t'][k]); sys.exit(0)
        sys.exit(1)
    s,o=k.rsplit('.',1)
    v=d['o'].get(s,{}).get(o)
    if v is None: sys.exit(1)
    print(' '.join(v) if isinstance(v,list) else v)
elif cmd=='set':
    k,v=args[0].split('=',1); k=resolve(k)
    if k.count('.')==1: d['t'][k]=v; d['order'].append(k) if k not in d['order'] else None; d['o'].setdefault(k,{})
    else:
        s,o=k.rsplit('.',1); assert s in d['t'], 'no section '+s; d['o'][s][o]=v
    save()
elif cmd=='add_list':
    k,v=args[0].split('=',1); k=resolve(k); s,o=k.rsplit('.',1); assert s in d['t']; d['o'][s].setdefault(o,[]); d['o'][s][o].append(v); save()
elif cmd=='delete':
    k=resolve(args[0])
    if k.count('.')==1:
        if k not in d['t']: sys.exit(1)
        del d['t'][k]; d['order'].remove(k); d['o'].pop(k,None)
    else:
        s,o=k.rsplit('.',1)
        if o not in d['o'].get(s,{}): sys.exit(1)
        del d['o'][s][o]
    save()
elif cmd=='add':
    c,t=args; n=f"{c}.cfg{len(d['order']):04x}"; d['t'][n]=t; d['order'].append(n); d['o'][n]={}
    i=len([s for s in d['order'] if s.startswith(c+'.') and d['t'][s]==t])-1
    d.setdefault('anon',{})[n]=f"{c}.@{t}[{i}]"; print(n.split('.')[1]); save()
elif cmd=='del_list':
    k,v=args[0].split('=',1); k=resolve(k); s_,o=k.rsplit('.',1)
    l=d['o'].get(s_,{}).get(o,[]); 
    if v in l: l.remove(v)
    save()
elif cmd=='commit': pass
elif cmd=='changes':
    import os
    f=os.environ.get('PENDING')
    if f: print(open(f).read(),end='')
elif cmd=='revert': pass
