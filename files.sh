#!/bin/bash

# ==========================================
# INSTALADOR GESTOR BLEXS V57.7 - TEMAS
# ==========================================

if [ "$EUID" -ne 0 ]; then 
    echo -e "\033[1;32m[!] ERROR: Ejecuta con sudo: sudo ./br.sh\033[0m"
    exit 1
fi

echo -e "\033[38;5;46m[👽] Instalando BLEXS V57.7...\033[0m"

PKGS="zip xclip python3-pip ntfs-3g exfat-fuse exfatprogs rsync parted gdisk rename qrencode git psmisc xdg-user-dirs"
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
I_CHECK="✅";   I_USB="🔌";     I_FIX="🔩";     I_WARN="⚠️ ";  I_STAR="🌟"
I_PLUS_DIR="➕📂"; I_PLUS_FILE="➕📄"; I_COPY="📋"; I_MOVE="📦"
I_TRASH="🗑️ "; I_EDIT="📝";    I_RENAME="✏️ "; I_PERM="🔓";   I_RUN="▶️ "
I_OPEN="🌐";   I_PASTE="📌";   I_POWER="⚡";   I_EJECT="⏏️ "; I_CANCEL="✖️ "
I_CUT="✂️ ";   I_ZIP="🗜️ ";   I_EYE="🔎";    I_WEB="🌐";    I_GIT="🐙"
I_SEARCH="🔍"; I_MULTI="☑️ "; I_DISCO="💿";  I_RELOJ="⏱️ "; I_ITEMS="🗂️ "
I_RUTA="📍";   I_USER="👤";   I_SUDO="🔴";   I_NOSUDO="🟢"; I_MARCA="▶"
I_VACIO="·";   I_LOCK="🔒";   I_SYNC="🔄";   I_TEMA="🎨"

# --- VARIABLES ---
CLIP_USB_SRC=""; CLIP_USB_TYPE=""; DEV_SELECCIONADO=""; DEV_PADRE=""
CLIP_RUTA=""; CLIP_MODO=""; VER_OCULTOS=false
TEMA_FILE="$HOME/.blexs_tema"

if [ -n "$SUDO_USER" ]; then REAL_USER="$SUDO_USER"; HOME_DIR=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else REAL_USER=$(whoami); HOME_DIR="$HOME"; fi

HAS_SUDO=""; if [ "$(id -u)" != "0" ]; then HAS_SUDO="sudo"; fi
TEMA_FILE="$HOME_DIR/.blexs_tema"

