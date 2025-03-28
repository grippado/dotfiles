# 🚀 Grippado Dotfiles

<div align="center">

![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)
![Linux](https://img.shields.io/badge/Linux-APT-green.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

```
  ▄▀  █▄▄▄▄ ▄█ █ ▄▄  █ ▄▄  ██   ██▄   ████▄            
▄▀    █  ▄▀ ██ █   █ █   █ █ █  █  █  █   █            
█ ▀▄  █▀▀▌  ██ █▀▀▀  █▀▀▀  █▄▄█ █   █ █   █            
█   █ █  █  ▐█ █     █     █  █ █  █  ▀████            
 ███    █    ▐  █     █       █ ███▀                   
       ▀         ▀     ▀     █                         
                            ▀                          
██▄   ████▄    ▄▄▄▄▀ ▄████  ▄█ █     ▄███▄     ▄▄▄▄▄   
█  █  █   █ ▀▀▀ █    █▀   ▀ ██ █     █▀   ▀   █     ▀▄ 
█   █ █   █     █    █▀▀    ██ █     ██▄▄   ▄  ▀▀▀▀▄   
█  █  ▀████    █     █      ▐█ ███▄  █▄   ▄▀ ▀▄▄▄▄▀    
███▀          ▀       █      ▐     ▀ ▀███▀             
                       ▀                               
```

</div>

## 🌟 Features

- 🚀 **Shell Environment**
  - ZSH with Oh-My-ZSH
  - Custom aliases and functions
  - FZF for fuzzy finding
  - NVM for Node.js version management
  - Bashtop for system monitoring

- 🛠️ **Development Tools**
  - Neovim configuration
  - Git configuration
  - Package management (Homebrew/APT)

- 🔒 **Security**
  - Secure secrets management
  - GitHub token integration

## 🚀 Quick Start

```bash
# Clone the repository
git clone git@github.com:grippado/dotfiles.git ~/.dotfiles

# Navigate to dotfiles directory
cd ~/.dotfiles

# Make install script executable
chmod +x install.sh

# Run the installer
./install.sh
```

## 📦 Requirements

- macOS 13.0+ or Linux with APT
- Git
- Homebrew (macOS) or APT (Linux)
- Internet connection

## 🛠️ Installation Process

The installer will:
1. Set up your shell environment
2. Install required packages
3. Configure development tools
4. Set up security features
5. Create necessary symbolic links

## 🔧 Manual Configuration

If you prefer to configure manually:

1. Create a `~/.secrets` file:
```bash
touch ~/.secrets
```

2. Add your secrets:
```bash
GITHUB_TOKEN=your_github_token_here
```

## 📚 Directory Structure

```
.dotfiles/
├── configs/         # Configuration files
├── installers/      # Installation scripts
├── zsh/            # ZSH configuration
├── install.sh      # Main installation script
└── README.md       # This file
```

---

# 🇧🇷 Português

## 🌟 Recursos

- 🚀 **Ambiente Shell**
  - ZSH com Oh-My-ZSH
  - Aliases e funções personalizadas
  - FZF para busca fuzzy
  - NVM para gerenciamento de versões do Node.js
  - Bashtop para monitoramento do sistema

- 🛠️ **Ferramentas de Desenvolvimento**
  - Configuração do Neovim
  - Configuração do Git
  - Gerenciamento de pacotes (Homebrew/APT)

- 🔒 **Segurança**
  - Gerenciamento seguro de segredos
  - Integração com token do GitHub

## 🚀 Início Rápido

```bash
# Clone o repositório
git clone git@github.com:grippado/dotfiles.git ~/.dotfiles

# Navegue até o diretório dotfiles
cd ~/.dotfiles

# Torne o script de instalação executável
chmod +x install.sh

# Execute o instalador
./install.sh
```

## 📦 Requisitos

- macOS 13.0+ ou Linux com APT
- Git
- Homebrew (macOS) ou APT (Linux)
- Conexão com a internet

## 🛠️ Processo de Instalação

O instalador irá:
1. Configurar seu ambiente shell
2. Instalar pacotes necessários
3. Configurar ferramentas de desenvolvimento
4. Configurar recursos de segurança
5. Criar links simbólicos necessários

## 🔧 Configuração Manual

Se preferir configurar manualmente:

1. Crie um arquivo `~/.secrets`:
```bash
touch ~/.secrets
```

2. Adicione seus segredos:
```bash
GITHUB_TOKEN=seu_token_github_aqui
```

## 📚 Estrutura de Diretórios

```
.dotfiles/
├── configs/         # Arquivos de configuração
├── installers/      # Scripts de instalação
├── zsh/            # Configuração do ZSH
├── install.sh      # Script principal de instalação
└── README.md       # Este arquivo
```

## 📄 Licença

Este projeto está licenciado sob a Licença MIT - veja o arquivo [LICENSE](LICENSE) para detalhes.
