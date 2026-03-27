# PRD: Dotfiles - Instalador Modular de Herramientas en Linux

## 📋 Resumen Ejecutivo

**Nombre del Proyecto:** Dotfiles  
**Objetivo:** Crear un sistema automatizado y modular para instalar herramientas, configuraciones y dependencias en Linux mediante un único comando.  
**Entrada:** `curl -fsSL https://raw.githubusercontent.com/usuario/dotfiles/main/install.sh | bash`  
**Alcance:** Linux (Ubuntu/Debian compatible como MVP)

---

## 🎯 Problema y Solución

### Problema

- Cada vez que configuras una máquina nueva, instalas las mismas herramientas manualmente
- No hay forma consistente de mantener tus configuraciones
- Es tedioso recordar qué paquetes necesitas y el orden correcto de instalación
- Diferentes usuarios quieren diferentes herramientas (sin un flujo de selección)

### Solución

Un repositorio centralizado (`dotfiles`) que:

1. Descarga e instala en un comando
2. Permite seleccionar qué instalar mediante una TUI interactiva
3. Mantiene scripts modulares para cada herramienta
4. Orquesta la instalación respetando dependencias
5. Es fácil de extender con nuevas herramientas

---

## 📐 Arquitectura

### Estructura de Carpetas

```
dotfiles/
├── install.sh                 # Bootstrap - descarga todo y arranca la TUI
├── src/
│   ├── orchestrator.sh        # Orquestador principal
│   ├── tui.sh                 # TUI - menú interactivo
│   ├── logger.sh              # Funciones de log
│   ├── utils.sh               # Utilidades generales
│   └── config.sh              # Configuración global
├── installers/                # Scripts de instalación por herramienta
│   ├── base.sh                # Dependencias base (build-essentials, curl, etc)
│   ├── git.sh
│   ├── nodejs.sh
│   ├── python.sh
│   ├── docker.sh
│   ├── zsh.sh
│   ├── neovim.sh
│   ├── tmux.sh
│   ├── ripgrep.sh
│   └── ...
├── dotfiles/                  # Archivos de configuración
│   ├── .zshrc
│   ├── .tmux.conf
│   ├── .gitconfig
│   └── ...
├── manifest.json              # Definición de herramientas y dependencias
├── README.md
└── VERSION
```

### Flujo de Ejecución

```
┌─────────────────────────────────────────────┐
│  install.sh (bootstrap vía curl/wget)       │
│  - Detecta distro Linux                     │
│  - Descarga el repo completo                │
│  - Ejecuta orchestrator.sh                  │
└────────────────┬────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────┐
│  orchestrator.sh                            │
│  - Valida prerequisitos (permisos, etc)     │
│  - Carga manifest.json                      │
│  - Llama a tui.sh                           │
└────────────────┬────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────┐
│  tui.sh (Terminal User Interface)           │
│  - Menú checkbox de herramientas            │
│  - Muestra dependencias                     │
│  - Usuario selecciona qué instalar          │
│  - Retorna lista de herramientas elegidas   │
└────────────────┬────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────┐
│  orchestrator.sh (fase 2)                   │
│  - Valida dependencias                      │
│  - Ordena instalaciones respetando deps     │
│  - Ejecuta installers/ en orden             │
│  - Copia dotfiles/ a $HOME                  │
│  - Registra lo instalado                    │
└────────────────┬────────────────────────────┘
                 │
                 ▼
         ✅ Completado
```

---

## 🔧 Componentes Principales

### 1. **install.sh** (Bootstrap)

**Responsabilidad:** Punto de entrada único  
**Qué hace:**

- Se ejecuta con permisos del usuario (sin sudo)
- Detecta la distro Linux (Ubuntu, Debian, Arch, Fedora)
- Descarga el repo (vía git si está disponible, si no vía tar.gz desde GitHub)
- Crea directorio de trabajo temporal
- Ejecuta `orchestrator.sh`
- Limpia archivos temporales

**Pseudocódigo:**

```bash
#!/bin/bash
set -e

DOTFILES_REPO="https://github.com/usuario/dotfiles"
WORK_DIR="${HOME}/.dotfiles-install-$$"

# 1. Detectar distro
detect_distro()

# 2. Descargar repo
download_repo()

# 3. Ejecutar orquestador
"${WORK_DIR}/src/orchestrator.sh" "$@"

# 4. Limpiar
cleanup()
```

---

### 2. **orchestrator.sh** (Orquestador)

**Responsabilidad:** Dirigir todo el flujo de instalación  
**Qué hace:**

