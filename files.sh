#!/bin/bash

# ==========================================
# INSTALADOR GESTOR BLEXS V58.0
# ==========================================

if [ "$EUID" -ne 0 ]; then 
    echo -e "\033[1;32m[!] ERROR: Ejecuta con sudo: sudo ./br.sh\033[0m"
    exit 1
fi

echo -e "\033[38;5;46m[👽] Instalando BLEXS V58.0...\033[0m"

PKGS="zip xclip python3-pip rsync rename qrencode git psmisc xdg-user-dirs openssh-client curl"
for pkg in $PKGS; do
    if ! dpkg -s $pkg >/dev/null 2>&1; then apt-get install -y $pkg > /dev/null 2>&1; fi
done

TARGET="/usr/local/bin/blexs_nav"

cat << 'EOF_PAYLOAD' > "$TARGET"
#!/bin/bash
[ -z "$BASH_VERSION" ] && { echo "Ejecuta con bash"; exit 1; }

# --- COLORES FIJOS ---
RESET='\033[0m'; BOLD='\033[1m'; DIM='\033[2m'
ROJO='\033[38;5;196m'
AMARILLO='\033[38;5;226m'
NARANJA='\033[38;5;208m'
GRIS='\033[38;5;240m'
GRIS2='\033[38;5;245m'
BLANCO='\033[38;5;255m'

# --- EMOJIS ---
I_ALIEN="👽"
I_EXIT="🚨";    I_BACK="◀️ ";    I_HOME="🖥️ ";   I_DIR="📂";    I_DOC="📄"
I_CHECK="✅";   I_WARN="⚠️ ";   I_STAR="🌟"
I_PLUS_DIR="➕📂"; I_PLUS_FILE="➕📄"; I_COPY="📋"; I_MOVE="📦"
I_TRASH="🗑️ "; I_EDIT="📝";    I_RENAME="✏️ "; I_PERM="🔓";   I_RUN="▶️ "
I_OPEN="🌐";   I_PASTE="📌";   I_POWER="⚡";   I_CANCEL="✖️ "
I_CUT="✂️ ";   I_ZIP="🗜️ ";   I_EYE="🔎";    I_WEB="🌐";    I_GIT="🐙"
I_SEARCH="🔍"; I_MULTI="☑️ "; I_DISCO="💿";  I_RELOJ="⏱️ "; I_ITEMS="🗂️ "
I_RUTA="📍";   I_USER="👤";   I_SUDO="🔴";   I_NOSUDO="🟢"; I_MARCA="▶"
I_VACIO="·";   I_LOCK="🔒";   I_SYNC="🔄";   I_TEMA="🎨";   I_SLOT="⚡"

# --- VARIABLES ---
CLIP_RUTA=""; CLIP_MODO=""; VER_OCULTOS=false

if [ -n "$SUDO_USER" ]; then REAL_USER="$SUDO_USER"; HOME_DIR=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else REAL_USER=$(whoami); HOME_DIR="$HOME"; fi

HAS_SUDO=""; if [ "$(id -u)" != "0" ]; then HAS_SUDO="sudo"; fi
TEMA_FILE="$HOME_DIR/.blexs_tema"
SLOTS_FILE="$HOME_DIR/.blexs_slots"

# --- TRAP: limpieza automática al salir ---
AIRDROP_PID=""
TUNNEL_PID=""
cleanup() {
    [ -n "$AIRDROP_PID" ] && kill "$AIRDROP_PID" 2>/dev/null
    [ -n "$TUNNEL_PID" ] && kill "$TUNNEL_PID" 2>/dev/null
    fuser -k 8000/tcp >/dev/null 2>&1
    rm -f /tmp/blexs_airdrop.py /tmp/blexs_tunnel_url /tmp/blexs_tunnel_output /tmp/blexs_server_log
}
trap cleanup EXIT INT TERM

