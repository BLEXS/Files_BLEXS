#!/bin/bash

# ==========================================
# INSTALADOR GESTOR BLEXS V57 - AIRDROP FIX
# ==========================================

if [ "$EUID" -ne 0 ]; then 
    echo -e "\033[1;31m[!] ERROR: Ejecuta con sudo: sudo ./br.sh\033[0m"
    exit 1
fi

echo -e "\033[1;34m[*] Instalando BLEXS V57 (Airdrop Estable)...\033[0m"

# Dependencias (Aseguramos psmisc para fuser)
PKGS="zip xclip python3-pip ntfs-3g exfat-fuse exfatprogs rsync parted gdisk rename qrencode git psmisc"
for pkg in $PKGS; do
    if ! dpkg -s $pkg >/dev/null 2>&1; then apt-get install -y $pkg > /dev/null 2>&1; fi
done

TARGET="/usr/local/bin/blexs_nav"

cat << 'EOF_PAYLOAD' > "$TARGET"
#!/bin/bash
[ -z "$BASH_VERSION" ] && { echo "Ejecuta con bash"; exit 1; }

# --- COLORES ---
RESET='\033[0m'; BOLD='\033[1m'; AZUL='\033[38;5;39m'; ROJO='\033[38;5;196m'
VERDE='\033[38;5;46m'; AMARILLO='\033[38;5;226m'; BLANCO='\033[38;5;255m'
GRIS='\033[38;5;244m'; ROSA='\033[38;5;200m'; CYAN='\033[38;5;51m'; PURPURA='\033[38;5;93m'

# --- EMOJIS (ORIGINALES) ---
I_HOME="🏠"; I_BACK="↩️ "; I_EXIT="🚪"; I_DIR="📁"; I_DOC="📄"
I_FLECHA="👉"; I_CHECK="✅"; I_USB="💾"; I_MEDIA="💿"; I_FIX="🔧"
I_CLIP="📌"; I_PLUS_DIR="✨📂"; I_PLUS_FILE="✨📄"; I_COPY="📑"; I_MOVE="🚚"
I_TRASH="🔥"; I_EDIT="✏️ "; I_RENAME="🏷️ "; I_PERM="🛡️ "; I_RUN="⚡"; I_OPEN="🌍"
I_PASTE="📋"; I_POWER="🔥"; I_LOCK="🔒"; I_EJECT="⏏️ "; I_SYNC="🔄"; I_CANCEL="🗑️ "
I_WARN="⚠️ "; I_INFO="ℹ️ "; I_CUT="✂️ "; I_ZIP="📦"; I_EYE="👁️ "
I_WEB="📡"; I_QR="📱"; I_GIT="🐙"

# --- VARIABLES ---
CLIP_USB_SRC=""; CLIP_USB_TYPE=""; DEV_SELECCIONADO=""; DEV_PADRE=""
CLIP_RUTA=""; CLIP_MODO=""; VER_OCULTOS=false

if [ -n "$SUDO_USER" ]; then REAL_USER="$SUDO_USER"; HOME_DIR=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else REAL_USER=$(whoami); HOME_DIR="$HOME"; fi
ESCRITORIO="$HOME_DIR/Desktop"; [ -d "$HOME_DIR/Escritorio" ] && ESCRITORIO="$HOME_DIR/Escritorio"
HAS_SUDO=""; if [ "$(id -u)" != "0" ]; then HAS_SUDO="sudo"; fi

# ================= FUNCIONES =================

