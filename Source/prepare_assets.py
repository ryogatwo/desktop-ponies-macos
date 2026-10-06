import csv,json,pathlib,shutil,sys
if len(sys.argv)!=2:
    raise SystemExit("Usage: python3 Source/prepare_assets.py /path/to/Desktop-Ponies")
root=pathlib.Path(sys.argv[1])
out=pathlib.Path(__file__).resolve().parent.parent/'Resources'; ponies=[]
shutil.rmtree(out/'Ponies',ignore_errors=True)
for folder in sorted((root/'Content/Ponies').iterdir()):
    ini=folder/'pony.ini'
    if not ini.exists() or folder.name=='Random Pony': continue
    behaviors=[]; name=folder.name
    lookup={p.name.lower():p for p in folder.iterdir() if p.is_file()}
    for row in csv.reader(ini.read_text(encoding='utf-8-sig',errors='replace').splitlines()):
        if not row: continue
        if row[0].lower()=='name': name=row[1]
        if row[0].lower()!='behavior' or len(row)<9: continue
        row += ['']*max(0,24-len(row))
        try:
            weight=float(row[2]); speed=float(row[5]); low=float(row[4]); high=float(row[3])
        except ValueError: continue
        if weight<=0 or row[12].lower()=='true' or row[15] or row[9] or row[8].lower()=='dragged': continue
        files=[lookup.get(row[i].lower()) for i in (6,7)]
        if any(p is None or p.suffix.lower() not in ('.gif','.png') for p in files): continue
        paths=[]
        for p in files:
            dst=out/'Ponies'/folder.name/p.name; dst.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(p,dst); paths.append(str(dst.relative_to(out)))
        def center(i):
            try: return [float(v) for v in row[i].split(',')] if row[i] else [0,0]
            except ValueError: return [0,0]
        behaviors.append(dict(group=int(row[22] or 0),name=row[1],weight=weight,min=max(.5,low),max=max(.5,high),speed=speed,mode=row[8].lower(),right=paths[0],left=paths[1],rc=center(19),lc=center(20),once=row[21].lower()=='true'))
    groups=[b['group'] for b in behaviors if b['group']>0]
    default_group=min(groups) if groups else 0
    behaviors=[b for b in behaviors if b['group'] in (0,default_group)]
    if behaviors: ponies.append(dict(name=name,id=folder.name,behaviors=behaviors))
(out/'ponies.json').write_text(json.dumps(ponies,ensure_ascii=False))
shutil.copy2(root/'Content/credits.txt',out/'UPSTREAM-CREDITS.txt')
print(f'{len(ponies)} characters, {sum(len(p["behaviors"]) for p in ponies)} behaviors')