- Valida prerequisitos (bash 4+, curl/wget, sudo)
- Carga funciones compartidas (logger.sh, utils.sh, config.sh)
- Carga manifest.json (árbol de dependencias)
- Llama a `tui.sh` para que el usuario seleccione
- Valida que todas las dependencias de herramientas elegidas están incluidas
- Construye orden topológico de instalaciones (respeta dependencias)
- Ejecuta cada `installers/TOOL.sh` en orden
- Copia dotfiles personalizados
- Registra el resultado en `.dotfiles-installed`

**Pseudocódigo:**

```bash
#!/bin/bash
source ./src/logger.sh
source ./src/utils.sh
source ./src/config.sh

# 1. Validaciones
validate_prerequisites()

# 2. Cargar manifest
load_manifest() {
  # Lee manifest.json, estructura:
  # {
  #   "tools": {
  #     "git": {
  #       "name": "Git",
  #       "dependencies": ["base"],
  #       "installer": "installers/git.sh"
  #     },
  #     ...
  #   }
  # }
}

# 3. Llamar TUI
selected_tools=$(./src/tui.sh)

# 4. Validar y ordenar
validate_deps "$selected_tools"
ordered_tools=$(topological_sort "$selected_tools")

# 5. Instalar
for tool in $ordered_tools; do
  install_tool "$tool"
done

# 6. Copiar dotfiles
copy_dotfiles

# 7. Registrar
log_installation_manifest "$ordered_tools"
```

---

### 3. **tui.sh** (Terminal User Interface)

**Responsabilidad:** Interfaz interactiva para seleccionar herramientas  
**Qué hace:**

- Carga la lista de herramientas desde manifest.json
- Muestra un menú checkbox
- Permite navegar con flechas y seleccionar con espacio/enter
- Muestra dependencias de cada herramienta al lado
- Retorna una lista de herramientas seleccionadas

**Opciones de implementación:**

- **Opción A (Simple):** Menú con `select` de bash + espacio para activar/desactivar
- **Opción B (Media):** Usar `fzf` si está disponible (fallback a Opción A)
- **Opción C (Sofisticada):** Script bash puro con manejo de teclado (más código pero más control)

**Pseudocódigo:**

```bash
#!/bin/bash

# Cargar herramientas desde manifest
load_tools_from_manifest() { ... }

# Inicializar estado (todas desmarcadas excepto "base")
initialize_state() { ... }

# Renderizar menú
render_menu() {
  clear
  echo "=== Dotfiles Installer ==="
  echo ""
  for tool in "${tools[@]}"; do
    if [[ " ${selected[@]} " =~ " ${tool} " ]]; then
      echo "✓ $tool"
    else
      echo "  $tool"
    fi
  done
}

# Loop principal
while true; do
  render_menu
  read -rsn1 key
  case $key in
    ' ') toggle_current ;;
    'j') move_down ;;
    'k') move_up ;;
    'q') exit 1 ;;
    '') confirm_selection && break ;;
  esac
done

echo "${selected[@]}"
```

**Salida esperada:**

```
base git nodejs python docker zsh neovim
```

---

### 4. **Installers Modulares** (installers/\*.sh)

**Responsabilidad:** Instalar una herramienta específica  
**Contrato:**

- Cada archivo contiene una función `install_TOOLNAME()`
- Puede usar variables globales del orchestrator
- Retorna código de salida 0 si éxito, >0 si fallo
- Usa `log_info()`, `log_error()`, `log_success()` para output
- Ejecuta `check_tool_installed()` antes si puede

**Ejemplo: installers/nodejs.sh**

```bash
#!/bin/bash

install_nodejs() {
  log_info "Installing Node.js..."

  # Detectar si ya está
  if command -v node &> /dev/null; then
    log_success "Node.js already installed: $(node -v)"
    return 0
  fi

  # Instalar según distro
  case "$DISTRO" in
    ubuntu|debian)
      curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
      sudo apt-get install -y nodejs
      ;;
    arch)
      sudo pacman -S nodejs npm
      ;;
    fedora)
      sudo dnf install nodejs npm
      ;;
  esac

  log_success "Node.js installed: $(node -v)"
  return 0
}

install_nodejs
```

**Herramientas sugeridas (MVP):**

1. **base** - build-essentials, curl, wget, git, sudo
2. **git** - git + config
3. **nodejs** - Node.js + npm
4. **python** - Python3 + pip
5. **docker** - Docker + docker-compose
6. **zsh** - Zsh + oh-my-zsh
7. **neovim** - Neovim + vim-plug
8. **tmux** - Tmux
9. **ripgrep** - ripgrep (rg)
10. **fzf** - Fuzzy finder