# ================= DETECCIÓN INTELIGENTE DE ESCRITORIO =================
detectar_escritorio() {
    local candidatos=()
    local xdg=""
    if [ -n "$SUDO_USER" ]; then
        xdg=$(sudo -u "$SUDO_USER" xdg-user-dir DESKTOP 2>/dev/null)
    else
        xdg=$(xdg-user-dir DESKTOP 2>/dev/null)
    fi
    if [ -n "$xdg" ] && [ -d "$xdg" ] && [[ "$xdg" == "$HOME_DIR"* ]]; then
        candidatos+=("$xdg")
    fi
    local nombres=("Desktop" "Escritorio" "Bureau" "Schreibtisch" "Skrivbord" "Bureaublad" "桌面")
    for n in "${nombres[@]}"; do
        local c="$HOME_DIR/$n"
        if [ -d "$c" ]; then
            local ya=false
            for ex in "${candidatos[@]}"; do [ "$ex" == "$c" ] && ya=true; done
            $ya || candidatos+=("$c")
        fi
    done
    while IFS= read -r found; do
        [ -z "$found" ] && continue
        local ya=false
        for ex in "${candidatos[@]}"; do [ "$ex" == "$found" ] && ya=true; done
        $ya || candidatos+=("$found")
    done < <(find "$HOME_DIR" -maxdepth 1 -type d \
        \( -iname "*desktop*" -o -iname "*escritorio*" -o -iname "*bureau*" \) 2>/dev/null)
    local mejor="" mejor_count=-1
    for c in "${candidatos[@]}"; do
        local count
        count=$(ls -1A "$c" 2>/dev/null | wc -l)
        if [ "$count" -gt "$mejor_count" ]; then mejor_count=$count; mejor="$c"; fi
    done
    if [ -n "$mejor" ] && [ "$mejor_count" -gt 0 ]; then echo "$mejor"; return; fi
    if [ -n "$xdg" ] && [ -d "$xdg" ] && [[ "$xdg" == "$HOME_DIR"* ]]; then echo "$xdg"; return; fi
    [ ${#candidatos[@]} -gt 0 ] && echo "${candidatos[0]}" && return
    echo "$HOME_DIR"
}

ESCRITORIO=$(detectar_escritorio)

# ================= SISTEMA DE SLOTS (Navegación Ultra-Rápida) =================
SLOT1=""; SLOT2=""; SLOT3=""

cargar_slots() {
    if [ -f "$SLOTS_FILE" ]; then
        SLOT1=$(sed -n '1p' "$SLOTS_FILE")
        SLOT2=$(sed -n '2p' "$SLOTS_FILE")
        SLOT3=$(sed -n '3p' "$SLOTS_FILE")
    fi
}

guardar_slots() {
    printf '%s\n%s\n%s\n' "$SLOT1" "$SLOT2" "$SLOT3" > "$SLOTS_FILE"
}

slot_nombre() {
    local s="$1"
    if [ -n "$s" ] && [ -d "$s" ]; then echo "$(basename "$s")"
    else echo "·"; fi
}

mostrar_slots() {
    local s1=$(slot_nombre "$SLOT1")
    local s2=$(slot_nombre "$SLOT2")
    local s3=$(slot_nombre "$SLOT3")
    echo -e "${COLOR3}║${RESET}  ${I_SLOT} ${GRIS}SLOTS${RESET} ${COLOR4}[!]${RESET}${COLOR1}$s1${RESET}  ${COLOR4}[\"]${RESET}${COLOR1}$s2${RESET}  ${COLOR4}[#]${RESET}${COLOR1}$s3${RESET}  ${GRIS}│ m1-3 guardar · k1-3 borrar${RESET}"
}

# ================= SISTEMA DE TEMAS =================

cargar_tema() {
    local tema="matrix"
    [ -f "$TEMA_FILE" ] && tema=$(cat "$TEMA_FILE")
    aplicar_tema "$tema"
}

aplicar_tema() {
    local t="$1"
    case $t in
        matrix)
            COLOR1='\033[38;5;46m'; COLOR2='\033[38;5;40m'; COLOR3='\033[38;5;34m'
            COLOR4='\033[38;5;51m'; COLOR5='\033[38;5;22m'; NOMBRE_TEMA="🟩 MATRIX" ;;
        purpura)
            COLOR1='\033[38;5;135m'; COLOR2='\033[38;5;99m'; COLOR3='\033[38;5;93m'
            COLOR4='\033[38;5;213m'; COLOR5='\033[38;5;55m'; NOMBRE_TEMA="🟣 PÚRPURA" ;;
        rojo)
            COLOR1='\033[38;5;196m'; COLOR2='\033[38;5;160m'; COLOR3='\033[38;5;124m'
            COLOR4='\033[38;5;208m'; COLOR5='\033[38;5;88m'; NOMBRE_TEMA="🔴 ROJO" ;;
        azul)
            COLOR1='\033[38;5;39m'; COLOR2='\033[38;5;33m'; COLOR3='\033[38;5;27m'
            COLOR4='\033[38;5;51m'; COLOR5='\033[38;5;17m'; NOMBRE_TEMA="🔵 AZUL" ;;
        dorado)
            COLOR1='\033[38;5;226m'; COLOR2='\033[38;5;220m'; COLOR3='\033[38;5;178m'
            COLOR4='\033[38;5;214m'; COLOR5='\033[38;5;136m'; NOMBRE_TEMA="🟡 DORADO" ;;
        cyan)
            COLOR1='\033[38;5;51m'; COLOR2='\033[38;5;45m'; COLOR3='\033[38;5;37m'
            COLOR4='\033[38;5;46m'; COLOR5='\033[38;5;23m'; NOMBRE_TEMA="🩵 CYAN" ;;
        rosa)
            COLOR1='\033[38;5;213m'; COLOR2='\033[38;5;205m'; COLOR3='\033[38;5;162m'
            COLOR4='\033[38;5;51m'; COLOR5='\033[38;5;89m'; NOMBRE_TEMA="🩷 ROSA" ;;
        naranja)
            COLOR1='\033[38;5;214m'; COLOR2='\033[38;5;208m'; COLOR3='\033[38;5;166m'
            COLOR4='\033[38;5;226m'; COLOR5='\033[38;5;130m'; NOMBRE_TEMA="🟠 NARANJA" ;;
        blanco)
            COLOR1='\033[38;5;255m'; COLOR2='\033[38;5;250m'; COLOR3='\033[38;5;244m'
            COLOR4='\033[38;5;51m'; COLOR5='\033[38;5;238m'; NOMBRE_TEMA="⬜ BLANCO" ;;
        hielo)
            COLOR1='\033[38;5;195m'; COLOR2='\033[38;5;189m'; COLOR3='\033[38;5;153m'
            COLOR4='\033[38;5;123m'; COLOR5='\033[38;5;117m'; NOMBRE_TEMA="🧊 HIELO" ;;
        fuego)
            COLOR1='\033[38;5;202m'; COLOR2='\033[38;5;214m'; COLOR3='\033[38;5;130m'
            COLOR4='\033[38;5;220m'; COLOR5='\033[38;5;94m'; NOMBRE_TEMA="🔥 FUEGO" ;;
        oceano)
            COLOR1='\033[38;5;117m'; COLOR2='\033[38;5;74m'; COLOR3='\033[38;5;67m'
            COLOR4='\033[38;5;159m'; COLOR5='\033[38;5;24m'; NOMBRE_TEMA="🌊 OCÉANO" ;;
        toxic)
            COLOR1='\033[38;5;190m'; COLOR2='\033[38;5;184m'; COLOR3='\033[38;5;142m'
            COLOR4='\033[38;5;226m'; COLOR5='\033[38;5;100m'; NOMBRE_TEMA="☢️  TOXIC" ;;
        neon)
            COLOR1='\033[38;5;201m'; COLOR2='\033[38;5;198m'; COLOR3='\033[38;5;162m'
            COLOR4='\033[38;5;123m'; COLOR5='\033[38;5;89m'; NOMBRE_TEMA="💜 NEÓN" ;;
        sangre)
            COLOR1='\033[38;5;160m'; COLOR2='\033[38;5;124m'; COLOR3='\033[38;5;88m'
            COLOR4='\033[38;5;203m'; COLOR5='\033[38;5;52m'; NOMBRE_TEMA="🩸 SANGRE" ;;
        galaxia)
            COLOR1='\033[38;5;183m'; COLOR2='\033[38;5;141m'; COLOR3='\033[38;5;97m'
            COLOR4='\033[38;5;219m'; COLOR5='\033[38;5;54m'; NOMBRE_TEMA="🌌 GALAXIA" ;;
        neonverde)
            COLOR1='\033[38;5;118m'; COLOR2='\033[38;5;82m'; COLOR3='\033[38;5;46m'
            COLOR4='\033[38;5;156m'; COLOR5='\033[38;5;22m'; NOMBRE_TEMA="💚 NEÓN VERDE" ;;
        *) aplicar_tema "matrix"; return ;;
    esac
    TEMA_ACTUAL="$t"
}

sep_top()   { echo -e "${COLOR3}╔══════════════════════════════════════════════════════════════╗${RESET}"; }
sep_mid()   { echo -e "${COLOR3}╠══════════════════════════════════════════════════════════════╣${RESET}"; }
sep_bot()   { echo -e "${COLOR3}╚══════════════════════════════════════════════════════════════╝${RESET}"; }
sep_linea() { echo -e "${COLOR5}  ┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈${RESET}"; }

# --- MENU TEMAS ---
menu_temas() {
    while true; do
        clear
        echo -e "${COLOR3}╔══════════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${COLOR3}║${RESET}  ${I_TEMA} ${BOLD}${COLOR1}SELECTOR DE TEMAS${RESET}  ${GRIS}:: actual: ${COLOR1}${NOMBRE_TEMA}${RESET}${COLOR3}             ║${RESET}"
        echo -e "${COLOR3}╚══════════════════════════════════════════════════════════════╝${RESET}"
        echo ""
        echo -e "  \033[38;5;46m[1]${RESET}  🟩 MATRIX    ${GRIS}── verde neón clásico${RESET}"
        echo -e "  \033[38;5;135m[2]${RESET}  🟣 PÚRPURA   ${GRIS}── oscuro y elegante${RESET}"
        echo -e "  \033[38;5;196m[3]${RESET}  🔴 ROJO      ${GRIS}── peligro total${RESET}"
        echo -e "  \033[38;5;39m[4]${RESET}  🔵 AZUL      ${GRIS}── frío y técnico${RESET}"
        echo -e "  \033[38;5;226m[5]${RESET}  🟡 DORADO    ${GRIS}── cálido y poderoso${RESET}"
        echo -e "  \033[38;5;51m[6]${RESET}  🩵 CYAN      ${GRIS}── hielo y tecnología${RESET}"
        echo -e "  \033[38;5;213m[7]${RESET}  🩷 ROSA      ${GRIS}── vibrante y llamativo${RESET}"
        echo -e "  \033[38;5;214m[8]${RESET}  🟠 NARANJA   ${GRIS}── energía y fuego${RESET}"
        echo -e "  \033[38;5;255m[9]${RESET}  ⬜ BLANCO    ${GRIS}── limpio y minimalista${RESET}"
        echo -e "  \033[38;5;195m[10]${RESET} 🧊 HIELO     ${GRIS}── azul polar helado${RESET}"
        echo -e "  \033[38;5;202m[11]${RESET} 🔥 FUEGO     ${GRIS}── rojo naranja ardiente${RESET}"
        echo -e "  \033[38;5;201m[12]${RESET} 💜 NEÓN      ${GRIS}── rosa neón oscuro${RESET}"
        echo -e "  \033[38;5;45m[13]${RESET}  🌊 OCÉANO    ${GRIS}── azul profundo marino${RESET}"
        echo -e "  \033[38;5;124m[14]${RESET} 🩸 SANGRE    ${GRIS}── rojo oscuro intenso${RESET}"
        echo -e "  \033[38;5;183m[15]${RESET} 🌌 GALAXIA   ${GRIS}── violeta espacial${RESET}"
        echo -e "  \033[38;5;154m[16]${RESET} ☢️  TOXIC     ${GRIS}── verde radioactivo${RESET}"
        echo -e "  \033[38;5;118m[17]${RESET} 💚 NEÓN VERDE ${GRIS}── verde eléctrico brillante${RESET}"
        echo ""
        echo -e "  ${GRIS}[0]${RESET}  ${I_BACK} Volver"
        echo -ne "\n  ${I_ALIEN} : "; read -r op
        local nuevo_tema=""
        case $op in
            1) nuevo_tema="matrix" ;; 2) nuevo_tema="purpura" ;; 3) nuevo_tema="rojo" ;;
            4) nuevo_tema="azul" ;; 5) nuevo_tema="dorado" ;; 6) nuevo_tema="cyan" ;;
            7) nuevo_tema="rosa" ;; 8) nuevo_tema="naranja" ;; 9) nuevo_tema="blanco" ;;
            10) nuevo_tema="hielo" ;; 11) nuevo_tema="fuego" ;; 12) nuevo_tema="neon" ;;
            13) nuevo_tema="oceano" ;; 14) nuevo_tema="sangre" ;; 15) nuevo_tema="galaxia" ;;
            16) nuevo_tema="toxic" ;; 17) nuevo_tema="neonverde" ;; 0) return ;;
        esac
        if [ -n "$nuevo_tema" ]; then
            echo "$nuevo_tema" > "$TEMA_FILE"
            aplicar_tema "$nuevo_tema"
            echo -e "\n  ${I_CHECK} ${COLOR1}Tema ${NOMBRE_TEMA} aplicado y guardado.${RESET}"
            sleep 1; return
        fi
    done
}

