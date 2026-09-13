extends Node
const CONEXION=preload("res://red/conexion772.gd")
const ESTADO=preload("res://red/estado_mundo.gd")
const CRED=preload("res://pruebas/credenciales_qa.gd")
var c; var e; var phase="login"; var t=0.0; var sent=0; var target_id=0; var target_name=""; var first=false; var duplicate=false; var msg_ok=false; var d2_after=0; var obs={}
func _ready():
 var req=["TVP772_PLAYER2_ACCOUNT","TVP772_PLAYER2_PASSWORD","TVP772_PLAYER2_CHARACTER","TVP772_PLAYER_CHARACTER","TVP772_VIP_TARGET_ID"]
 if not CRED.exigir(self,req): return
 target_id=CRED.entero("TVP772_VIP_TARGET_ID"); target_name=CRED.texto("TVP772_PLAYER_CHARACTER")
 c=CONEXION.new(); add_child(c); c.lista_personajes.connect(_chars); c.error_red.connect(func(x): _fail("FAIL red: "+str(x))); c.pedir_personajes(CRED.host(),CRED.puerto_login(),CRED.entero("TVP772_PLAYER2_ACCOUNT"),CRED.texto("TVP772_PLAYER2_PASSWORD"))
func _chars(_m,list):
 for x in list:
  if str(x.get("nombre",""))==CRED.texto("TVP772_PLAYER2_CHARACTER"):
   c.cerrar(); _open(int(x.get("puerto",0))); return
 _fail("FAIL observer character missing")
func _open(port):
 e=ESTADO.new(); e.vip_actualizado.connect(_vip); e.mensaje_pantalla.connect(_message); e.pedido_ping.connect(func(): c.enviar_juego(PackedByteArray([0x1E]))); c.paquete_juego.connect(func(m): e.procesar(m)); c.entrar_al_mundo(CRED.host(),port,CRED.entero("TVP772_PLAYER2_ACCOUNT"),CRED.texto("TVP772_PLAYER2_CHARACTER"),CRED.texto("TVP772_PLAYER2_PASSWORD")); phase="replay"; t=0
func _process(dt):
 t+=dt
 if t>90: _fail("FAIL timeout "+phase)
 if e==null: return
 if phase=="replay" and t>8:
  if e.vip.has(target_id): _fail("PREFLIGHT target present in completed login replay")
  elif e.vip.size()>=200: _fail("PREFLIGHT VIP capacity unavailable")
  else: phase="first"; t=0; sent=0; print("BASELINE target absent; entries=%d"%e.vip.size())
 elif phase=="first" and sent==0:
  sent=1; c.enviar_agregar_vip(target_name); print("FIRST ADD sent via production semantic API"); t=0
 elif phase=="first" and first: phase="duplicate"; sent=0; t=0
 elif phase=="first" and t>15: _fail("FAIL first add produced no expected VIP entry")
 elif phase=="duplicate" and sent==0:
  sent=1; c.enviar_agregar_vip(target_name); print("DUPLICATE ADD sent via production semantic API"); t=0
 elif phase=="duplicate" and duplicate:
  obs={"vip_duplicate_add":{"target_absent_before":true,"first_add_expected_entry":true,"duplicate_rejected":msg_ok,"additional_entry_emitted":d2_after==0}}
  phase="cleanup"; sent=0; t=0
 elif phase=="duplicate" and t>12: _fail("FAIL duplicate rejection not observed")
 elif phase=="cleanup" and sent==0:
  sent=1; c.enviar_quitar_vip(target_id); print("CLEANUP remove sent before logout"); t=0
 elif phase=="cleanup" and t>2:
  c.enviar_logout(); print("OBSERVATION_JSON: "+JSON.stringify(obs)); await get_tree().create_timer(1.0).timeout; c.cerrar(); get_tree().quit(0)
func _vip(g,entry):
 if phase=="first" and g==target_id and not first:
  if str(entry.get("nombre",""))!=target_name: _fail("FAIL canonical identity mismatch")
  first=true; print("FIRST D2 expected GUID received")
 elif phase=="duplicate" and g==target_id: d2_after+=1
func _message(text,kind):
 if phase=="duplicate": msg_ok=(kind==0x17 and text=="This player is already in your list."); duplicate=true; print("DUPLICATE B4 type=%d exact=%s"%[kind,str(msg_ok)])
func _fail(x): print(x); get_tree().quit(1)