compartir_web_qr_airdrop() {
    local ip; ip=$(hostname -I | awk '{print $1}')
    local port=8000
    if [ -z "$ip" ]; then echo -e "${ROJO}Sin red.${RESET}"; read; return; fi
    
    # 1. LIMPIEZA DE PUERTO (Vital para que no se cierre)
    fuser -k 8000/tcp >/dev/null 2>&1
    
    # 2. GENERAR SCRIPT PYTHON (Sin indentación para evitar errores)
cat << 'PY_EOF' > /tmp/blexs_airdrop.py
import http.server, os, cgi, sys

class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/subir':
            self.send_response(200)
            self.send_header('Content-type', 'text/html; charset=utf-8')
            self.end_headers()
            html = """
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0">
<style>
body{background:#000;color:#0f0;font-family:monospace;text-align:center;padding:20px}
.box{border:1px solid #0f0;padding:20px;border-radius:5px;max-width:400px;margin:0 auto}
h1{margin-top:0}
input{margin:20px 0;width:90%;color:#fff}
button{background:#0f0;color:#000;border:none;padding:15px;width:100%;font-weight:bold;font-size:1.2em;cursor:pointer}
a{color:#0ff;text-decoration:none;display:block;margin-top:30px;border:1px solid #0ff;padding:10px}
</style>
</head>
<body>
<div class="box">
<h1>👽 BLEXS UPLOAD</h1>
<p>Subir archivo a Kali</p>
<form enctype="multipart/form-data" method="POST">
<input type="file" name="file" required><br>
<button type="submit">SUBIR AHORA 🚀</button>
</form>
<a href="/">📂 VER ARCHIVOS (BAJAR)</a>
</div>
</body>
</html>
"""
            self.wfile.write(html.encode('utf-8'))
        else:
            super().do_GET()

    def do_POST(self):
        try:
            form = cgi.FieldStorage(fp=self.rfile, headers=self.headers, environ={'REQUEST_METHOD': 'POST'})
            if 'file' in form:
                fileitem = form['file']
                if fileitem.filename:
                    fn = os.path.basename(fileitem.filename)
                    with open(fn, 'wb') as f: f.write(fileitem.file.read())
                    self.send_response(200)
                    self.send_header('Content-type', 'text/html; charset=utf-8')
                    self.end_headers()
                    self.wfile.write(b"<html><body style='background:#000;color:#0f0;text-align:center;font-family:monospace'><br><h1>EXITO! RECIBIDO.</h1><script>setTimeout(function(){window.location.href='/subir'},2000);</script></body></html>")
        except Exception as e:
            print(e)

if __name__ == '__main__':
    try:
        print("Servidor iniciado...")
        http.server.HTTPServer(('0.0.0.0', 8000), Handler).serve_forever()
    except KeyboardInterrupt:
        print("\nCerrando...")
PY_EOF

    clear
    echo -e "${VERDE}╔════════════════════════════════════════════╗${RESET}"
    echo -e "${VERDE}║${RESET} ${I_WEB} ${BOLD}SERVIDOR BLEXS AIRDROP${RESET}               ${VERDE}║${RESET}"
    echo -e "${VERDE}╚════════════════════════════════════════════╝${RESET}"
    echo -e "${AMARILLO}📂 CARPETA:${RESET} $(basename "$(pwd)")"
    echo -e "${PURPURA}🔗 SUBIR  :${RESET} http://$ip:$port/subir"
    echo -e "\n${BLANCO}👇 ESCANEA PARA CONECTAR:${RESET}\n"
    qrencode -t ANSIUTF8 "http://$ip:$port/subir"
    
    echo -e "\n${ROJO}[!] Presiona CTRL+C para detener el servidor.${RESET}"
    
    # 3. EJECUCIÓN PROTEGIDA
    python3 /tmp/blexs_airdrop.py
    
    # Si falla, no cierra el menú de golpe
    if [ $? -ne 0 ]; then
        echo -e "\n${ROJO}❌ El servidor se cerró inesperadamente.${RESET}"
        echo -e "Posible causa: Puerto 8000 ocupado o error de python."
        read -p "Enter para continuar..."
    fi
    
    rm /tmp/blexs_airdrop.py
}

actualizar_git() {
    if [ -d ".git" ]; then
        echo -e "${PURPURA}${I_GIT} ACTUALIZANDO...${RESET}"
        if git pull; then echo -e "${VERDE}OK.${RESET}"; else echo -e "${ROJO}Error.${RESET}"; fi
    else echo -e "${ROJO}No es un repo git.${RESET}"; fi; sleep 1
}

verificar_nombres_windows() {
    local r="$1"; local b=$(find "$r" -name "*[\:\*\?\"<>|\\]*" 2>/dev/null)
    if [ -n "$b" ]; then echo -e "${ROJO}${I_WARN} NOMBRES ILEGALES.${RESET}"; echo -ne " [s] Corregir [n] Cancelar: "; read -r o
    if [[ "$o" == "s" ]]; then find "$r" -depth -name "*[\:\*\?\"<>|\\]*" -exec sh -c 'mv "$1" "$(echo "$1" | tr -d ":\\*?\"<>|\\\\")"' _ {} \; 2>/dev/null; echo -e "${VERDE}Hecho.${RESET}"; else return 1; fi; fi; return 0
}