# ================= DETECCIÓN INTELIGENTE DE ESCRITORIO =================
detectar_escritorio() {
    # Recopilar TODOS los candidatos posibles (no retornar temprano)
    local candidatos=()

    # 1. xdg-user-dir con el usuario REAL (no root)
    local xdg=""
    if [ -n "$SUDO_USER" ]; then
        xdg=$(sudo -u "$SUDO_USER" xdg-user-dir DESKTOP 2>/dev/null)
    else
        xdg=$(xdg-user-dir DESKTOP 2>/dev/null)
    fi
    # Agregar xdg como candidato si apunta a HOME_DIR
    if [ -n "$xdg" ] && [ -d "$xdg" ] && [[ "$xdg" == "$HOME_DIR"* ]]; then
        candidatos+=("$xdg")
    fi

    # 2. Nombres conocidos en múltiples idiomas
    local nombres=("Desktop" "Escritorio" "Bureau" "Schreibtisch" "Skrivbord" "Bureaublad" "桌面")
    for n in "${nombres[@]}"; do
        local c="$HOME_DIR/$n"
        if [ -d "$c" ]; then
            # Evitar duplicados con lo que ya tenemos
            local ya=false
            for ex in "${candidatos[@]}"; do [ "$ex" == "$c" ] && ya=true; done
            $ya || candidatos+=("$c")
        fi
    done

    # 3. Búsqueda dinámica por patrón (por si tiene un nombre raro)
    while IFS= read -r found; do
        [ -z "$found" ] && continue
        local ya=false
        for ex in "${candidatos[@]}"; do [ "$ex" == "$found" ] && ya=true; done
        $ya || candidatos+=("$found")
    done < <(find "$HOME_DIR" -maxdepth 1 -type d \
        \( -iname "*desktop*" -o -iname "*escritorio*" -o -iname "*bureau*" \) 2>/dev/null)

    # 4. Elegir la que tenga MÁS contenido (archivos + carpetas)
    local mejor="" mejor_count=-1
    for c in "${candidatos[@]}"; do
        local count
        count=$(ls -1A "$c" 2>/dev/null | wc -l)
        if [ "$count" -gt "$mejor_count" ]; then
            mejor_count=$count
            mejor="$c"
        fi
    done

    # Si encontramos alguna con contenido, usarla
    if [ -n "$mejor" ] && [ "$mejor_count" -gt 0 ]; then
        echo "$mejor"; return
    fi

    # Si todas están vacías, preferir la de xdg
    if [ -n "$xdg" ] && [ -d "$xdg" ] && [[ "$xdg" == "$HOME_DIR"* ]]; then
        echo "$xdg"; return
    fi

    # Si hay algún candidato, usar el primero
    [ ${#candidatos[@]} -gt 0 ] && echo "${candidatos[0]}" && return

    # Último recurso
    echo "$HOME_DIR"
}

ESCRITORIO=$(detectar_escritorio)

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
            COLOR1='\033[38;5;46m'
            COLOR2='\033[38;5;40m'
            COLOR3='\033[38;5;34m'
            COLOR4='\033[38;5;51m'
            COLOR5='\033[38;5;22m'
            NOMBRE_TEMA="🟩 MATRIX"
            ;;
        purpura)
            COLOR1='\033[38;5;135m'
            COLOR2='\033[38;5;99m'
            COLOR3='\033[38;5;93m'
            COLOR4='\033[38;5;213m'
            COLOR5='\033[38;5;55m'
            NOMBRE_TEMA="🟣 PÚRPURA"
            ;;
        rojo)
            COLOR1='\033[38;5;196m'
            COLOR2='\033[38;5;160m'
            COLOR3='\033[38;5;124m'
            COLOR4='\033[38;5;208m'
            COLOR5='\033[38;5;88m'
            NOMBRE_TEMA="🔴 ROJO"
            ;;
        azul)
            COLOR1='\033[38;5;39m'
            COLOR2='\033[38;5;33m'
            COLOR3='\033[38;5;27m'
            COLOR4='\033[38;5;51m'
            COLOR5='\033[38;5;17m'
            NOMBRE_TEMA="🔵 AZUL"
            ;;
        dorado)
            COLOR1='\033[38;5;226m'
            COLOR2='\033[38;5;220m'
            COLOR3='\033[38;5;178m'
            COLOR4='\033[38;5;214m'
            COLOR5='\033[38;5;136m'
            NOMBRE_TEMA="🟡 DORADO"
            ;;
        cyan)
            COLOR1='\033[38;5;51m'
            COLOR2='\033[38;5;45m'
            COLOR3='\033[38;5;37m'
            COLOR4='\033[38;5;46m'
            COLOR5='\033[38;5;23m'
            NOMBRE_TEMA="🩵 CYAN"
            ;;
        rosa)
            COLOR1='\033[38;5;213m'
            COLOR2='\033[38;5;205m'
            COLOR3='\033[38;5;162m'
            COLOR4='\033[38;5;51m'
            COLOR5='\033[38;5;89m'
            NOMBRE_TEMA="🩷 ROSA"
            ;;
        naranja)
            COLOR1='\033[38;5;214m'
            COLOR2='\033[38;5;208m'
            COLOR3='\033[38;5;166m'
            COLOR4='\033[38;5;226m'
            COLOR5='\033[38;5;130m'
            NOMBRE_TEMA="🟠 NARANJA"
            ;;
        blanco)
            COLOR1='\033[38;5;255m'
            COLOR2='\033[38;5;250m'
            COLOR3='\033[38;5;244m'
            COLOR4='\033[38;5;51m'
            COLOR5='\033[38;5;238m'
            NOMBRE_TEMA="⬜ BLANCO"
            ;;
        hielo)
            COLOR1='\033[38;5;195m'
            COLOR2='\033[38;5;189m'
            COLOR3='\033[38;5;153m'
            COLOR4='\033[38;5;123m'
            COLOR5='\033[38;5;117m'
            NOMBRE_TEMA="🧊 HIELO"
            ;;
        fuego)
            COLOR1='\033[38;5;202m'
            COLOR2='\033[38;5;214m'
            COLOR3='\033[38;5;130m'
            COLOR4='\033[38;5;220m'
            COLOR5='\033[38;5;94m'
            NOMBRE_TEMA="🔥 FUEGO"
            ;;
        oceano)
            COLOR1='\033[38;5;117m'
            COLOR2='\033[38;5;74m'
            COLOR3='\033[38;5;67m'
            COLOR4='\033[38;5;159m'
            COLOR5='\033[38;5;24m'
            NOMBRE_TEMA="🌊 OCÉANO"
            ;;
        toxic)
            COLOR1='\033[38;5;190m'
            COLOR2='\033[38;5;184m'
            COLOR3='\033[38;5;142m'
            COLOR4='\033[38;5;226m'
            COLOR5='\033[38;5;100m'
            NOMBRE_TEMA="☢️  TOXIC"
            ;;
        neon)
            COLOR1='\033[38;5;201m'
            COLOR2='\033[38;5;198m'
            COLOR3='\033[38;5;162m'
            COLOR4='\033[38;5;123m'
            COLOR5='\033[38;5;89m'
            NOMBRE_TEMA="💜 NEÓN"
            ;;
        sangre)
            COLOR1='\033[38;5;160m'
            COLOR2='\033[38;5;124m'
            COLOR3='\033[38;5;88m'
            COLOR4='\033[38;5;203m'
            COLOR5='\033[38;5;52m'
            NOMBRE_TEMA="🩸 SANGRE"
            ;;
        galaxia)
            COLOR1='\033[38;5;183m'
            COLOR2='\033[38;5;141m'
            COLOR3='\033[38;5;97m'
            COLOR4='\033[38;5;219m'
            COLOR5='\033[38;5;54m'
            NOMBRE_TEMA="🌌 GALAXIA"
            ;;
        *)
            aplicar_tema "matrix"; return ;;
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
        echo ""
        echo -e "  ${GRIS}[0]${RESET}  ${I_BACK} Volver"
        echo -ne "\n  ${I_ALIEN} : "; read -r op
        local nuevo_tema=""
        case $op in
            1) nuevo_tema="matrix" ;;
            2) nuevo_tema="purpura" ;;
            3) nuevo_tema="rojo" ;;
            4) nuevo_tema="azul" ;;
            5) nuevo_tema="dorado" ;;
            6) nuevo_tema="cyan" ;;
            7) nuevo_tema="rosa" ;;
            8) nuevo_tema="naranja" ;;
            9) nuevo_tema="blanco" ;;
            10) nuevo_tema="hielo" ;;
            11) nuevo_tema="fuego" ;;
            12) nuevo_tema="neon" ;;
            13) nuevo_tema="oceano" ;;
            14) nuevo_tema="sangre" ;;
            15) nuevo_tema="galaxia" ;;
            16) nuevo_tema="toxic" ;;
            0) return ;;
        esac
        if [ -n "$nuevo_tema" ]; then
            echo "$nuevo_tema" > "$TEMA_FILE"
            aplicar_tema "$nuevo_tema"
            echo -e "\n  ${I_CHECK} ${COLOR1}Tema ${NOMBRE_TEMA} aplicado y guardado.${RESET}"
            sleep 1
            return
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
        echo -e "  ${COLOR1}🏋️  Más pesado     :${RESET} ${NARANJA}$ag_name${RESET} ${GRIS}($ag_size bytes)${RESET}"
    fi
    [ -n "$archivo_reciente" ] && echo -e "  ${COLOR1}🕐 Más reciente   :${RESET} ${COLOR2}$archivo_reciente${RESET}"
    echo ""
    sep_linea
    echo -e "  ${COLOR4}💿 Disco libre    :${RESET} ${BOLD}${COLOR1}$disco_libre${RESET}${GRIS} / $disco_total${RESET}   ${GRIS}(uso: $disco_uso)${RESET}"
    sep_linea
    echo -ne "\n  ${I_ALIEN} Enter para volver..."; read
}