# --- ESTADÍSTICAS DE CARPETA ---
estadisticas_carpeta() {
    clear
    local r="$(pwd)"
    sep_top
    echo -e "${COLOR3}║${RESET}  📊 ${BOLD}${COLOR1}ESTADÍSTICAS DE CARPETA${RESET}${COLOR3}                                      ║${RESET}"
    sep_bot
    echo -e "  ${COLOR4}📍 Ruta:${RESET}       ${GRIS2}$r${RESET}"
    echo ""
    local total_peso=$(du -sh . 2>/dev/null | awk '{print $1}')
    local total_archivos=$(find . -maxdepth 1 -type f | wc -l)
    local total_dirs=$(find . -maxdepth 1 -type d | grep -v "^\.$" | wc -l)
    local total_ocultos=$(find . -maxdepth 1 -name ".*" ! -name "." | wc -l)
    local total_scripts=$(find . -maxdepth 1 -type f \( -name "*.sh" -o -name "*.py" -o -name "*.pl" -o -name "*.rb" \) | wc -l)
    local ejecutables=$(find . -maxdepth 1 -type f -perm /111 | wc -l)
    local archivo_grande=$(find . -maxdepth 1 -type f -printf '%s %f\n' 2>/dev/null | sort -rn | head -1)
    local archivo_reciente=$(find . -maxdepth 1 -type f -printf '%T@ %f\n' 2>/dev/null | sort -rn | head -1 | awk '{print $2}')
    local disco_libre=$(df -h "$r" 2>/dev/null | awk 'NR==2{print $4}')
    local disco_total=$(df -h "$r" 2>/dev/null | awk 'NR==2{print $2}')
    local disco_uso=$(df -h "$r" 2>/dev/null | awk 'NR==2{print $5}')

    echo -e "  ${COLOR1}💾 Peso total     :${RESET} ${BOLD}${AMARILLO}$total_peso${RESET}"
    echo -e "  ${COLOR1}📄 Archivos       :${RESET} ${COLOR4}$total_archivos${RESET}"
    echo -e "  ${COLOR1}📂 Subcarpetas    :${RESET} ${COLOR4}$total_dirs${RESET}"
    echo -e "  ${COLOR1}👁️  Ocultos        :${RESET} ${GRIS2}$total_ocultos${RESET}"
    echo -e "  ${COLOR1}⚡ Scripts        :${RESET} ${COLOR2}$total_scripts ${GRIS}(.sh .py .pl .rb)${RESET}"
    echo -e "  ${COLOR1}🔓 Ejecutables    :${RESET} ${COLOR2}$ejecutables${RESET}"
    if [ -n "$archivo_grande" ]; then
        local ag_size=$(echo "$archivo_grande" | awk '{print $1}' | numfmt --to=iec 2>/dev/null || echo "$archivo_grande" | awk '{print $1}')
        local ag_name=$(echo "$archivo_grande" | awk '{print $2}')
        echo -e "  ${COLOR1}🏋️  Más pesado     :${RESET} ${NARANJA}$ag_name${RESET} ${GRIS}($ag_size)${RESET}"
    fi
    [ -n "$archivo_reciente" ] && echo -e "  ${COLOR1}🕐 Más reciente   :${RESET} ${COLOR2}$archivo_reciente${RESET}"
    echo ""
    sep_linea
    echo -e "  ${COLOR4}💿 Disco libre    :${RESET} ${BOLD}${COLOR1}$disco_libre${RESET}${GRIS} / $disco_total${RESET}   ${GRIS}(uso: $disco_uso)${RESET}"
    sep_linea
    echo -ne "\n  ${I_ALIEN} Enter para volver..."; read
}

# --- INFO PANEL ---
info_panel() {
    local r="$(pwd)"
    local num_archivos=$(ls -1 "$r" 2>/dev/null | wc -l)
    local fecha=$(date "+%d/%m/%Y %H:%M")

    if [ "$r" == "$ESCRITORIO" ] || [ "$r" == "$HOME_DIR" ]; then
        local disco_libre=$(df -h "$r" 2>/dev/null | awk 'NR==2{print $4}')
        local disco_total=$(df -h "$r" 2>/dev/null | awk 'NR==2{print $2}')
        echo -e "${COLOR3}║${RESET}  ${I_DISCO} ${GRIS2}Disco libre:${RESET} ${BOLD}${COLOR1}$disco_libre${RESET}${GRIS}/$disco_total${RESET}   ${I_ITEMS} ${GRIS2}Items:${RESET} ${BOLD}${COLOR4}$num_archivos${RESET}   ${I_RELOJ} ${GRIS}$fecha${RESET}"
    else
        local carpeta_peso=$(du -sh "$r" 2>/dev/null | awk '{print $1}')
        echo -e "${COLOR3}║${RESET}  📂 ${GRIS2}Carpeta:${RESET} ${BOLD}${COLOR1}$carpeta_peso${RESET}   ${I_ITEMS} ${GRIS2}Items:${RESET} ${BOLD}${COLOR4}$num_archivos${RESET}   ${I_RELOJ} ${GRIS}$fecha${RESET}"
    fi
}