reparar_y_redirigir() {
    echo -e "${ROJO}⚠️ USB BLOQUEADA.${RESET} Elige:"; seleccionar_dispositivo_smart; local d="$DEV_SELECCIONADO"; [ -z "$d" ] && return 1
    echo -e "${AMARILLO}>>> Reparando...${RESET}"; $HAS_SUDO umount "$d" 2>/dev/null
    local fs=$($HAS_SUDO lsblk -no FSTYPE "$d" 2>/dev/null)
    if [[ "$fs" == "exfat" ]]; then $HAS_SUDO fsck.exfat -a "$d" >/dev/null 2>&1; else $HAS_SUDO ntfsfix "$d" >/dev/null 2>&1; fi
    local m="/mnt/usb_blexs"; $HAS_SUDO mkdir -p "$m"
    if $HAS_SUDO mount -o rw,users,umask=000 "$d" "$m" 2>/dev/null; then echo -e "${VERDE}OK.${RESET}"; NEW_DESTINO="$m"; return 0; else $HAS_SUDO mount -t exfat -o rw,users,umask=000 "$d" "$m" 2>/dev/null; [ $? -eq 0 ] && NEW_DESTINO="$m" && return 0; fi; return 1
}

seleccionar_dispositivo_smart() {
    echo -e "${CYAN}🔎 UNIDADES:${RESET}"; local ds=(); mapfile -t ds < <(lsblk -lp -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT 2>/dev/null | grep -v "loop\|sr0\|NAME")
    if [ ${#ds[@]} -eq 0 ]; then echo -e "${ROJO}No detectado.${RESET}"; return; fi; local i=1
    for d in "${ds[@]}"; do if [[ "$d" == *"/sda"* ]]; then echo -e " ${ROJO}[SYS]${RESET} $d"; else echo -e " ${VERDE}[$i]${RESET} $d"; fi; ((i++)); done
    echo -ne "\n ${I_FLECHA} #: "; read -r n
    if [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le ${#ds[@]} ]; then local l="${ds[$((n-1))]}"; DEV_SELECCIONADO=$(echo "$l" | awk '{print $1}')
        if [[ "$DEV_SELECCIONADO" == *"/sda"* ]]; then echo -e "${ROJO}ERROR.${RESET}"; DEV_SELECCIONADO=""; read; return; fi
        if [[ "$DEV_SELECCIONADO" =~ [0-9]$ ]]; then DEV_PADRE=${DEV_SELECCIONADO%[0-9]*}; else DEV_PADRE="$DEV_SELECCIONADO"; DEV_SELECCIONADO="${DEV_SELECCIONADO}1"; fi
    else DEV_SELECCIONADO=""; fi
}

mostrar_detalles_usb() {
    seleccionar_dispositivo_smart; local d="$DEV_SELECCIONADO"; [ -z "$d" ] && return
    local m="/mnt/usb_viewer"; $HAS_SUDO mkdir -p "$m" 2>/dev/null; $HAS_SUDO umount "$d" 2>/dev/null
    $HAS_SUDO mount -o ro,users "$d" "$m" 2>/dev/null || $HAS_SUDO mount -t exfat -o ro,users "$d" "$m" 2>/dev/null
    clear; echo -e "${PURPURA}╔══ INSPECTOR ══╗${RESET}"; ls -lh "$m" | head -15; echo "Enter..."; read
}

ejecutar_pegado_usb_777() {
    local dest="$(pwd)"; echo -e "${PURPURA}╔════════════════════════════════════════════╗${RESET}"
    echo -e "${PURPURA}║${RESET} ${I_POWER} ${BOLD}PEGADO USB 777 (V57)${RESET}                 ${PURPURA}║${RESET}"
    echo -e "${PURPURA}╚════════════════════════════════════════════╝${RESET}"
    if ! verificar_nombres_windows "$CLIP_USB_SRC"; then echo "Cancelado."; read; return; fi
    echo -ne "${CYAN}>>> Test Escritura... ${RESET}"; if touch "$dest/.t" 2>/dev/null; then echo "OK"; rm "$dest/.t"; else echo "FAIL"; read -p "Fix? [s/n]: " r; [[ "$r" == "s" ]] && reparar_y_redirigir && dest="$NEW_DESTINO" && cd "$dest" || return; fi
    echo -e "${AMARILLO}ORIGEN :${RESET} $CLIP_USB_SRC"; echo -e "${CYAN}>>> Copiando...${RESET}"
    $HAS_SUDO rsync -rt --no-o --no-g --copy-links --modify-window=1 --progress "$CLIP_USB_SRC" "$dest/"
    $HAS_SUDO chmod -R 777 "$dest/$(basename "$CLIP_USB_SRC")" 2>/dev/null
    echo -e "${VERDE}${I_CHECK} Finalizado.${RESET}"; CLIP_USB_SRC=""; read
}

expulsar_usb_seguro() {
    echo -e "${PURPURA}${I_EJECT} EXPULSIÓN SEGURA${RESET}"; seleccionar_dispositivo_smart; local d="$DEV_SELECCIONADO"; [ -z "$d" ] && return
    echo "Sync..."; sync; [[ "$(pwd)" == *"/mnt/usb_blexs"* ]] && cd "$HOME_DIR"
    $HAS_SUDO umount "$d" 2>/dev/null; $HAS_SUDO umount /mnt/usb_blexs 2>/dev/null
    echo -e "${VERDE}✅ PUEDES RETIRAR: $d${RESET}"; read
}

menu_usb_tools() {
    while true; do clear; echo -e "${CYAN}${BOLD}${I_USB} MANTENIMIENTO USB${RESET}"
    echo -e " [1] ${VERDE}REPARAR${RESET}       [2] ${AMARILLO}MONTAR${RESET}       [5] ${ROJO}FORMAT${RESET}"
    echo -e " [3] ${AZUL}INFO${RESET}          [9] ${ROSA}${I_EJECT} EXPULSAR${RESET}    [0] ${GRIS}VOLVER${RESET}"
    echo -ne "\n ${I_FLECHA} : "; read -r o
    case $o in 1|2|5) seleccionar_dispositivo_smart; local d="$DEV_SELECCIONADO"; [ -z "$d" ] && continue; 
        case $o in 1) $HAS_SUDO umount "$d"; $HAS_SUDO ntfsfix "$d"; read ;; 2) $HAS_SUDO mkdir -p /mnt/usb_blexs; $HAS_SUDO mount -o rw,users,umask=000 "$d" /mnt/usb_blexs; xdg-open /mnt/usb_blexs & read ;; 5) $HAS_SUDO mkfs.exfat "${DEV_PADRE}1"; echo "Done"; read ;; esac ;;
    3) mostrar_detalles_usb ;; 9) expulsar_usb_seguro ;; 0) return ;; esac; done
}