VISTA_FILE="$HOME_DIR/.blexs_vista"
MODO_VISTA="normal"
[ -f "$VISTA_FILE" ] && MODO_VISTA=$(cat "$VISTA_FILE")

# --- TOGGLE VISTA ---
toggle_vista() {
    if [ "$MODO_VISTA" == "arbol" ]; then
        MODO_VISTA="normal"; echo "normal" > "$VISTA_FILE"
        echo -e "  ${COLOR1}${I_CHECK} Vista: NORMAL${RESET}"; sleep 1
    else
        MODO_VISTA="arbol"; echo "arbol" > "$VISTA_FILE"
        echo -e "  ${COLOR1}${I_CHECK} Vista: ÁRBOL${RESET}"; sleep 1
    fi
}

# --- MODO ÁRBOL INTERACTIVO ---
ARBOL_MAPA=()

_arbol_build() {
    local dir="${1:-.}"
    local prefix="${2:-}"
    local nivel="${3:-0}"
    local max_nivel=3
    [ "$nivel" -ge "$max_nivel" ] && return
    local entries=()
    if $VER_OCULTOS; then
        mapfile -t entries < <(ls -1a --group-directories-first "$dir" 2>/dev/null | grep -v "^\.$\|^\.\.$")
    else
        mapfile -t entries < <(ls -1 --group-directories-first "$dir" 2>/dev/null)
    fi
    local total=${#entries[@]}
    local idx=0
    for entry in "${entries[@]}"; do
        ((idx++))
        local full="$dir/$entry"
        local conector="├──"
        local nuevo_prefix="${prefix}│   "
        [ "$idx" -eq "$total" ] && conector="└──" && nuevo_prefix="${prefix}    "
        local num=${#ARBOL_MAPA[@]}
        ARBOL_MAPA+=("$full")
        if [ -d "$full" ]; then
            echo -e "${COLOR3}║${RESET} ${GRIS}${prefix}${conector}${RESET} ${COLOR4}[${num}]${RESET} ${I_DIR} ${BOLD}${COLOR1}${entry}${RESET}"
            _arbol_build "$full" "$nuevo_prefix" "$((nivel+1))"
        else
            echo -e "${COLOR3}║${RESET} ${GRIS}${prefix}${conector}${RESET} ${COLOR2}[${num}]${RESET} ${I_DOC} ${GRIS2}${entry}${RESET}"
        fi
    done
}

mostrar_arbol() {
    ARBOL_MAPA=()
    _arbol_build "." "" 0
}

navegar_arbol() {
    local sel="$1"
    if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -lt "${#ARBOL_MAPA[@]}" ]; then
        local target="${ARBOL_MAPA[$sel]}"
        target="${target#./}"
        local full_path="$(pwd)/$target"
        if [ -d "$full_path" ]; then
            cd "$full_path"
            return 0
        elif [ -f "$full_path" ]; then
            menu_archivo "$full_path"
            return 0
        fi
    fi
    return 1
}

# --- INFO PANEL ---
info_panel() {
    local r="$(pwd)"
    local num_archivos=$(ls -1 "$r" 2>/dev/null | wc -l)
    local fecha=$(date "+%d/%m/%Y %H:%M")
    local vista_label=""
    [ "$MODO_VISTA" == "arbol" ] && vista_label=" ${GRIS}│ 🌳 ÁRBOL${RESET}"

    if [ "$r" == "$ESCRITORIO" ] || [ "$r" == "$HOME_DIR" ]; then
        local disco_libre=$(df -h "$r" 2>/dev/null | awk 'NR==2{print $4}')
        local disco_total=$(df -h "$r" 2>/dev/null | awk 'NR==2{print $2}')
        echo -e "${COLOR3}║${RESET}  ${I_DISCO} ${GRIS2}Disco libre:${RESET} ${BOLD}${COLOR1}$disco_libre${RESET}${GRIS}/$disco_total${RESET}   ${I_ITEMS} ${GRIS2}Items:${RESET} ${BOLD}${COLOR4}$num_archivos${RESET}   ${I_RELOJ} ${GRIS}$fecha${RESET}${vista_label}"
    else
        local carpeta_peso=$(du -sh "$r" 2>/dev/null | awk '{print $1}')
        echo -e "${COLOR3}║${RESET}  📂 ${GRIS2}Carpeta:${RESET} ${BOLD}${COLOR1}$carpeta_peso${RESET}   ${I_ITEMS} ${GRIS2}Items:${RESET} ${BOLD}${COLOR4}$num_archivos${RESET}   ${I_RELOJ} ${GRIS}$fecha${RESET}${vista_label}"
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

compartir_web_qr_airdrop() {
    local ip; ip=$(hostname -I | awk '{print $1}')
    local port=8000
    if [ -z "$ip" ]; then echo -e "  ${ROJO}Sin red.${RESET}"; read; return; fi
    fuser -k 8000/tcp >/dev/null 2>&1

cat << 'PY_EOF' > /tmp/blexs_airdrop.py
import http.server, os, cgi, sys, zipfile, io, urllib.parse, mimetypes

BASE_DIR = os.getcwd()

CSS = """
*{box-sizing:border-box;margin:0;padding:0}
body{background:#000;color:#00ff41;font-family:'Courier New',monospace;padding:20px;min-height:100vh}
h1{color:#00ff41;font-size:1.4em;text-shadow:0 0 10px #00ff41;margin-bottom:4px;text-align:center}
.sub{color:#00cc33;font-size:0.8em;text-align:center;margin-bottom:16px}
.box{border:1px solid #00ff41;padding:16px;border-radius:4px;max-width:600px;margin:0 auto;box-shadow:0 0 20px #00ff4122}
.upload-area{border:1px dashed #00ff41;padding:14px;margin-bottom:14px;border-radius:4px}
input[type=file]{width:100%;color:#00ff41;background:#001a00;border:1px solid #00ff41;padding:8px;border-radius:2px;cursor:pointer;margin-bottom:8px}
.btn{background:#00ff41;color:#000;border:none;padding:10px;width:100%;font-weight:bold;font-size:0.9em;cursor:pointer;border-radius:2px;letter-spacing:1px}
.btn:hover{background:#00cc33;box-shadow:0 0 10px #00ff41}
.btn-zip{background:#003300;color:#00ff41;border:1px solid #00ff41;padding:10px;width:100%;font-weight:bold;font-size:0.9em;cursor:pointer;border-radius:2px;letter-spacing:1px;margin-bottom:12px;display:block;text-align:center;text-decoration:none}
.btn-zip:hover{background:#00ff41;color:#000}
.file-list{margin-top:8px}
.file-row{display:flex;align-items:center;justify-content:space-between;padding:7px 4px;border-bottom:1px solid #003300}
.file-row:hover{background:#001a00}
.fname{color:#00ff41;font-size:0.85em;word-break:break-all;flex:1}
.fsize{color:#005500;font-size:0.75em;margin:0 10px;white-space:nowrap}
.fdir{color:#00ffff;font-size:0.85em;flex:1}
.dl-btn{background:#003300;color:#00ffff;border:1px solid #00ffff;padding:4px 10px;font-size:0.75em;cursor:pointer;border-radius:2px;text-decoration:none;white-space:nowrap}
.dl-btn:hover{background:#00ffff;color:#000}
.section-title{color:#005500;font-size:0.75em;padding:6px 4px;letter-spacing:2px;margin-top:8px}
"""

def human_size(b):
    for u in ['B','KB','MB','GB']:
        if b < 1024: return f"{b:.1f} {u}"
        b /= 1024
    return f"{b:.1f} TB"

class Handler(http.server.BaseHTTPRequestHandler):

    def log_message(self, format, *args):
        pass

    def do_GET(self):
        path = urllib.parse.unquote(self.path.split('?')[0])

        if path == '/zipall':
            buf = io.BytesIO()
            with zipfile.ZipFile(buf, 'w', zipfile.ZIP_DEFLATED) as zf:
                for root, dirs, files in os.walk(BASE_DIR):
                    for f in files:
                        fp = os.path.join(root, f)
                        zf.write(fp, os.path.relpath(fp, BASE_DIR))
            buf.seek(0)
            data = buf.read()
            nombre_zip = os.path.basename(BASE_DIR) + '.zip'
            self.send_response(200)
            self.send_header('Content-Type', 'application/zip')
            self.send_header('Content-Disposition', f'attachment; filename="{nombre_zip}"')
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return

        if path.startswith('/dl/'):
            rel = path[4:]
            fp = os.path.join(BASE_DIR, rel)
            fp = os.path.normpath(fp)
            if not fp.startswith(BASE_DIR):
                self.send_error(403); return
            if os.path.isfile(fp):
                with open(fp, 'rb') as f: data = f.read()
                fname = os.path.basename(fp)
                self.send_response(200)
                self.send_header('Content-Type', 'application/octet-stream')
                self.send_header('Content-Disposition', f'attachment; filename="{fname}"')
                self.send_header('Content-Length', str(len(data)))
                self.end_headers()
                self.wfile.write(data)
            else:
                self.send_error(404)
            return

        if path == '/' or path == '/subir':
            entries = sorted(os.scandir(BASE_DIR), key=lambda e: (not e.is_dir(), e.name.lower()))
            rows = ''
            for e in entries:
                if e.name.startswith('.'): continue
                if e.is_dir():
                    rows += f'<div class="file-row"><span class="fdir">📂 {e.name}/</span></div>'
                else:
                    sz = human_size(e.stat().st_size)
                    enc_name = urllib.parse.quote(e.name)
                    rows += f'<div class="file-row"><span class="fname">📄 {e.name}</span><span class="fsize">{sz}</span><a class="dl-btn" href="/dl/{enc_name}">⬇ BAJAR</a></div>'

            html = f"""<!DOCTYPE html>
<html lang="es"><head><meta charset="UTF-8">
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
</form>
</div>
<div class="file-list">
<div class="section-title">── ARCHIVOS EN CARPETA ──</div>
{rows if rows else '<div style="color:#003300;padding:10px;text-align:center">~ vacío ~</div>'}
</div>
</div></body></html>"""
            data = html.encode('utf-8')
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return

        self.send_error(404)

    def do_POST(self):
        if self.path != '/subir':
            self.send_error(404); return
        try:
            form = cgi.FieldStorage(fp=self.rfile, headers=self.headers, environ={'REQUEST_METHOD':'POST'})
            if 'file' in form:
                fileitem = form['file']
                if fileitem.filename:
                    fn = os.path.basename(fileitem.filename)
                    with open(os.path.join(BASE_DIR, fn), 'wb') as f:
                        f.write(fileitem.file.read())
                    html = "<html><body style='background:#000;color:#00ff41;text-align:center;font-family:monospace;padding:40px'><h1>[ RECIBIDO OK ]</h1><script>setTimeout(function(){window.location.href='/'},2000);</script></body></html>"
                    data = html.encode('utf-8')
                    self.send_response(200)
                    self.send_header('Content-Type', 'text/html; charset=utf-8')
                    self.send_header('Content-Length', str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
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
    sep_top
    echo -e "${COLOR3}║${RESET}  ${I_WEB} ${BOLD}${COLOR1}SERVIDOR BLEXS AIRDROP${RESET}${COLOR3}                                    ║${RESET}"
    sep_bot
    echo -e "  ${AMARILLO}📂 Carpeta :${RESET} ${BOLD}${COLOR1}$(basename "$(pwd)")${RESET}"
    echo -e "  ${COLOR4}🔗 Subir   :${RESET} ${BOLD}http://$ip:$port/subir${RESET}"
    echo -e "\n  ${GRIS2}Escanea para conectar:${RESET}\n"
    qrencode -t ANSIUTF8 "http://$ip:$port/subir"
    echo -e "\n  ${ROJO}${I_WARN} CTRL+C para detener.${RESET}"
    python3 /tmp/blexs_airdrop.py
    if [ $? -ne 0 ]; then
        echo -e "\n  ${ROJO}❌ Servidor cerrado inesperadamente.${RESET}"
        read -p "  Enter para continuar..."
    fi
    rm -f /tmp/blexs_airdrop.py
}

actualizar_git() {
    if [ -d ".git" ]; then
        echo -e "  ${COLOR1}${I_GIT} Actualizando repo...${RESET}"
        if git pull; then echo -e "  ${COLOR1}${I_CHECK} OK.${RESET}"; else echo -e "  ${ROJO}Error en pull.${RESET}"; fi
    else echo -e "  ${ROJO}${I_WARN} No es un repositorio git.${RESET}"; fi; sleep 1
}

verificar_nombres_windows() {
    local r="$1"; local b=$(find "$r" -name "*[\:\*\?\"<>|\\]*" 2>/dev/null)
    if [ -n "$b" ]; then echo -e "  ${ROJO}${I_WARN} NOMBRES ILEGALES.${RESET}"; echo -ne "  [s] Corregir [n] Cancelar: "; read -r o
    if [[ "$o" == "s" ]]; then find "$r" -depth -name "*[\:\*\?\"<>|\\]*" -exec sh -c 'mv "$1" "$(echo "$1" | tr -d ":\\*?\"<>|\\\\")"' _ {} \; 2>/dev/null; echo -e "  ${COLOR1}${I_CHECK} Corregido.${RESET}"; else return 1; fi; fi; return 0
}

reparar_y_redirigir() {
    echo -e "  ${ROJO}${I_WARN} USB BLOQUEADA.${RESET}"; seleccionar_dispositivo_smart; local d="$DEV_SELECCIONADO"; [ -z "$d" ] && return 1
    echo -e "  ${AMARILLO}>>> Reparando...${RESET}"; $HAS_SUDO umount "$d" 2>/dev/null
    local fs=$($HAS_SUDO lsblk -no FSTYPE "$d" 2>/dev/null)
    if [[ "$fs" == "exfat" ]]; then $HAS_SUDO fsck.exfat -a "$d" >/dev/null 2>&1; else $HAS_SUDO ntfsfix "$d" >/dev/null 2>&1; fi
    local m="/mnt/usb_blexs"; $HAS_SUDO mkdir -p "$m"
    if $HAS_SUDO mount -o rw,users,umask=000 "$d" "$m" 2>/dev/null; then echo -e "  ${COLOR1}${I_CHECK} OK.${RESET}"; NEW_DESTINO="$m"; return 0
    else $HAS_SUDO mount -t exfat -o rw,users,umask=000 "$d" "$m" 2>/dev/null; [ $? -eq 0 ] && NEW_DESTINO="$m" && return 0; fi; return 1
}

seleccionar_dispositivo_smart() {
    echo -e "  ${COLOR4}${I_EYE} UNIDADES DETECTADAS:${RESET}"; local ds=()
    mapfile -t ds < <(lsblk -lp -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT 2>/dev/null | grep -v "loop\|sr0\|NAME")
    if [ ${#ds[@]} -eq 0 ]; then echo -e "  ${ROJO}No detectado.${RESET}"; return; fi
    local i=1
    for d in "${ds[@]}"; do
        if [[ "$d" == *"/sda"* ]]; then echo -e "  ${ROJO}[SYS]${RESET} $d"
        else echo -e "  ${COLOR1}[$i]${RESET} $d"; fi
        ((i++))
    done
    echo -ne "\n  ${I_ALIEN} #: "; read -r n
    if [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le ${#ds[@]} ]; then
        local l="${ds[$((n-1))]}"; DEV_SELECCIONADO=$(echo "$l" | awk '{print $1}')
        if [[ "$DEV_SELECCIONADO" == *"/sda"* ]]; then echo -e "  ${ROJO}ERROR: disco del sistema.${RESET}"; DEV_SELECCIONADO=""; read; return; fi
        if [[ "$DEV_SELECCIONADO" =~ [0-9]$ ]]; then DEV_PADRE=${DEV_SELECCIONADO%[0-9]*}
        else DEV_PADRE="$DEV_SELECCIONADO"; DEV_SELECCIONADO="${DEV_SELECCIONADO}1"; fi
    else DEV_SELECCIONADO=""; fi
}

mostrar_detalles_usb() {
    seleccionar_dispositivo_smart; local d="$DEV_SELECCIONADO"; [ -z "$d" ] && return
    local m="/mnt/usb_viewer"; $HAS_SUDO mkdir -p "$m" 2>/dev/null; $HAS_SUDO umount "$d" 2>/dev/null
    $HAS_SUDO mount -o ro,users "$d" "$m" 2>/dev/null || $HAS_SUDO mount -t exfat -o ro,users "$d" "$m" 2>/dev/null
    clear; sep_top
    echo -e "${COLOR3}║${RESET}  ${I_USB} ${BOLD}${COLOR1}INSPECTOR USB${RESET}${COLOR3}                                             ║${RESET}"
    sep_bot; ls -lh "$m" | head -15; echo -ne "  Enter..."; read
}

ejecutar_pegado_usb_777() {
    local dest="$(pwd)"
    sep_top
    echo -e "${COLOR3}║${RESET}  ${I_POWER} ${BOLD}${COLOR1}PEGADO USB 777${RESET}${COLOR3}                                           ║${RESET}"
    sep_bot
    if ! verificar_nombres_windows "$CLIP_USB_SRC"; then echo "  Cancelado."; read; return; fi
    echo -ne "  ${COLOR4}>>> Test escritura...${RESET} "
    if touch "$dest/.t" 2>/dev/null; then echo -e "${COLOR1}OK${RESET}"; rm "$dest/.t"
    else echo -e "${ROJO}FAIL${RESET}"; read -p "  Reparar? [s/n]: " r
        [[ "$r" == "s" ]] && reparar_y_redirigir && dest="$NEW_DESTINO" && cd "$dest" || return; fi
    echo -e "  ${AMARILLO}Origen :${RESET} $CLIP_USB_SRC"
    echo -e "  ${COLOR4}>>> Copiando...${RESET}"
    $HAS_SUDO rsync -rt --no-o --no-g --copy-links --modify-window=1 --progress "$CLIP_USB_SRC" "$dest/"
    $HAS_SUDO chmod -R 777 "$dest/$(basename "$CLIP_USB_SRC")" 2>/dev/null
    echo -e "  ${COLOR1}${I_CHECK} Finalizado.${RESET}"; CLIP_USB_SRC=""; read
}

expulsar_usb_seguro() {
    echo -e "  ${COLOR1}${I_EJECT} EXPULSIÓN SEGURA${RESET}"; seleccionar_dispositivo_smart
    local d="$DEV_SELECCIONADO"; [ -z "$d" ] && return
    echo -e "  ${GRIS}Sync...${RESET}"; sync
    [[ "$(pwd)" == *"/mnt/usb_blexs"* ]] && cd "$HOME_DIR"
    $HAS_SUDO umount "$d" 2>/dev/null; $HAS_SUDO umount /mnt/usb_blexs 2>/dev/null
    echo -e "  ${COLOR1}${I_CHECK} Puedes retirar: ${BOLD}$d${RESET}"; read
}

menu_usb_tools() {
    while true; do
        clear
        sep_top
        echo -e "${COLOR3}║${RESET}  ${I_USB} ${BOLD}${COLOR1}HERRAMIENTAS USB${RESET}${COLOR3}                                          ║${RESET}"
        sep_bot
        echo -e "  ${COLOR1}[1]${RESET} ${I_FIX}  Reparar      ${AMARILLO}[2]${RESET} 🔗 Montar      ${ROJO}[5]${RESET} 💣 Formatear"
        echo -e "  ${COLOR4}[3]${RESET} ${I_EYE}  Inspeccionar  ${COLOR2}[9]${RESET} ${I_EJECT} Expulsar  ${GRIS}[0]${RESET} ${I_BACK} Volver"
        echo -ne "\n  ${I_ALIEN} : "; read -r o
        case $o in
            1|2|5) seleccionar_dispositivo_smart; local d="$DEV_SELECCIONADO"; [ -z "$d" ] && continue
                case $o in
                    1) $HAS_SUDO umount "$d"; $HAS_SUDO ntfsfix "$d"; read ;;
                    2) $HAS_SUDO mkdir -p /mnt/usb_blexs; $HAS_SUDO mount -o rw,users,umask=000 "$d" /mnt/usb_blexs; xdg-open /mnt/usb_blexs & read ;;
                    5) $HAS_SUDO mkfs.exfat "${DEV_PADRE}1"; echo -e "  ${COLOR1}Done.${RESET}"; read ;;
                esac ;;
            3) mostrar_detalles_usb ;; 9) expulsar_usb_seguro ;; 0) return ;;
        esac
    done
}