---

### 5. **manifest.json** (Definición de Herramientas)

**Responsabilidad:** Declarar todas las herramientas y sus dependencias  
**Formato:**

```json
{
  "version": "1.0.0",
  "tools": {
    "base": {
      "name": "Base System Tools",
      "description": "Essential build tools, curl, wget",
      "dependencies": [],
      "installer": "installers/base.sh",
      "category": "system",
      "required": true
    },
    "git": {
      "name": "Git",
      "description": "Version control system",
      "dependencies": ["base"],
      "installer": "installers/git.sh",
      "category": "vcs",
      "required": false
    },
    "nodejs": {
      "name": "Node.js",
      "description": "JavaScript runtime",
      "dependencies": ["base"],
      "installer": "installers/nodejs.sh",
      "category": "runtime",
      "required": false
    },
    "python": {
      "name": "Python",
      "description": "Python 3 + pip",
      "dependencies": ["base"],
      "installer": "installers/python.sh",
      "category": "runtime",
      "required": false
    },
    "docker": {
      "name": "Docker",
      "description": "Container platform",
      "dependencies": ["base"],
      "installer": "installers/docker.sh",
      "category": "devops",
      "required": false
    },
    "zsh": {
      "name": "Zsh Shell",
      "description": "Advanced shell + oh-my-zsh",
      "dependencies": ["base"],
      "installer": "installers/zsh.sh",
      "category": "shell",
      "required": false
    },
    "neovim": {
      "name": "Neovim",
      "description": "Modern vim",
      "dependencies": ["base"],
      "installer": "installers/neovim.sh",
      "category": "editor",
      "required": false
    },
    "tmux": {
      "name": "Tmux",
      "description": "Terminal multiplexer",
      "dependencies": ["base"],
      "installer": "installers/tmux.sh",
      "category": "terminal",
      "required": false
    },
    "ripgrep": {
      "name": "Ripgrep",
      "description": "Fast grep alternative (rg)",
      "dependencies": ["base"],
      "installer": "installers/ripgrep.sh",
      "category": "tools",
      "required": false
    },
    "fzf": {
      "name": "FZF",
      "description": "Fuzzy finder",
      "dependencies": ["base"],
      "installer": "installers/fzf.sh",
      "category": "tools",
      "required": false
    }
  }
}
```

---

### 6. **Funciones Compartidas**

#### **logger.sh** - Logging

```bash
log_info()    # Info en azul
log_success() # Éxito en verde
log_error()   # Error en rojo
log_warn()    # Advertencia en amarillo
```

#### **utils.sh** - Utilidades

```bash
check_command()           # Verifica si comando existe
detect_distro()           # Ubuntu/Debian/Arch/Fedora
ask_confirm()             # Pregunta sí/no
wait_for_user_action()    # Pausa hasta que presione algo
topological_sort()        # Ordena herramientas por deps
```

#### **config.sh** - Configuración

```bash
DISTRO                    # Variable global
DOTFILES_DIR              # Ruta del repo
HOME_BACKUP_DIR           # Backup de dotfiles anteriores
```

---

## 📦 Flujo de Instalación Detallado

### Paso 1: Bootstrap (30 segundos)

```bash
curl -fsSL https://raw.githubusercontent.com/usuario/dotfiles/main/install.sh | bash
```

**Qué pasa:**

- Detecta distro
- Descarga repo en `/tmp`
- Ejecuta orchestrator.sh

### Paso 2: TUI (1-2 minutos)

```
═══════════════════════════════════════════════════════════════
 Dotfiles Installer
═══════════════════════════════════════════════════════════════

Selecciona qué instalar (espacio para marcar, enter para confirmar):

[✓] base              (required)
[✓] git               (depends on: base)
[ ] nodejs            (depends on: base)
[ ] python            (depends on: base)
[✓] docker            (depends on: base)
[ ] zsh               (depends on: base)
[✓] neovim            (depends on: base)
[ ] tmux              (depends on: base)
[ ] ripgrep           (depends on: base)
[ ] fzf               (depends on: base)

Controles: j/k=navegar, espacio=marcar, q=salir, enter=confirmar
```

### Paso 3: Instalación (5-30 minutos según herramientas)