menu_archivo() {
    local f="$1"; local n=$(basename "$f")
    while true; do clear; echo -e "${AZUL}>>> $n${RESET}"
    echo -e " [1] ${I_EDIT} Editar    [2] ${I_TRASH} Eliminar  [3] ${I_RENAME} Renombrar"
    echo -e " [4] ${I_PERM} Permisos  [5] ${I_CUT} Cortar    [6] ${I_COPY} Copiar"
    echo -e " ----------------------------------"
    echo -e " [C] ${I_POWER} ${BOLD}COPIAR A USB 777${RESET}"
    echo -e " ----------------------------------"
    echo -e " [7] ${I_RUN} Ejecutar  [8] ${I_OPEN} Abrir     [Z] ${I_ZIP} Zip"
    echo -e " [0] ${I_BACK} Volver"
    echo -ne "\n ${I_FLECHA} : "; read -r o
    case $o in 1) nano "$f"; return ;; 2) rm -rf "$f"; return ;; 3) read -p "N: " nn; mv "$f" "$nn"; return ;; 4) chmod +x "$f"; return ;; 5) CLIP_RUTA="$(pwd)/$n"; CLIP_MODO="MOVER"; return ;; 6) CLIP_RUTA="$(pwd)/$n"; CLIP_MODO="COPIAR"; return ;; [cC]) CLIP_USB_SRC="$(pwd)/$n"; CLIP_USB_TYPE="FILE"; echo "Loaded"; sleep 1; return ;; [zZ]) zip -r "${n}.zip" "$f"; sleep 1; return ;; 7) chmod +x "$f"; [[ "$n" == *".py" ]] && $HAS_SUDO python3 "$f" || $HAS_SUDO bash "$f"; read; return ;; 8) xdg-open "$f" & return ;; 0) return ;; esac; done
}