# --- BUSCADOR ---
buscar_archivo() {
    clear
    sep_top
    echo -e "${COLOR3}║${RESET}  ${I_SEARCH} ${BOLD}${COLOR1}BUSCADOR BLEXS${RESET}${COLOR3}                                               ║${RESET}"
    sep_bot
    echo -e "  ${GRIS}Desde: ${GRIS2}$(pwd)${RESET}"
    echo -ne "\n  ${I_ALIEN} ${COLOR1}Buscar:${RESET} "; read -r query
    [ -z "$query" ] && return
    clear
    echo -e "  ${I_SEARCH} ${COLOR4}Resultados:${RESET} ${BOLD}${AMARILLO}\"$query\"${RESET}\n"
    local resultados=()
    mapfile -t resultados < <(find "$(pwd)" -iname "*${query}*" 2>/dev/null | head -30)
    if [ ${#resultados[@]} -eq 0 ]; then
        echo -e "  ${ROJO}${I_WARN} Sin resultados.${RESET}"; sleep 1; return
    fi
    local i=1
    for res in "${resultados[@]}"; do
        if [ -d "$res" ]; then echo -e "  ${COLOR4}[$i]${RESET} ${I_DIR} ${COLOR1}$res${RESET}"
        else echo -e "  ${COLOR2}[$i]${RESET} ${I_DOC} ${GRIS2}$res${RESET}"; fi
        ((i++))
    done
    sep_linea
    echo -ne "  ${I_ALIEN} ${COLOR1}Ir a [#] o Enter para volver:${RESET} "; read -r sel
    if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -le ${#resultados[@]} ]; then
        local target="${resultados[$((sel-1))]}"
        if [ -d "$target" ]; then cd "$target"
        else cd "$(dirname "$target")"; menu_archivo "$target"; fi
    fi
}

# --- SELECCION MULTIPLE ---
menu_seleccion_multiple() {
    local ls_items=()
    if $VER_OCULTOS; then
        mapfile -t ls_items < <(ls -1a --group-directories-first | grep -v "^\.$\|^\.\.$")
    else
        mapfile -t ls_items < <(ls -1 --group-directories-first)
    fi
    if [ ${#ls_items[@]} -eq 0 ]; then echo -e "  ${ROJO}Carpeta vacía.${RESET}"; sleep 1; return; fi
    local marcados=()
    for item in "${ls_items[@]}"; do marcados+=("0"); done

    while true; do
        clear
        sep_top
        echo -e "${COLOR3}║${RESET}  ${I_MULTI} ${BOLD}${COLOR1}SELECCIÓN MÚLTIPLE${RESET}  ${GRIS}│ [#] marcar  [A] todos  [N] ninguno  [0] salir${RESET}"
        local total_sel=$(echo "${marcados[@]}" | tr ' ' '\n' | grep -c 1)
        echo -e "${COLOR3}║${RESET}  ${BOLD}${COLOR4}$total_sel${RESET} ${GRIS2}seleccionado(s)${RESET}"
        sep_bot
        sep_linea
        local i=1
        for x in "${ls_items[@]}"; do
            local marca="${GRIS}${I_VACIO}${RESET}"
            [[ "${marcados[$((i-1))]}" == "1" ]] && marca="${COLOR1}${I_MARCA}${RESET}"
            if [ -d "$x" ]; then echo -e "  ${COLOR4}[$i]${RESET} [$marca] ${I_DIR} ${BOLD}${COLOR1}$x${RESET}"
            else echo -e "  ${COLOR2}[$i]${RESET} [$marca] ${I_DOC} ${GRIS2}$x${RESET}"; fi
            ((i++))
        done
        sep_linea
        echo -e "  ${ROJO}[D]${RESET} ${I_TRASH} Borrar   ${COLOR1}[C]${RESET} ${I_COPY} Copiar   ${AMARILLO}[M]${RESET} ${I_MOVE} Mover   ${COLOR4}[Z]${RESET} ${I_ZIP} Zip"
        echo -ne "\n  ${I_ALIEN} : "; read -r op

        if [[ "$op" =~ ^[0-9]+$ ]] && [ "$op" -ge 1 ] && [ "$op" -le ${#ls_items[@]} ]; then
            local idx=$((op-1))
            [[ "${marcados[$idx]}" == "0" ]] && marcados[$idx]="1" || marcados[$idx]="0"
        elif [[ "$op" == "A" || "$op" == "a" ]]; then
            for j in "${!marcados[@]}"; do marcados[$j]="1"; done
        elif [[ "$op" == "N" || "$op" == "n" ]]; then
            for j in "${!marcados[@]}"; do marcados[$j]="0"; done
        elif [[ "$op" == "0" ]]; then return
        elif [[ "$op" == "D" || "$op" == "d" ]]; then
            echo -ne "  ${ROJO}${I_WARN} ¿Borrar seleccionados? [s/n]:${RESET} "; read -r conf
            if [[ "$conf" == "s" ]]; then
                for j in "${!ls_items[@]}"; do [[ "${marcados[$j]}" == "1" ]] && rm -rf "${ls_items[$j]}"; done
                echo -e "  ${COLOR1}${I_CHECK} Eliminado.${RESET}"; sleep 1; return
            fi
        elif [[ "$op" == "C" || "$op" == "c" ]]; then
            echo -ne "  ${COLOR1}${I_RUTA} Destino:${RESET} "; read -r dest
            [ -d "$dest" ] || mkdir -p "$dest"
            for j in "${!ls_items[@]}"; do [[ "${marcados[$j]}" == "1" ]] && cp -r "${ls_items[$j]}" "$dest/"; done
            echo -e "  ${COLOR1}${I_CHECK} Copiado.${RESET}"; sleep 1; return
        elif [[ "$op" == "M" || "$op" == "m" ]]; then
            echo -ne "  ${AMARILLO}${I_RUTA} Destino:${RESET} "; read -r dest
            [ -d "$dest" ] || mkdir -p "$dest"
            for j in "${!ls_items[@]}"; do [[ "${marcados[$j]}" == "1" ]] && mv "${ls_items[$j]}" "$dest/"; done
            echo -e "  ${COLOR1}${I_CHECK} Movido.${RESET}"; sleep 1; return
        elif [[ "$op" == "Z" || "$op" == "z" ]]; then
            echo -ne "  ${COLOR4}${I_ZIP} Nombre del zip:${RESET} "; read -r znombre
            local zfiles=()
            for j in "${!ls_items[@]}"; do [[ "${marcados[$j]}" == "1" ]] && zfiles+=("${ls_items[$j]}"); done
            zip -r "${znombre}.zip" "${zfiles[@]}"
            echo -e "  ${COLOR1}${I_CHECK} Zip creado.${RESET}"; sleep 1; return
        fi
    done
}

# --- AIRDROP CON TÚNEL GLOBAL ---
compartir_web_qr_airdrop() {
    local ip; ip=$(hostname -I | awk '{print $1}')
    local port=8000
    if [ -z "$ip" ]; then echo -e "  ${ROJO}Sin red.${RESET}"; read; return; fi

    # Matar cualquier proceso previo en el puerto
    fuser -k $port/tcp >/dev/null 2>&1
    sleep 0.5

    local CARPETA_ACTUAL="$(pwd)"

cat << 'PY_EOF' > /tmp/blexs_airdrop.py
#!/usr/bin/env python3
import http.server, os, sys, zipfile, io, urllib.parse, re

# Recibir carpeta como argumento (evita problemas con cwd de root/sudo)
if len(sys.argv) > 1:
    BASE_DIR = os.path.abspath(sys.argv[1])
else:
    BASE_DIR = os.getcwd()

os.chdir(BASE_DIR)

CSS = """
*{box-sizing:border-box;margin:0;padding:0}
body{background:#000;color:#00ff41;font-family:'Courier New',monospace;padding:20px;min-height:100vh}
h1{color:#00ff41;font-size:1.6em;text-shadow:0 0 7px #00ff41,0 0 20px #00ff41,0 0 40px #00cc33,0 0 80px #009922;margin-bottom:4px;text-align:center;letter-spacing:2px}
.sub{color:#00cc33;font-size:0.8em;text-align:center;margin-bottom:16px;text-shadow:0 0 5px #00cc33}
.box{border:1px solid #00ff41;padding:16px;border-radius:6px;max-width:600px;margin:0 auto;box-shadow:0 0 15px #00ff4144,0 0 40px #00ff4118,inset 0 0 30px #00ff4108;background:#000a00}
.upload-area{border:1px dashed #00ff41;padding:14px;margin-bottom:14px;border-radius:4px;box-shadow:inset 0 0 15px #00ff4110}
input[type=file]{width:100%;color:#00ff41;background:#001a00;border:1px solid #00ff41;padding:10px;border-radius:3px;cursor:pointer;margin-bottom:8px;text-shadow:0 0 5px #00ff41}
.btn{background:#00ff41;color:#000;border:none;padding:12px;width:100%;font-weight:bold;font-size:0.95em;cursor:pointer;border-radius:3px;letter-spacing:2px;box-shadow:0 0 15px #00ff4166,0 0 30px #00ff4133;transition:all 0.2s}
.btn:hover{background:#44ff77;box-shadow:0 0 20px #00ff41aa,0 0 50px #00ff4155;transform:scale(1.01)}
.btn-zip{background:#001a00;color:#00ff41;border:1px solid #00ff41;padding:12px;width:100%;font-weight:bold;font-size:0.9em;cursor:pointer;border-radius:3px;letter-spacing:2px;margin-bottom:12px;display:block;text-align:center;text-decoration:none;box-shadow:0 0 10px #00ff4122;transition:all 0.2s;text-shadow:0 0 5px #00ff41}
.btn-zip:hover{background:#00ff41;color:#000;box-shadow:0 0 20px #00ff4188;text-shadow:none}
.file-list{margin-top:8px}
.file-row{display:flex;align-items:center;justify-content:space-between;padding:8px 6px;border-bottom:1px solid #003300;transition:background 0.15s}
.file-row:hover{background:#001a00;box-shadow:inset 0 0 10px #00ff4110}
.fname{color:#00ff41;font-size:0.85em;word-break:break-all;flex:1;text-shadow:0 0 3px #00ff4188}
.fsize{color:#006600;font-size:0.75em;margin:0 10px;white-space:nowrap}
.fdir{color:#00ffcc;font-size:0.85em;flex:1;text-shadow:0 0 5px #00ffcc66}
.dl-btn{background:#001a00;color:#00ffcc;border:1px solid #00ffcc;padding:5px 12px;font-size:0.75em;cursor:pointer;border-radius:3px;text-decoration:none;white-space:nowrap;box-shadow:0 0 8px #00ffcc22;transition:all 0.2s;text-shadow:0 0 3px #00ffcc}
.dl-btn:hover{background:#00ffcc;color:#000;box-shadow:0 0 15px #00ffcc88;text-shadow:none}
.section-title{color:#005500;font-size:0.75em;padding:6px 4px;letter-spacing:3px;margin-top:8px;text-shadow:0 0 3px #00550066}
@keyframes glow{0%,100%{box-shadow:0 0 15px #00ff4144,0 0 40px #00ff4118}50%{box-shadow:0 0 20px #00ff4166,0 0 60px #00ff4128}}
.box{animation:glow 3s ease-in-out infinite}
"""

def human_size(b):
    for u in ['B','KB','MB','GB']:
        if b < 1024: return f"{b:.1f} {u}"
        b /= 1024
    return f"{b:.1f} TB"

def parse_multipart(rfile, content_type, content_length):
    boundary = None
    for part in content_type.split(';'):
        part = part.strip()
        if part.startswith('boundary='):
            boundary = part[9:].strip('"')
            break
    if not boundary:
        return None, None
    raw = rfile.read(content_length)
    boundary_bytes = ('--' + boundary).encode()
    parts = raw.split(boundary_bytes)
    for part in parts:
        if b'filename="' not in part:
            continue
        header_end = part.find(b'\r\n\r\n')
        if header_end == -1:
            continue
        header = part[:header_end].decode('utf-8', errors='replace')
        body = part[header_end+4:]
        if body.endswith(b'\r\n'):
            body = body[:-2]
        if body.endswith(b'--\r\n'):
            body = body[:-4]
        if body.endswith(b'--'):
            body = body[:-2]
        m = re.search(r'filename="([^"]+)"', header)
        if m:
            return m.group(1), body
    return None, None

class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args): pass

    def do_GET(self):
        path = urllib.parse.unquote(self.path.split('?')[0])
        if path == '/zipall':
            buf = io.BytesIO()
            with zipfile.ZipFile(buf, 'w', zipfile.ZIP_DEFLATED) as zf:
                for root, dirs, files in os.walk(BASE_DIR):
                    for f in files:
                        fp = os.path.join(root, f)
                        zf.write(fp, os.path.relpath(fp, BASE_DIR))
            buf.seek(0); data = buf.read()
            nombre_zip = os.path.basename(BASE_DIR) + '.zip'
            self.send_response(200)
            self.send_header('Content-Type', 'application/zip')
            self.send_header('Content-Disposition', f'attachment; filename="{nombre_zip}"')
            self.send_header('Content-Length', str(len(data)))
            self.end_headers(); self.wfile.write(data); return

        if path.startswith('/dl/'):
            rel = path[4:]
            fp = os.path.normpath(os.path.join(BASE_DIR, rel))
            if not fp.startswith(BASE_DIR): self.send_error(403); return
            if os.path.isfile(fp):
                with open(fp, 'rb') as f: data = f.read()
                fname = os.path.basename(fp)
                self.send_response(200)
                self.send_header('Content-Type', 'application/octet-stream')
                self.send_header('Content-Disposition', f'attachment; filename="{fname}"')
                self.send_header('Content-Length', str(len(data)))
                self.end_headers(); self.wfile.write(data)
            else: self.send_error(404)
            return

        if path == '/' or path == '/subir':
            entries = sorted(os.scandir(BASE_DIR), key=lambda e: (not e.is_dir(), e.name.lower()))
            rows = ''
            for e in entries:
                if e.name.startswith('.'): continue
                if e.is_dir():
                    rows += f'<div class="file-row"><span class="fdir">📂 {e.name}/</span></div>'
                else:
                    try:
                        sz = human_size(e.stat().st_size)
                    except:
                        sz = "?"
                    enc_name = urllib.parse.quote(e.name)
                    rows += f'<div class="file-row"><span class="fname">📄 {e.name}</span><span class="fsize">{sz}</span><a class="dl-btn" href="/dl/{enc_name}">⬇ BAJAR</a></div>'
            html = f"""<!DOCTYPE html><html lang="es"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<style>{CSS}</style></head>
<body><div class="box">
<h1>👽 BLEXS AIRDROP</h1>
<p class="sub">// TRANSFERENCIA SEGURA //</p>
<a class="btn-zip" href="/zipall">🗜️  COMPRIMIR TODO Y DESCARGAR</a>
<div class="upload-area">
<form enctype="multipart/form-data" method="POST" action="/subir">
<input type="file" name="file" required>
<button class="btn" type="submit">&gt; SUBIR ARCHIVO &lt;</button>
</form></div>
<div class="file-list">
<div class="section-title">── ARCHIVOS EN CARPETA ──</div>
{rows if rows else '<div style="color:#003300;padding:10px;text-align:center">~ vacío ~</div>'}
</div></div></body></html>"""
            data = html.encode('utf-8')
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.send_header('Content-Length', str(len(data)))
            self.end_headers(); self.wfile.write(data); return
        self.send_error(404)

    def do_POST(self):
        if self.path != '/subir': self.send_error(404); return
        try:
            content_type = self.headers.get('Content-Type', '')
            content_length = int(self.headers.get('Content-Length', 0))
            filename, filedata = parse_multipart(self.rfile, content_type, content_length)
            if filename and filedata:
                fn = os.path.basename(filename)
                filepath = os.path.join(BASE_DIR, fn)
                with open(filepath, 'wb') as f:
                    f.write(filedata)
                os.chmod(filepath, 0o666)
                html = "<html><body style='background:#000;color:#00ff41;text-align:center;font-family:monospace;padding:40px'><h1>[ RECIBIDO OK ]</h1><p>" + fn + "</p><script>setTimeout(function(){window.location.href='/'},2000);</script></body></html>"
            else:
                html = "<html><body style='background:#000;color:#ff4444;text-align:center;font-family:monospace;padding:40px'><h1>[ ERROR ]</h1><script>setTimeout(function(){window.location.href='/'},2000);</script></body></html>"
            data = html.encode('utf-8')
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.send_header('Content-Length', str(len(data)))
            self.end_headers(); self.wfile.write(data)
        except Exception as e:
            print(f"Upload error: {e}", file=sys.stderr)

if __name__ == '__main__':
    import threading
    class ThreadedServer(http.server.HTTPServer):
        allow_reuse_address = True
        daemon_threads = True
        def process_request(self, request, client_address):
            t = threading.Thread(target=self.process_request_thread, args=(request, client_address))
            t.daemon = True
            t.start()
        def process_request_thread(self, request, client_address):
            try:
                self.finish_request(request, client_address)
            except Exception:
                pass
            try:
                self.shutdown_request(request)
            except Exception:
                pass
    try:
        server = ThreadedServer(('0.0.0.0', 8000), Handler)
        print("BLEXS_SERVER_OK", flush=True)
        server.serve_forever()
    except Exception as e:
        print(f"BLEXS_SERVER_FAIL: {e}", flush=True)
        sys.exit(1)
PY_EOF

    # Abrir puerto en firewall (TODOS los métodos posibles)
    $HAS_SUDO ufw allow $port/tcp >/dev/null 2>&1
    $HAS_SUDO iptables -I INPUT -p tcp --dport $port -j ACCEPT 2>/dev/null

    # Lanzar servidor Python con la carpeta como argumento
    python3 /tmp/blexs_airdrop.py "$CARPETA_ACTUAL" > /tmp/blexs_server_log 2>&1 &
    AIRDROP_PID=$!

    # Esperar confirmación (máx 3 seg)
    local srv_ok=false
    for _wait in $(seq 1 6); do
        if grep -q "BLEXS_SERVER_OK" /tmp/blexs_server_log 2>/dev/null; then
            srv_ok=true; break
        fi
        if grep -q "BLEXS_SERVER_FAIL" /tmp/blexs_server_log 2>/dev/null; then
            break
        fi
        sleep 0.5
    done

    if ! $srv_ok; then
        echo -e "  ${ROJO}❌ Servidor no pudo arrancar:${RESET}"
        cat /tmp/blexs_server_log 2>/dev/null
        kill "$AIRDROP_PID" 2>/dev/null; AIRDROP_PID=""
        fuser -k $port/tcp >/dev/null 2>&1
        rm -f /tmp/blexs_airdrop.py /tmp/blexs_server_log
        echo -ne "\n  Enter para volver..."; read; return
    fi

    # Test real: verificar que el servidor responde
    local test_ok=false
    if curl -s --max-time 2 "http://127.0.0.1:$port/" >/dev/null 2>&1; then
        test_ok=true
    fi

    clear
    sep_top
    echo -e "${COLOR3}║${RESET}  ${I_WEB} ${BOLD}${COLOR1}BLEXS AIRDROP${RESET}${COLOR3}                                               ║${RESET}"
    sep_bot
    echo -e "  ${AMARILLO}📂 Carpeta :${RESET} ${BOLD}${COLOR1}$(basename "$CARPETA_ACTUAL")${RESET}"

    if $test_ok; then
        echo -e "  ${COLOR1}${I_CHECK} Servidor activo en puerto $port${RESET}"
    else
        echo -e "  ${AMARILLO}${I_WARN} Servidor lanzado pero no responde al test local${RESET}"
    fi
    echo ""

    # --- RED LOCAL ---
    echo -e "  ${COLOR4}🏠 RED LOCAL:${RESET}"
    echo -e "  ${BOLD}http://$ip:$port${RESET}"
    echo ""
    qrencode -t ANSIUTF8 "http://$ip:$port" 2>/dev/null
    sep_linea
    echo -e "  ${GRIS}Ambos dispositivos deben estar en la misma WiFi.${RESET}"
    echo -e "  ${GRIS}Si no carga, prueba en el navegador del móvil:${RESET}"
    echo -e "  ${BOLD}${COLOR4}http://$ip:$port${RESET}"
    sep_linea

    # --- TÚNEL GLOBAL (pinggy.io — NO requiere cuenta) ---
    echo ""
    echo -e "  ${GRIS}🌍 Creando túnel global (pinggy.io)...${RESET}"
    rm -f /tmp/blexs_tunnel_url /tmp/blexs_tunnel_output

    # Generar SSH key si no existe (pinggy funciona mejor con key)
    if [ ! -f "$HOME_DIR/.ssh/id_rsa" ] && [ ! -f "$HOME_DIR/.ssh/id_ed25519" ]; then
        mkdir -p "$HOME_DIR/.ssh"
        ssh-keygen -t ed25519 -f "$HOME_DIR/.ssh/id_ed25519" -N "" -q 2>/dev/null
    fi

    # Pinggy: si pide password, se responde vacío automáticamente
    # NO usar BatchMode (mata la conexión si pide password)
    # Usamos script -qc para simular terminal sin pipe que rompa el servidor
    script -qc "ssh -p443 \
        -o StrictHostKeyChecking=no \
        -o ConnectTimeout=15 \
        -o ServerAliveInterval=30 \
        -R0:127.0.0.1:$port a.pinggy.io" \
        /dev/null > /tmp/blexs_tunnel_output 2>&1 &
    TUNNEL_PID=$!

    # Esperar URL (máx 15 seg)
    local intentos=0
    local tunnel_url=""
    while [ $intentos -lt 30 ]; do
        if [ -f /tmp/blexs_tunnel_output ]; then
            # Pinggy devuelve: https://xxxxx.a.free.pinggy.link
            tunnel_url=$(grep -oP 'https://[a-zA-Z0-9_-]+\.a\.free\.pinggy\.link' /tmp/blexs_tunnel_output 2>/dev/null | head -1)
            # Fallback: cualquier https://xxx.pinggy.xxx
            [ -z "$tunnel_url" ] && tunnel_url=$(grep -oP 'https://[a-zA-Z0-9._-]+pinggy[a-zA-Z0-9._-]*' /tmp/blexs_tunnel_output 2>/dev/null | head -1)
            # Fallback final: cualquier URL https que no sea pinggy.io
            [ -z "$tunnel_url" ] && tunnel_url=$(grep -oP 'https://[a-zA-Z0-9][a-zA-Z0-9._-]+\.[a-z]{2,}' /tmp/blexs_tunnel_output 2>/dev/null | grep -v "pinggy.io$\|openssh\|ssh" | head -1)
            if [ -n "$tunnel_url" ]; then
                echo "$tunnel_url" > /tmp/blexs_tunnel_url
                echo -e "\n  ${COLOR1}🌍 ACCESO GLOBAL:${RESET} ${BOLD}$tunnel_url${RESET}"
                echo ""
                qrencode -t ANSIUTF8 "$tunnel_url" 2>/dev/null
                echo -e "\n  ${COLOR1}${I_CHECK} Cualquier persona con este link puede acceder (60 min).${RESET}"
                break
            fi
        fi
        if ! kill -0 "$TUNNEL_PID" 2>/dev/null; then break; fi
        sleep 0.5
        ((intentos++))
    done

    if [ -z "$tunnel_url" ]; then
        echo -e "  ${GRIS}${I_WARN} Túnel global no disponible.${RESET}"
        if [ -f /tmp/blexs_tunnel_output ]; then
            local debug_msg=$(head -5 /tmp/blexs_tunnel_output 2>/dev/null | tr '\n' ' ')
            [ -n "$debug_msg" ] && echo -e "  ${DIM}${GRIS}$debug_msg${RESET}"
        fi
        kill "$TUNNEL_PID" 2>/dev/null; TUNNEL_PID=""
    fi

    echo -e "\n  ${ROJO}${I_WARN} Enter para detener servidor.${RESET}"
    read

    # Limpieza completa
    [ -n "$AIRDROP_PID" ] && kill "$AIRDROP_PID" 2>/dev/null; AIRDROP_PID=""
    [ -n "$TUNNEL_PID" ] && kill "$TUNNEL_PID" 2>/dev/null; TUNNEL_PID=""
    fuser -k $port/tcp >/dev/null 2>&1
    rm -f /tmp/blexs_airdrop.py /tmp/blexs_tunnel_url /tmp/blexs_tunnel_output /tmp/blexs_server_log
    echo -e "  ${COLOR1}${I_CHECK} Servidor cerrado.${RESET}"; sleep 1
}

actualizar_git() {
    if [ -d ".git" ]; then
        echo -e "  ${COLOR1}${I_GIT} Actualizando repo...${RESET}"
        if git pull; then echo -e "  ${COLOR1}${I_CHECK} OK.${RESET}"; else echo -e "  ${ROJO}Error en pull.${RESET}"; fi
    else echo -e "  ${ROJO}${I_WARN} No es un repositorio git.${RESET}"; fi; sleep 1
}

menu_archivo() {
    local n=$(basename "$1")
    local f="$(pwd)/$n"
    while true; do
        clear
        sep_top
        echo -e "${COLOR3}║${RESET}  ${I_DOC} ${BOLD}${AMARILLO}$n${RESET}${COLOR3}                                                        ║${RESET}"
        sep_bot
        sep_linea
        echo -e "  ${COLOR1}[1]${RESET} ${I_EDIT}  Editar     ${ROJO}[2]${RESET} ${I_TRASH} Eliminar   ${AMARILLO}[3]${RESET} ${I_RENAME} Renombrar"
        echo -e "  ${COLOR4}[4]${RESET} ${I_PERM}  Permisos   ${NARANJA}[5]${RESET} ${I_CUT} Cortar     ${COLOR2}[6]${RESET} ${I_COPY} Copiar"
        sep_linea
        echo -e "  ${COLOR4}[7]${RESET} ${I_RUN}  Ejecutar   ${COLOR2}[8]${RESET} ${I_OPEN} Abrir     ${AMARILLO}[Z]${RESET} ${I_ZIP} Zip"
        echo -e "  ${COLOR4}[R]${RESET} 📎 Copiar ruta   ${GRIS}[0]${RESET} ${I_BACK} Volver"
        echo -ne "\n  ${I_ALIEN} : "; read -r o
        case $o in
            1)
                if [ -n "$SUDO_USER" ]; then
                    sudo -u "$SUDO_USER" nano "$f"
                else
                    nano "$f"
                fi
                # Restaurar permisos si editó un script
                if [[ "$n" == *.sh || "$n" == *.py ]]; then
                    chmod +x "$f" 2>/dev/null
                fi
                return ;;
            2) rm -rf "$f"; return ;;
            3) echo -ne "  ${AMARILLO}Nuevo nombre:${RESET} "; read -r nn; mv "$f" "$nn"; return ;;
            4) chmod +x "$f"; echo -e "  ${COLOR1}+x aplicado.${RESET}"; sleep 1; return ;;
            5) CLIP_RUTA="$(pwd)/$n"; CLIP_MODO="MOVER"; echo -e "  ${NARANJA}${I_CUT} Cortado.${RESET}"; sleep 1; return ;;
            6) CLIP_RUTA="$(pwd)/$n"; CLIP_MODO="COPIAR"; echo -e "  ${COLOR4}${I_COPY} Copiado.${RESET}"; sleep 1; return ;;
            [zZ]) zip -r "${n}.zip" "$f"; echo -e "  ${COLOR1}${I_CHECK} Zip creado.${RESET}"; sleep 1; return ;;
            7)
                chmod +x "$f"
                clear
                sep_top
                echo -e "${COLOR3}║${RESET}  ${I_RUN} ${BOLD}${COLOR1}EJECUTAR:${RESET} ${AMARILLO}$n${COLOR3}                                          ║${RESET}"
                sep_bot
                echo -e "\n  ${I_SUDO}  ${ROJO}[1]${RESET} Con sudo"
                echo -e "  ${I_NOSUDO} ${COLOR1}[2]${RESET} Sin sudo"
                echo -e "  ${GRIS}     [0]${RESET} Cancelar"
                echo -ne "\n  ${I_ALIEN} : "; read -r modo_exec
                case $modo_exec in
                    1|2)
                        clear
                        echo -e "${COLOR1}═══ EJECUTANDO: $n ═══${RESET}\n"
                        if [[ "$n" == *.py ]]; then
                            [ "$modo_exec" == "1" ] && sudo python3 "$f" || python3 "$f"
                        else
                            [ "$modo_exec" == "1" ] && sudo bash "$f" || bash "$f"
                        fi
                        echo -e "\n${COLOR1}═══ FIN ═══${RESET}"
                        echo -ne "  Enter para volver..."; read
                        ;;
                esac
                return ;;
            8) xdg-open "$f" & return ;;
            [rR])
                local ruta_completa="$(pwd)/$n"
                echo -n "$ruta_completa" | xclip -selection clipboard 2>/dev/null || echo -n "$ruta_completa" | xclip 2>/dev/null
                echo -e "  ${COLOR1}${I_CHECK} Ruta copiada:${RESET} ${GRIS2}$ruta_completa${RESET}"; sleep 1 ;;
            0) return ;;
        esac
    done
}