```
[✓] Validando prerequisitos...
[✓] Validando dependencias...
[►] Instalando herramientas en orden...
  [✓] base (1/5)
  [✓] git (2/5)
  [✓] docker (3/5)
  [✓] neovim (4/5)
  [✓] Copying dotfiles...
  [✓] Registrando instalación...

═══════════════════════════════════════════════════════════════
✅ Instalación completada exitosamente!
═══════════════════════════════════════════════════════════════

Herramientas instaladas: base, git, docker, neovim
Dotfiles copiados a: /home/usuario
Manifiesto guardado en: /home/usuario/.dotfiles-installed

Próximos pasos:
  1. source ~/.zshrc (si instalaste zsh)
  2. Configura git: git config --global user.name "Tu Nombre"
  3. Revisa los dotfiles en ~/.dotfiles/
```

---

## 🔄 Casos de Uso

### Caso 1: Primera instalación en máquina nueva

```bash
# En una máquina limpia (Ubuntu/Debian)
curl -fsSL https://raw.githubusercontent.com/usuario/dotfiles/main/install.sh | bash

# Usuario selecciona todas las herramientas
# Todo se instala automáticamente
```

### Caso 2: Agregar solo una herramienta

```bash
# Re-ejecutar el script
./install.sh

# Usuario deselecciona lo que ya tiene
# Solo instala lo nuevo
```

### Caso 3: Actualizar dotfiles

```bash
# Actualizar el repo
cd ~/.dotfiles
git pull

# Re-ejecutar instalador (sin instalar nada, solo copia dotfiles)
./install.sh
```

---

## 📋 Especificaciones Técnicas

### Requisitos Mínimos

- Bash 4.0+
- curl o wget
- Linux (Ubuntu 18.04+, Debian 10+, Arch, Fedora como mínimo)
- Usuario sin permisos root (pero con sudo)

### Decisiones de Diseño

| Decisión                 | Razonamiento                                            |
| ------------------------ | ------------------------------------------------------- |
| Bootstrap vía curl\|bash | Punto de entrada único, sin necesidad de clonar primero |
| Manifest.json            | Declarativo, fácil de leer y extender                   |
| Bash puro para TUI       | No depende de utilidades externas (fzf es opcional)     |
| Modulos separados        | Cada herramienta es independiente, reutilizable         |
| Topological sort         | Respeta dependencias complejas                          |
| Copia dotfiles al final  | Evita sobrescrituras accidentales durante instalación   |

---

## 🚀 Extensibilidad

### Agregar una nueva herramienta

**1. Crear instalador:** `installers/mynewtools.sh`

```bash
#!/bin/bash

install_mynewtools() {
  log_info "Installing mynewtools..."

  if command -v mytool &> /dev/null; then
    log_success "mynewtools already installed"
    return 0
  fi

  case "$DISTRO" in
    ubuntu|debian)
      sudo apt-get install -y mynewtools
      ;;
    arch)
      sudo pacman -S mynewtools
      ;;
  esac

  log_success "mynewtools installed"
}

install_mynewtools
```

**2. Agregar a manifest.json**

```json
"mynewtools": {
  "name": "My New Tool",
  "description": "Does something awesome",
  "dependencies": ["base"],
  "installer": "installers/mynewtools.sh",
  "category": "tools",
  "required": false
}
```

**3. (Opcional) Crear dotfile:** `dotfiles/.mynewtoolrc`

**4. Agregar a tui.sh** (se carga automáticamente desde manifest)

---

## 📊 Registros e Historial

Archivo: `~/.dotfiles-installed`

```json
{
  "timestamp": "2024-03-26T10:30:45Z",
  "version": "1.0.0",
  "distro": "ubuntu",
  "tools_installed": ["base", "git", "docker", "neovim"],
  "dotfiles_copied": [
    ".gitconfig",
    ".zshrc",
    ".tmux.conf",
    ".config/nvim/init.vim"
  ],
  "duration_seconds": 245
}
```

---

## ✅ Criterios de Aceptación

- [x] El script `install.sh` funciona con `curl | bash`
- [x] La TUI permite seleccionar/deseleccionar herramientas
- [x] El orquestador respeta dependencias
- [x] Cada herramienta se instala correctamente en Ubuntu 18.04+
- [x] Los dotfiles se copian a $HOME
- [x] Se genera un registro de instalación
- [x] Es fácil agregar nuevas herramientas
- [x] El código es legible, comentado, y reutilizable
- [x] No requiere interacción del usuario durante instalación (excepto TUI inicial)

---

## 📚 Stack Tecnológico

- **Lenguaje:** Bash 4+
- **Versionamiento:** Git + GitHub
- **Testeo:** BATS (Bash Automated Testing System)

---

**Documento versión 1.0**  
**Última actualización:** 26 de Marzo 2025
