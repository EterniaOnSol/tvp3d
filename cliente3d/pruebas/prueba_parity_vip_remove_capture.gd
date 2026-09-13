extends Node
const CONEXION=preload("res://red/conexion772.gd")
const ESTADO=preload("res://red/estado_mundo.gd")
const CRED=preload("res://pruebas/credenciales_qa.gd")
var c; var e; var login; var reconnecting=false; var phase="login"; var t=0.0; var sent=0; var target_id=0; var target_name=""; var setup=false; var readd=false; var dup=false; var msg=false; var recon=false; var obs={}
func _ready():
 var req=["TVP772_PLAYER2_ACCOUNT","TVP772_PLAYER2_PASSWORD","TVP772_PLAYER2_CHARACTER","TVP772_PLAYER_CHARACTER","TVP772_VIP_TARGET_ID"]
 if not CRED.exigir(self,req): return
 target_id=CRED.entero("TVP772_VIP_TARGET_ID"); target_name=CRED.texto("TVP772_PLAYER_CHARACTER"); _login()
func _login():
 login=CONEXION.new(); add_child(login); login.lista_personajes.connect(_chars); login.error_red.connect(func(x): _fail("FAIL login "+str(x))); login.pedir_personajes(CRED.host(),CRED.puerto_login(),CRED.entero("TVP772_PLAYER2_ACCOUNT"),CRED.texto("TVP772_PLAYER2_PASSWORD"))
func _chars(_m,list):
 for x in list:
  if str(x.get("nombre",""))==CRED.texto("TVP772_PLAYER2_CHARACTER"):
   var port=int(x.get("puerto",0)); login.cerrar(); _open(port); return
 _fail("FAIL observer missing")
func _open(port):
 e=ESTADO.new(); e.vip_actualizado.connect(_vip); e.mensaje_pantalla.connect(_message); e.pedido_ping.connect(func(): c.enviar_juego(PackedByteArray([0x1E]))); c=CONEXION.new(); add_child(c); c.paquete_juego.connect(func(m): e.procesar(m)); c.error_red.connect(func(x): _fail("FAIL red "+str(x))); c.entrar_al_mundo(CRED.host(),port,CRED.entero("TVP772_PLAYER2_ACCOUNT"),CRED.texto("TVP772_PLAYER2_CHARACTER"),CRED.texto("TVP772_PLAYER2_PASSWORD")); phase="reconnect" if reconnecting else "baseline"; t=0
func _process(dt):
 t+=dt
 if t>100: _fail("FAIL timeout "+phase)
 if e==null: return
 if phase=="baseline" and t>8:
  if e.vip.has(target_id): _fail("PREFLIGHT target already present")
  elif e.vip.size()>=200: _fail("PREFLIGHT capacity")
  else: phase="setup";t=0;sent=0;print("BASELINE target absent")
 elif phase=="setup" and sent==0: sent=1;c.enviar_agregar_vip(target_name);t=0;print("SETUP ADD sent")
 elif phase=="setup" and setup: phase="remove";sent=0;t=0
 elif phase=="setup" and t>15:_fail("FAIL setup add")
 elif phase=="remove" and sent==0: sent=1;c.enviar_quitar_vip(target_id);t=0;print("REMOVE measured sent")
 elif phase=="remove" and t>3: phase="readd";sent=0;t=0
 elif phase=="readd" and sent==0: sent=1;c.enviar_agregar_vip(target_name);t=0;print("READD sent")
 elif phase=="readd" and readd:
  obs={"vip_remove":{"target_absent_before":true,"setup_add_entry_seen":true,"remove_had_no_success_confirmation":true,"readd_after_remove_entry_seen":true,"readd_duplicate_rejection_seen":dup,"target_absent_after_cleanup_reconnect":false}};phase="cleanup";sent=0;t=0
 elif phase=="readd" and t>15:_fail("FAIL readd")
 elif phase=="cleanup" and sent==0:sent=1;c.enviar_quitar_vip(target_id);t=0;print("CLEANUP REMOVE sent")
 elif phase=="cleanup" and t>2: c.enviar_logout();c.cerrar();reconnecting=true;phase="waiting_login";sent=0;t=0;_login()
 elif phase=="reconnect" and t>8:
  if e.vip.has(target_id): _fail("FAIL target persisted after cleanup")
  else: obs.vip_remove.target_absent_after_cleanup_reconnect=true; print("OBSERVATION_JSON: "+JSON.stringify(obs)); get_tree().quit(0)
 elif phase=="reconnect" and recon:
  obs.vip_remove.target_absent_after_cleanup_reconnect=true;print("OBSERVATION_JSON: "+JSON.stringify(obs));get_tree().quit(0)
func _vip(g,entry):
 if g!=target_id:return
 if phase=="setup" and not setup:
  if str(entry.get("nombre",""))!=target_name:_fail("FAIL identity")
  setup=true;print("SETUP D2 expected")
 elif phase=="readd" and not readd:readd=true;print("READD D2 expected")
 elif phase=="reconnect":_fail("FAIL target persisted after cleanup")
func _message(text,kind):
 if phase=="readd" and kind==0x17 and text=="This player is already in your list.":dup=true
func _fail(x):print(x);get_tree().quit(1)