navegar() {
    while true; do
        clear
        local r="$(pwd)"
        echo -e "${COLOR3}╔══════════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${COLOR3}║${RESET}  ${I_ALIEN} ${BOLD}${COLOR1}GESTOR BLEXS${RESET} ${GRIS}V58.0${RESET}  ${GRIS}::${RESET}  ${I_USER} ${BOLD}${COLOR4}$REAL_USER${RESET}  ${GRIS}│${RESET} ${I_TEMA} ${COLOR2}${NOMBRE_TEMA}${RESET}"
        echo -e "${COLOR3}║${RESET}  ${I_RUTA} ${GRIS2}$r${RESET}"
        info_panel
        mostrar_slots
        echo -e "${COLOR3}╠══════════════════════════════════════════════════════════════╣${RESET}"
        echo -e "${COLOR3}║${RESET}  ${ROJO}[x]${RESET} ${I_EXIT} Salir     ${GRIS}[0]${RESET} ${I_BACK} Atrás     ${COLOR4}[1]${RESET} ${I_HOME} Escritorio ${GRIS2}($(basename "$ESCRITORIO"))${RESET}"
        echo -e "${COLOR3}║${RESET}  ${COLOR1}[2]${RESET} ${I_PLUS_DIR} Crear Dir  ${COLOR2}[3]${RESET} ${I_PLUS_FILE} Crear File  ${AMARILLO}[/]${RESET} ${I_SEARCH} Buscar"
        echo -e "${COLOR3}║${RESET}  ${COLOR4}[6]${RESET} ${I_COPY} Copiar Dir  ${COLOR4}[7]${RESET} ${I_MOVE} Mover Dir  ${ROJO}[9]${RESET} ${I_TRASH} Borrar"
        echo -e "${COLOR3}║${RESET}  ${COLOR1}[W]${RESET} ${I_WEB} Airdrop    ${COLOR1}[T]${RESET} ${I_TEMA} Temas      ${COLOR2}[I]${RESET} 📊 Stats"
        echo -e "${COLOR3}║${RESET}  ${COLOR4}[R]${RESET} 📎 Copiar ruta  ${COLOR1}[O]${RESET} 🖥️  Terminal   ${COLOR4}[B]${RESET} 📁 Thunar"
        [ -d .git ] && echo -e "${COLOR3}║${RESET}  ${GRIS}[G]${RESET} ${I_GIT} Git Update"
        echo -e "${COLOR3}╠══════════════════════════════════════════════════════════════╣${RESET}"
        echo -e "${COLOR3}║${RESET}  ${AMARILLO}[Z]${RESET} ${I_ZIP} Zip   ${COLOR1}[S]${RESET} ${I_MULTI} Selección"
        if [ -n "$CLIP_RUTA" ]; then
            echo -e "${COLOR3}║${RESET}  ${COLOR4}[P]${RESET} ${I_PASTE} ${BOLD}Pegar${RESET} ${GRIS}($CLIP_MODO)${RESET} ${GRIS2}$(basename "$CLIP_RUTA")${RESET}   ${ROJO}[K]${RESET} ${I_CANCEL} Cancelar"
        fi
        echo -e "${COLOR3}╠══════════════════════════════════════════════════════════════╣${RESET}"
        local ls_arr=()
        if $VER_OCULTOS; then
            mapfile -t ls_arr < <(ls -1a --group-directories-first | grep -v "^\.$\|^\.\.$")
        else
            mapfile -t ls_arr < <(ls -1 --group-directories-first)
        fi
        local i=10
        if [ ${#ls_arr[@]} -gt 0 ]; then
            for x in "${ls_arr[@]}"; do
                if [ -d "$x" ]; then
                    echo -e "${COLOR3}║${RESET}  ${COLOR4}[$i]${RESET} ${I_DIR} ${BOLD}${COLOR1}$x${RESET}"
                else
                    echo -e "${COLOR3}║${RESET}  ${COLOR2}[$i]${RESET} ${I_DOC} ${GRIS2}$x${RESET}"
                fi
                ((i++))
            done
        else
            echo -e "${COLOR3}║${RESET}  ${GRIS}  ~ vacío ~${RESET}"
        fi
        echo -e "${COLOR3}╚══════════════════════════════════════════════════════════════╝${RESET}"
        echo -ne "  ${I_ALIEN} : "; read -r i
        case $i in
            # --- SALIR ---
            [xX])
                TERM_PID=$(ps -o ppid= -p $$ | tr -d ' ')
                TERM_PID=$(ps -o ppid= -p $TERM_PID | tr -d ' ')
                kill $TERM_PID 2>/dev/null
                exit ;;
            # --- NAVEGACIÓN ---
            0) cd .. ;;
            1) cd "$ESCRITORIO" ;;
            # --- SLOTS: Saltar (! = Shift+1, " = Shift+2, # = Shift+3) ---
            '!') [ -n "$SLOT1" ] && [ -d "$SLOT1" ] && cd "$SLOT1" || echo -e "  ${GRIS}Slot 1 vacío.${RESET}" ;;
            '"') [ -n "$SLOT2" ] && [ -d "$SLOT2" ] && cd "$SLOT2" || echo -e "  ${GRIS}Slot 2 vacío.${RESET}" ;;
            '#') [ -n "$SLOT3" ] && [ -d "$SLOT3" ] && cd "$SLOT3" || echo -e "  ${GRIS}Slot 3 vacío.${RESET}" ;;
            # --- SLOTS: Guardar ---
            m1) SLOT1="$(pwd)"; guardar_slots; echo -e "  ${COLOR1}${I_CHECK} Slot 1 → $(basename "$(pwd)")${RESET}"; sleep 1 ;;
            m2) SLOT2="$(pwd)"; guardar_slots; echo -e "  ${COLOR1}${I_CHECK} Slot 2 → $(basename "$(pwd)")${RESET}"; sleep 1 ;;
            m3) SLOT3="$(pwd)"; guardar_slots; echo -e "  ${COLOR1}${I_CHECK} Slot 3 → $(basename "$(pwd)")${RESET}"; sleep 1 ;;
            # --- SLOTS: Limpiar ---
            k1) SLOT1=""; guardar_slots; echo -e "  ${GRIS}Slot 1 limpio.${RESET}"; sleep 1 ;;
            k2) SLOT2=""; guardar_slots; echo -e "  ${GRIS}Slot 2 limpio.${RESET}"; sleep 1 ;;
            k3) SLOT3=""; guardar_slots; echo -e "  ${GRIS}Slot 3 limpio.${RESET}"; sleep 1 ;;
            # --- ACCIONES DE SISTEMA (letras) ---
            2) echo -ne "  ${COLOR1}Nombre carpeta:${RESET} "; read -r n; mkdir -p "$n" ;;
            3) echo -ne "  ${COLOR1}Nombre archivo:${RESET} "; read -r n; touch "$n" ;;
            [tT]) menu_temas ;;
            [iI]) estadisticas_carpeta ;;
            [oO]) xfce4-terminal --working-directory="$(pwd)" & ;;
            [bB]) thunar "$(pwd)" & ;;
            [rR])
                echo -n "$r" | xclip -selection clipboard 2>/dev/null || echo -n "$r" | xclip 2>/dev/null
                echo -e "  ${COLOR1}${I_CHECK} Ruta copiada:${RESET} ${GRIS2}$r${RESET}"; sleep 1 ;;
            [zZ]) zip -r "$(basename "$r").zip" .; echo -e "  ${COLOR1}${I_CHECK} Zip creado.${RESET}"; sleep 1 ;;
            [wW]) compartir_web_qr_airdrop ;;
            [gG]) actualizar_git ;;
            "/") buscar_archivo ;;
            [sS]) menu_seleccion_multiple ;;
            # --- PORTAPAPELES ---
            [pP])
                if [ -n "$CLIP_RUTA" ]; then
                    [[ "$CLIP_MODO" == "COPIAR" ]] && cp -r "$CLIP_RUTA" . || mv "$CLIP_RUTA" .
                    echo -e "  ${COLOR1}${I_CHECK} Pegado OK.${RESET}"; sleep 1; CLIP_RUTA=""
                fi ;;
            [kK]) CLIP_RUTA=""; echo -e "  ${GRIS}Portapapeles limpio.${RESET}"; sleep 1 ;;
            6) CLIP_RUTA="$(pwd)"; CLIP_MODO="COPIAR"; echo -e "  ${COLOR4}${I_COPY} Dir en portapapeles.${RESET}"; sleep 1 ;;
            7) CLIP_RUTA="$(pwd)"; CLIP_MODO="MOVER"; echo -e "  ${AMARILLO}${I_MOVE} Dir listo para mover.${RESET}"; sleep 1 ;;
            9)
                echo -ne "  ${ROJO}${I_WARN} ¿Borrar carpeta ACTUAL? [s/n]:${RESET} "; read -r c
                if [[ "$c" == "s" ]]; then cd ..; rm -rf "$r"; echo -e "  ${COLOR1}Eliminado.${RESET}"; sleep 1
                else echo -e "  ${GRIS}Cancelado.${RESET}"; sleep 1; fi ;;
            # --- ARCHIVOS (números >= 10) ---
            *)
                if [[ "$i" =~ ^[0-9]+$ ]] && [ "$i" -ge 10 ]; then
                    local s="${ls_arr[$((i-10))]}"
                    [ -d "$s" ] && cd "$s" || menu_archivo "$s"
                fi ;;
        esac
    done
}

# --- INICIO ---
cargar_tema
cargar_slots
navegar
# Creado por BLEXS
EOF_PAYLOAD

chmod +x "$TARGET"

if [ ! -f /usr/local/bin/go ] && [ ! -L /usr/local/bin/go ]; then
    ln -s "$TARGET" /usr/local/bin/go
    echo -e "\033[38;5;46m[👽] BLEXS V58.0 INSTALADO. USA 'go' PARA ENTRAR.\033[0m"
else
    rm -f /usr/local/bin/go
    ln -s "$TARGET" /usr/local/bin/go
    echo -e "\033[38;5;46m[👽] COMANDO 'go' ACTUALIZADO A V58.0.\033[0m"
fi