navegar() {
    while true; do clear; local r="$(pwd)"; echo -e "${AZUL}┌─────────────────────────────────────────────────────────────┐${RESET}"
    echo -e "${AZUL}│${RESET} ${BOLD}👽 GESTOR BLEXS V57${RESET} :: ${GRIS}$REAL_USER${RESET}"
    echo -e "${AZUL}│${RESET} ${AMARILLO}📍 $r${RESET}"
    [ -n "$CLIP_USB_SRC" ] && echo -e "${AZUL}│${RESET} ${VERDE}${I_POWER} USB COPY: $(basename "$CLIP_USB_SRC")${RESET}"
    echo -e "${AZUL}└─────────────────────────────────────────────────────────────┘${RESET}"
    echo -e " ${ROJO}[x]${RESET} ${I_EXIT} Salir       ${AMARILLO}[0]${RESET} ${I_BACK} Atrás       ${AZUL}[1]${RESET} ${I_HOME} Escritorio"
    echo -e " ${VERDE}[2]${RESET} ${I_PLUS_DIR} Crear Dir   ${VERDE}[3]${RESET} ${I_PLUS_FILE} Crear File  ${CYAN}[U]${RESET} ${I_USB} USB TOOLS"
    echo -e " ${BLANCO}[6]${RESET} ${I_COPY} Copiar Dir  ${BLANCO}[7]${RESET} ${I_MOVE} Mover Dir   ${ROJO}[9]${RESET} ${I_TRASH} BORRAR"
    echo -e " ${ROSA}[E]${RESET} ${I_EJECT} EXPULSAR    ${CYAN}[W]${RESET} ${I_WEB} ${BOLD}AIRDROP${RESET}"
    [ -d .git ] && echo -e " ${PURPURA}[G]${RESET} ${I_GIT} GIT UPDATE"
    echo "───────────────────────────────────────────────────────────────"
    echo -e " ${PURPURA}[C]${RESET} ${I_POWER} ${BOLD}COPIAR ESTA CARPETA A USB${RESET}  ${AMARILLO}[Z]${RESET} ${I_ZIP} ZIP"
    if [ -n "$CLIP_USB_SRC" ]; then echo -e " ${VERDE}[P]${RESET} ${I_POWER} ${BOLD}PEGAR A USB${RESET}  ${ROJO}[K]${RESET} ${I_CANCEL} CANCELAR"; 
    elif [ -n "$CLIP_RUTA" ]; then echo -e " ${ROSA}[P]${RESET} ${I_PASTE} PEGAR (Normal)"; fi
    echo "───────────────────────────────────────────────────────────────"
    local ls=(); if $VER_OCULTOS; then mapfile -t ls < <(ls -1a --group-directories-first | grep -v "^\.$\|^\.\.$"); else mapfile -t ls < <(ls -1 --group-directories-first); fi
    local i=10; if [ ${#ls[@]} -gt 0 ]; then for x in "${ls[@]}"; do if [ -d "$x" ]; then echo -e " ${AZUL}[$i]${RESET} $I_DIR $x${RESET}"; else echo -e " ${BLANCO}[$i]${RESET} $I_DOC $x${RESET}"; fi; ((i++)); done; else echo "Empty"; fi
    echo -ne "\n ${I_FLECHA} : "; read -r i
    case $i in [xX]) exit ;; 0) cd .. ;; 1) cd "$ESCRITORIO" ;; 2) read -p "D: " n; mkdir -p "$n" ;; 3) read -p "F: " n; touch "$n" ;; [eE]) expulsar_usb_seguro ;; [uU]) menu_usb_tools ;; [cC]) CLIP_USB_SRC="$(pwd)"; CLIP_USB_TYPE="DIR"; echo "Loaded"; sleep 1 ;; [zZ]) zip -r "$(basename "$r").zip" . ;; [wW]) compartir_web_qr_airdrop ;; [gG]) actualizar_git ;; [pP]) if [ -n "$CLIP_USB_SRC" ]; then ejecutar_pegado_usb_777; elif [ -n "$CLIP_RUTA" ]; then [[ "$CLIP_MODO" == "COPIAR" ]] && cp -r "$CLIP_RUTA" . || mv "$CLIP_RUTA" .; CLIP_RUTA=""; fi ;; [kK]) CLIP_USB_SRC=""; ;; 6) CLIP_RUTA="$(pwd)"; CLIP_MODO="COPIAR" ;; 7) CLIP_RUTA="$(pwd)"; CLIP_MODO="MOVER" ;; 9) read -p "Del? " c; [[ "$c" == "s" ]] && cd .. && rm -rf "$(basename "$r")" ;; *) if [[ "$i" =~ ^[0-9]+$ ]] && [ "$i" -ge 10 ]; then local s="${ls[$((i-10))]}"; [ -d "$s" ] && cd "$s" || menu_archivo "$s"; fi ;; esac
    done
}
navegar
EOF_PAYLOAD

chmod +x "$TARGET"
echo -e "${VERDE}[OK] BLEXS V57 (AIRDROP STABLE) INSTALADO.${NC}"
