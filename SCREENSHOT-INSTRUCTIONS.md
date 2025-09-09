# 📸 Screenshot Instructions for Nexus Manager Dashboard

## 🎯 How to Take Dashboard Screenshot

For users who want to share their dashboard or contribute screenshots to the project:

### 1. Run the Dashboard
```bash
./nexus-manager.sh
# or for Windows:
bash ./nexus-manager.sh
```

### 2. Take Screenshot Methods

#### 🖥️ Windows Users:
- **Windows Key + Shift + S** - Snipping Tool (recommended)
- **Alt + Print Screen** - Current window only
- **Print Screen** - Full screen

#### 🐧 Linux Users:
```bash
# Using gnome-screenshot
gnome-screenshot -w

# Using scrot
scrot -s dashboard-screenshot.png

# Using import (ImageMagick)
import dashboard-screenshot.png
```

#### 🍎 macOS Users:
- **Cmd + Shift + 4** - Select area
- **Cmd + Shift + 3** - Full screen
- **Cmd + Shift + 4 + Space** - Specific window

### 3. Terminal Screenshot Tools

#### For better quality terminal screenshots:
```bash
# Install carbon-cli for beautiful code screenshots
npm install -g carbon-now-cli

# Take screenshot of terminal
carbon-now nexus-manager.sh --target terminal
```

#### Using asciinema for terminal recordings:
```bash
# Install asciinema
pip install asciinema

# Record terminal session
asciinema rec dashboard-demo.cast

# Convert to gif
agg dashboard-demo.cast dashboard-demo.gif
```

## 📁 Screenshot Guidelines

### File Naming Convention:
- `dashboard-preview.png` - Main dashboard view
- `dashboard-running-nodes.png` - With running nodes
- `dashboard-stopped-nodes.png` - With stopped nodes  
- `management-menu.png` - Management menu view
- `node-control.png` - Node control center
- `log-viewer.png` - Log viewer interface

### Image Requirements:
- **Format**: PNG preferred (better quality)
- **Resolution**: Minimum 1200x800px
- **Background**: Dark terminal recommended
- **Font**: Monospace font for better readability
- **Colors**: Ensure color indicators are visible

### Content Guidelines:
- Show realistic node data (not just test data)
- Include system information bar
- Display some completed tasks
- Show mix of running/healthy nodes
- Avoid showing sensitive information (wallet addresses, etc.)

## 🎨 Terminal Theme Recommendations

For best screenshot quality, use these terminal themes:

### Windows Terminal:
```json
{
    "name": "Nexus Dashboard",
    "background": "#0c0c0c",
    "foreground": "#cccccc",
    "cursorColor": "#ffffff"
}
```

### VS Code Terminal:
- Theme: "Dark+" or "One Dark Pro"
- Font: "Fira Code" or "JetBrains Mono"

### macOS Terminal:
- Profile: "Pro" or "Homebrew"
- Font: "SF Mono" or "Menlo"

## 📤 Contributing Screenshots

To contribute screenshots to the project:

1. Take high-quality screenshots following guidelines above
2. Save to `screenshots/` folder
3. Update `SCREENSHOTS.md` with descriptions
4. Create pull request with new screenshots

### Example contribution:
```bash
# Add screenshots
git add screenshots/dashboard-preview.png
git commit -m "Add dashboard screenshot with 10 running nodes"
git push origin feature/screenshots
```

## 🔧 Troubleshooting Screenshot Issues

### Colors not showing properly:
- Ensure terminal supports 256 colors
- Check TERM environment variable: `echo $TERM`
- Should be `xterm-256color` or similar

### Unicode characters not displaying:
- Install proper fonts with Unicode support
- Use UTF-8 encoding in terminal
- Try "Nerd Fonts" for better icon support

### Blurry screenshots:
- Use high DPI settings
- Take screenshots at native resolution
- Avoid upscaling small screenshots

---

**Note**: The current `README.md` includes an ASCII text version of the dashboard that works across all platforms and doesn't require images.
