# 🚨 CRITICAL: Nexus CLI v0.10.11 Migration Guide

## ⚠️ BREAKING CHANGES - ACTION REQUIRED

### 🔴 **THREADS ARE DEPRECATED**
**`--max-threads` parameter is DEPRECATED and will be IGNORED**

```bash
# ❌ OLD (v0.10.10) - This will be ignored!
nexus-cli start --headless --node-id 12345 --max-threads 4

# ✅ NEW (v0.10.11) - Automatic threading
nexus-cli start --headless --node-id 12345
```

### 🆕 **NEW: Self-Regulating Difficulty**
Nexus now automatically adjusts difficulty for optimal performance.

## 🚀 Quick Migration Steps

### **Step 1: Update Your Configuration**
1. Run your Nexus Manager: `./nexus-manager.sh`
2. Go to `[5] Environment Config`
3. Choose `[11] Set Max Difficulty (v0.10.11)`
4. Select `[0] AUTO - Let Nexus self-regulate` **(RECOMMENDED)**

### **Step 2: Ignore Thread Warnings**
- Your containers will show warnings about deprecated threads
- **This is normal** - Nexus handles threading automatically now
- No action needed - warnings are just informational

### **Step 3: Rebuild Your Containers**
1. Go to `[A] Docker Management`
2. Choose `[8] Deep System Cleanup` (optional - for clean start)
3. Go to `[1] Build/Update Image` to get v0.10.11 binary
4. Restart your node containers

## 🎯 New Difficulty Options

### **Recommended: AUTO Mode** 🤖
- **Best for**: Everyone (default)
- **Why**: Nexus intelligently adapts to your hardware
- **Setup**: Just leave difficulty empty/auto

### **Manual Override Options:**
- **SMALL** - Testing/debugging on low-power devices
- **SMALL_MEDIUM** - Entry-level hardware
- **MEDIUM** - Standard desktop computers  
- **LARGE** - High-performance systems
- **EXTRA_LARGE** - Server-grade hardware

## ✅ What You Should See

### **Environment Config Menu:**
```
[11] 🎯 Set Max Difficulty (v0.10.11)  ← NEW OPTION
```

### **Configuration Display:**
```
Max Difficulty   : auto               ← NEW
Default Threads  : 4 (DEPRECATED)     ← DEPRECATED WARNING
```

### **Container Logs:**
```
⚠️ Warning: --max-threads is DEPRECATED in v0.10.11 and will be ignored
🚀 Starting Nexus Node 12345
🤖 Using self-regulating difficulty
```

## 🔧 Technical Changes

### **What Still Works:**
- All Docker management features
- Background colors (`--with-background`)
- Task limits (`--max-tasks`)
- Node management and monitoring

### **What's Different:**
- Thread settings are ignored (not harmful, just ignored)
- Difficulty can be configured (new feature)
- Better automatic performance optimization

## 💡 Pro Tips

1. **Use AUTO difficulty** - it's the recommended default
2. **Don't worry about thread warnings** - they're just informational
3. **Rebuild containers** to get the latest v0.10.11 improvements
4. **Test with SMALL difficulty** if you want to verify the system works
5. **Monitor performance** - auto-difficulty should improve task completion

## 🆘 Troubleshooting

### **Q: My containers show thread warnings**
**A:** This is normal. v0.10.11 ignores thread settings and handles threading automatically.

### **Q: Should I remove thread configuration?**
**A:** Not required. The system safely ignores deprecated settings.

### **Q: Which difficulty should I choose?**
**A:** Use AUTO (recommended) for best performance. Only override for specific testing needs.

### **Q: Will this affect my existing nodes?**
**A:** Existing containers continue working. New containers use v0.10.11 features automatically.

---

## ⏰ Quick Action Items

- [ ] Update to v0.10.11 (automatic when rebuilding)
- [ ] Set difficulty to AUTO (recommended)  
- [ ] Ignore thread deprecation warnings
- [ ] Test new containers work properly
- [ ] Enjoy better automatic performance!

**Bottom Line**: Let Nexus handle the complexity. Use AUTO mode and enjoy better performance! 🚀