menu_archivo() {
    local f="$1"; local n=$(basename "$f")
    while true; do
        clear
        sep_top
        echo -e "${COLOR3}║${RESET}  ${I_DOC} ${BOLD}${AMARILLO}$n${RESET}${COLOR3}                                                        ║${RESET}"
        sep_bot
        sep_linea
        echo -e "  ${COLOR1}[1]${RESET} ${I_EDIT}  Editar     ${ROJO}[2]${RESET} ${I_TRASH} Eliminar   ${AMARILLO}[3]${RESET} ${I_RENAME} Renombrar"
        echo -e "  ${COLOR4}[4]${RESET} ${I_PERM}  Permisos   ${NARANJA}[5]${RESET} ${I_CUT} Cortar     ${COLOR2}[6]${RESET} ${I_COPY} Copiar"
        sep_linea
        echo -e "  ${COLOR1}[C]${RESET} ${I_POWER} ${BOLD}COPIAR A USB 777${RESET}"
        sep_linea
        echo -e "  ${COLOR4}[7]${RESET} ${I_RUN}  Ejecutar   ${COLOR2}[8]${RESET} ${I_OPEN} Abrir     ${AMARILLO}[Z]${RESET} ${I_ZIP} Zip"
        echo -e "  ${COLOR4}[R]${RESET} 📎 Copiar ruta   ${GRIS}[0]${RESET} ${I_BACK} Volver"
        echo -ne "\n  ${I_ALIEN} : "; read -r o
        case $o in
            1) nano "$f"; return ;;
            2) rm -rf "$f"; return ;;
            3) echo -ne "  ${AMARILLO}Nuevo nombre:${RESET} "; read -r nn; mv "$f" "$nn"; return ;;
            4) chmod +x "$f"; echo -e "  ${COLOR1}+x aplicado.${RESET}"; sleep 1; return ;;
            5) CLIP_RUTA="$(pwd)/$n"; CLIP_MODO="MOVER"; echo -e "  ${NARANJA}${I_CUT} Cortado.${RESET}"; sleep 1; return ;;
            6) CLIP_RUTA="$(pwd)/$n"; CLIP_MODO="COPIAR"; echo -e "  ${COLOR4}${I_COPY} Copiado.${RESET}"; sleep 1; return ;;
            [cC]) CLIP_USB_SRC="$(pwd)/$n"; CLIP_USB_TYPE="FILE"; echo -e "  ${COLOR1}${I_CHECK} Cargado.${RESET}"; sleep 1; return ;;
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
                    1) if [[ "$n" == *".py" ]]; then xfce4-terminal -e "sudo python3 \"$f\""
                       else xfce4-terminal -e "sudo bash \"$f\""; fi; wait ;;
                    2) if [[ "$n" == *".py" ]]; then xfce4-terminal -e "python3 \"$f\""
                       else xfce4-terminal -e "bash \"$f\""; fi; wait ;;
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
        echo -e "${COLOR3}║${RESET}  ${I_ALIEN} ${BOLD}${COLOR1}GESTOR BLEXS${RESET} ${GRIS}V57.7${RESET}  ${GRIS}::${RESET}  ${I_USER} ${BOLD}${COLOR4}$REAL_USER${RESET}  ${GRIS}│${RESET} ${I_TEMA} ${COLOR2}${NOMBRE_TEMA}${RESET}"
        echo -e "${COLOR3}║${RESET}  ${I_RUTA} ${GRIS2}$r${RESET}"
        info_panel
        [ -n "$CLIP_USB_SRC" ] && echo -e "${COLOR3}║${RESET}  ${I_POWER} ${BOLD}${COLOR1}USB:${RESET} ${AMARILLO}$(basename "$CLIP_USB_SRC")${RESET}"
        echo -e "${COLOR3}╠══════════════════════════════════════════════════════════════╣${RESET}"
        echo -e "${COLOR3}║${RESET}  ${ROJO}[x]${RESET} ${I_EXIT} Salir     ${GRIS}[0]${RESET} ${I_BACK} Atrás     ${COLOR4}[1]${RESET} ${I_HOME} Escritorio ${GRIS2}($(basename "$ESCRITORIO"))${RESET}"
        echo -e "${COLOR3}║${RESET}  ${COLOR1}[2]${RESET} ${I_PLUS_DIR} Crear Dir  ${COLOR2}[3]${RESET} ${I_PLUS_FILE} Crear File  ${AMARILLO}[U]${RESET} ${I_USB} USB Tools"
        echo -e "${COLOR3}║${RESET}  ${COLOR4}[6]${RESET} ${I_COPY} Copiar Dir  ${COLOR4}[7]${RESET} ${I_MOVE} Mover Dir  ${ROJO}[9]${RESET} ${I_TRASH} Borrar"
        echo -e "${COLOR3}║${RESET}  ${COLOR2}[E]${RESET} ${I_EJECT} Expulsar   ${COLOR1}[W]${RESET} ${I_WEB} Airdrop   ${AMARILLO}[/]${RESET} ${I_SEARCH} Buscar"
        echo -e "${COLOR3}║${RESET}  ${COLOR1}[T]${RESET} ${I_TEMA} ${BOLD}Temas${RESET}       ${COLOR4}[R]${RESET} 📎 Copiar ruta   ${COLOR2}[I]${RESET} 📊 Stats"
        echo -e "${COLOR3}║${RESET}  ${COLOR1}[O]${RESET} 🖥️  Terminal aquí  ${COLOR4}[B]${RESET} 📁 Abrir en Thunar  ${COLOR1}[V]${RESET} 🌳 Vista"
        [ -d .git ] && echo -e "${COLOR3}║${RESET}  ${GRIS}[G]${RESET} ${I_GIT} Git Update"
        echo -e "${COLOR3}╠══════════════════════════════════════════════════════════════╣${RESET}"
        echo -e "${COLOR3}║${RESET}  ${NARANJA}[C]${RESET} ${I_POWER} ${BOLD}Copiar carpeta → USB${RESET}   ${AMARILLO}[Z]${RESET} ${I_ZIP} Zip   ${COLOR1}[S]${RESET} ${I_MULTI} Selección"
        if [ -n "$CLIP_USB_SRC" ]; then
            echo -e "${COLOR3}║${RESET}  ${COLOR1}[P]${RESET} ${I_POWER} ${BOLD}Pegar a USB${RESET}   ${ROJO}[K]${RESET} ${I_CANCEL} Cancelar"
        elif [ -n "$CLIP_RUTA" ]; then
            echo -e "${COLOR3}║${RESET}  ${COLOR4}[P]${RESET} ${I_PASTE} ${BOLD}Pegar${RESET} ${GRIS}($CLIP_MODO)${RESET} ${GRIS2}$(basename "$CLIP_RUTA")${RESET}"
        fi
        echo -e "${COLOR3}╠══════════════════════════════════════════════════════════════╣${RESET}"
        local ls_arr=()
        if $VER_OCULTOS; then
            mapfile -t ls_arr < <(ls -1a --group-directories-first | grep -v "^\.$\|^\.\.$")
        else
            mapfile -t ls_arr < <(ls -1 --group-directories-first)
        fi
        if [ "$MODO_VISTA" == "arbol" ]; then
            if [ ${#ls_arr[@]} -gt 0 ]; then
                mostrar_arbol "."
            else
                echo -e "${COLOR3}║${RESET}  ${GRIS}  ~ vacío ~${RESET}"
            fi
        else
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
        fi
        echo -e "${COLOR3}╚══════════════════════════════════════════════════════════════╝${RESET}"
        [ "$MODO_VISTA" == "arbol" ] && echo -e "  ${GRIS}🌳 Árbol activo — escribe ${COLOR4}[#]${GRIS} para navegar directo · ${COLOR1}[V]${GRIS} para desactivar${RESET}"
        echo -ne "  ${I_ALIEN} : "; read -r i
        case $i in
            [xX])
                TERM_PID=$(ps -o ppid= -p $$ | tr -d ' ')
                TERM_PID=$(ps -o ppid= -p $TERM_PID | tr -d ' ')
                kill $TERM_PID 2>/dev/null
                exit ;;
            0) cd .. ;;
            1) cd "$ESCRITORIO" ;;
            2) echo -ne "  ${COLOR1}Nombre carpeta:${RESET} "; read -r n; mkdir -p "$n" ;;
            3) echo -ne "  ${COLOR1}Nombre archivo:${RESET} "; read -r n; touch "$n" ;;
            [eE]) expulsar_usb_seguro ;;
            [uU]) menu_usb_tools ;;
            [tT]) menu_temas ;;
            [iI]) estadisticas_carpeta ;;
            [oO]) xfce4-terminal --working-directory="$(pwd)" & ;;
            [bB]) thunar "$(pwd)" & ;;
            [vV]) toggle_vista ;;
            [rR])
                echo -n "$r" | xclip -selection clipboard 2>/dev/null || echo -n "$r" | xclip 2>/dev/null
                echo -e "  ${COLOR1}${I_CHECK} Ruta copiada:${RESET} ${GRIS2}$r${RESET}"; sleep 1 ;;
            [cC]) CLIP_USB_SRC="$(pwd)"; CLIP_USB_TYPE="DIR"; echo -e "  ${COLOR1}${I_CHECK} Carpeta en portapapeles.${RESET}"; sleep 1 ;;
            [zZ]) zip -r "$(basename "$r").zip" .; echo -e "  ${COLOR1}${I_CHECK} Zip creado.${RESET}"; sleep 1 ;;
            [wW]) compartir_web_qr_airdrop ;;
            [gG]) actualizar_git ;;
            "/") buscar_archivo ;;
            [sS]) menu_seleccion_multiple ;;
            [pP])
                if [ -n "$CLIP_USB_SRC" ]; then ejecutar_pegado_usb_777
                elif [ -n "$CLIP_RUTA" ]; then
                    [[ "$CLIP_MODO" == "COPIAR" ]] && cp -r "$CLIP_RUTA" . || mv "$CLIP_RUTA" .
                    echo -e "  ${COLOR1}${I_CHECK} Pegado OK.${RESET}"; sleep 1; CLIP_RUTA=""
                fi ;;
            [kK]) CLIP_USB_SRC=""; echo -e "  ${GRIS}Portapapeles limpio.${RESET}"; sleep 1 ;;
            6) CLIP_RUTA="$(pwd)"; CLIP_MODO="COPIAR"; echo -e "  ${COLOR4}${I_COPY} Dir en portapapeles.${RESET}"; sleep 1 ;;
            7) CLIP_RUTA="$(pwd)"; CLIP_MODO="MOVER"; echo -e "  ${AMARILLO}${I_MOVE} Dir listo para mover.${RESET}"; sleep 1 ;;
            9)
                echo -ne "  ${ROJO}${I_WARN} ¿Borrar carpeta ACTUAL? [s/n]:${RESET} "; read -r c
                if [[ "$c" == "s" ]]; then cd ..; rm -rf "$r"; echo -e "  ${COLOR1}Eliminado.${RESET}"; sleep 1
                else echo -e "  ${GRIS}Cancelado.${RESET}"; sleep 1; fi ;;
            *)
                if [[ "$i" =~ ^[0-9]+$ ]]; then
                    if [ "$MODO_VISTA" == "arbol" ]; then
                        navegar_arbol "$i"
                    elif [ "$i" -ge 10 ]; then
                        local s="${ls_arr[$((i-10))]}"
                        [ -d "$s" ] && cd "$s" || menu_archivo "$s"
                    fi
                fi ;;
        esac
    done
}

# --- INICIO ---
cargar_tema
navegar
# Creado por BLEXS
EOF_PAYLOAD

chmod +x "$TARGET"

if [ ! -f /usr/local/bin/go ] && [ ! -L /usr/local/bin/go ]; then
    ln -s "$TARGET" /usr/local/bin/go
    echo -e "\033[38;5;46m[👽] BLEXS V57.7 INSTALADO. USA 'go' PARA ENTRAR.\033[0m"
else
    rm -f /usr/local/bin/go
    ln -s "$TARGET" /usr/local/bin/go
    echo -e "\033[38;5;46m[👽] COMANDO 'go' ACTUALIZADO A V57.7.\033[0m"
fi
