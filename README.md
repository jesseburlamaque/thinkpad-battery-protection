# ThinkCharge 🔴⚡

Plugin para o **Omarchy** projetado especialmente para **Lenovo ThinkPads**, fornecendo controle fino e intuitivo dos **dois limiares de carga da bateria** (*Dual-Threshold Protection*).

---

## 🎯 Por que o ThinkCharge?

A maioria dos notebooks modernos permite apenas definir um limite único de parada (ex: 80%). No entanto, os ThinkPads suportam nativamente dois limiares no Embedded Controller (EC):

1. **Stop Threshold (Limite Máximo):** A bateria interrompe o carregamento ao atingir este valor.
2. **Start Threshold (Início de Recarga):** A bateria só volta a puxar carga da tomada se a porcentagem cair abaixo deste valor.

Isso elimina os microciclos de recarga contínuos quando o notebook passa o dia inteiro conectado na fonte ou no docking station, prolongando substancialmente a vida útil química das células de lítio.

---

## ✨ Recursos

- **Dois Sliders Dinâmicos:**
  - **Limite Máximo (Stop):** 45% a 100% (passos de 5%).
  - **Início de Recarga (Start):** 40% a 95% (passos de 5%).
- **Lógica Anti-Erro Inteligente (Constraint Synchronization):**
  - O firmware do ThinkPad exige que `Start < Stop`.
  - Se você puxar o slider de parada para baixo, o início é reduzido automaticamente com a margem de segurança.
  - Se puxar o início para cima, o limite de parada avança automaticamente.
  - Impossível aplicar um estado inválido no hardware!
- **Feedback em Linguagem Natural:** Exibe em tempo real o que o ThinkPad fará (ex: *"Carrega até 85% e só volta a recarregar abaixo de 75%"*).
- **Presets Rápidos com 1 Clique:**
  - **Dock (50–60%):** Máxima preservação para computadores quase sempre na tomada.
  - **Equilibrado (75–85%):** Uso diário ideal, unindo longevidade e autonomia.
  - **Viagem (95–100%):** Carga total sob demanda para saídas e viagens.
- **Integração Completa ao Omarchy:**
  - Acesso pelo clique no ícone da barra (`󱈑` com o ponto vermelho característico dos ThinkPads).
  - Acesso direto pelo menu do Omarchy (**Trigger → Hardware → ThinkCharge**).
  - Pop-up responsivo na barra ou painel centralizado caso o ícone esteja oculto.
  - Serviço systemd automático para persistência entre reboots.

---

## 📦 Instalação

Como o projeto está na sua pasta `~/Projects/omarchy-thinkcharge`:

1. **Vincular o plugin ao Omarchy:**
   ```bash
   ln -s ~/Projects/omarchy-thinkcharge ~/.config/omarchy/plugins/jesseburlamaque.thinkcharge
   ```

2. **Instalar os componentes do sistema (regras Polkit e serviço systemd):**
   ```bash
   cd ~/Projects/omarchy-thinkcharge
   ./install.sh
   ```

3. **Recarregar os plugins no Omarchy Shell:**
   ```bash
   omarchy-shell shell rescanPlugins
   ```

---

## 💻 Uso

- **Abrir a interface gráfica:**
  ```bash
  omarchy-shell jesseburlamaque.thinkcharge open
  ```
  *(Ou abra pelo menu Trigger > Hardware > ThinkCharge)*.

- **Consultar status via terminal:**
  ```bash
  /usr/local/libexec/thinkcharge-helper status
  ```

- **Alterar via terminal (como root):**
  ```bash
  sudo /usr/local/libexec/thinkcharge-helper set <STOP> <START>
  # Exemplo:
  sudo /usr/local/libexec/thinkcharge-helper set 85 75
  ```

---

## 📄 Licença

MIT License.
