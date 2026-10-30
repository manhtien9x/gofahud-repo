from pathlib import Path
import hashlib,json,zipfile,os
# All installed text configuration files are included in the source manifest.
base=Path(os.environ.get('GOFAHUD_SOURCE_ROOT','source'));out=Path('outputs/releases');out.mkdir(parents=True,exist_ok=True)
for slug in ['rootless','roothide','ios14-rootful']:
 folder=base/slug
 if not folder.exists():folder=base/f'GOFAHUD-source-{slug}-0.3.4'
 manifest=json.loads((folder/'SOURCE-SHA256.json').read_text(encoding='utf-8'))
 files={p.relative_to(folder).as_posix():p for p in folder.rglob('*') if p.is_file() and 'build' not in p.relative_to(folder).parts}
 assert set(files)==set(manifest)|{'SOURCE-SHA256.json'},slug
 for name,h in manifest.items():assert hashlib.sha256(files[name].read_bytes()).hexdigest()==h,(slug,name)
 dest=out/f'GOFAHUD-{slug}-0.3.4-source.zip'
 with zipfile.ZipFile(dest,'w',zipfile.ZIP_STORED) as z:
  for name,p in sorted(files.items()):
   info=zipfile.ZipInfo(f'GOFAHUD-source-{slug}-0.3.4/'+name,date_time=(1980,1,1,0,0,0));info.create_system=3;info.external_attr=0o100644<<16
   z.writestr(info,p.read_bytes())
 print(dest,hashlib.sha256(dest.read_bytes()).hexdigest())
