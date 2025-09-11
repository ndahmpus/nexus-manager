# 🚀 Quick Reference: Nexus CLI v0.10.10 Features

## 🎯 New Features at a Glance

### 🎨 Background Colors (`--with-background`)
- **Location**: Main Menu → [5] Environment Config → [9] Toggle Background Colors
- **Purpose**: Enhance Nexus CLI dashboard appearance with background colors
- **Usage**: Toggle ON for better visual contrast in terminal
- **Default**: OFF (maintains compatibility)

### 🔢 Task Limits (`--max-tasks`)
- **Location**: Main Menu → [5] Environment Config → [10] Set Max Tasks Limit
- **Purpose**: Auto-exit container after processing N tasks
- **Usage**: Set number (100, 500, 1000) or leave empty for unlimited
- **Default**: Unlimited (continuous operation)

## 📋 How to Use

### Enable Background Colors:
1. Run `./nexus-manager.sh`
2. Choose `[5] Environment Config`
3. Choose `[9] Toggle Background Colors (v0.10.10)`
4. Restart containers to see effect

### Set Task Limit:
1. Run `./nexus-manager.sh`
2. Choose `[5] Environment Config`
3. Choose `[10] Set Max Tasks Limit (v0.10.10)`
4. Enter desired number (e.g., 1000) or press Enter for unlimited
5. New containers will use this setting

### Check Current Settings:
The Environment Config menu shows:
```
With Background  : false/true
Max Tasks Limit  : unlimited/1000
```

## 🔄 Container Behavior

### With Background Colors Enabled:
- Nexus CLI dashboard inside containers will have enhanced visual appearance
- Better readability and professional look
- No impact on performance

### With Task Limit Set:
- Container processes exactly N tasks then exits gracefully
- Useful for batch processing or controlled runs
- Container status shows "Exited (0)" when limit reached
- Can be restarted manually or with auto-restart enabled

## 🛠️ Technical Details

### Configuration Variables:
```bash
NEXUS_WITH_BACKGROUND="true"   # Enable background colors
NEXUS_MAX_TASKS="1000"         # Limit to 1000 tasks
```

### Environment Variables in Container:
```bash
WITH_BACKGROUND=true    # Passed to nexus-cli
MAX_TASKS=1000         # Passed to nexus-cli
```

### Command Line Result:
```bash
nexus-cli start --headless --node-id 12345 --with-background --max-tasks 1000
```

## ⚡ Quick Tips

1. **Background Colors**: Try enabling for better visual experience
2. **Task Limits**: Use for testing (e.g., 100 tasks) or batch processing
3. **Unlimited Mode**: Default setting for continuous operation
4. **Restart Required**: Changes take effect on new container starts
5. **Safe to Toggle**: No risk in trying these new features

## 🔍 Verification

To verify the update worked:
1. Check Environment Config menu shows new options 9 & 10
2. Configuration display includes "With Background" and "Max Tasks Limit"
3. New containers include the environment variables when set

---

*Nexus CLI v0.10.10 integration complete! 🎉*
