# 🎮 Battlefield 2 v1.5 Mod Tool

Welcome to the **Battlefield 2 v1.5 Mod Tool**! This is a simple, all-in-one PowerShell script designed to effortlessly modify your BF2 server and singleplayer experience. Whether you want unlimited ammo or massive bot battles, this tool has you covered.

---

## ✨ Features

1. 🔫 **Unlimited Ammo - Handheld Weapons**
   Never run out of bullets again! Automatically updates all infantry weapons to have **999 ammo** in their magazines.

2. 🚁 **Unlimited Ammo - Vehicles**
   Unleash chaos from above or on the ground. Choose between **Air** or **Land** vehicles and equip them with **999 ammo**.

3. 🤖 **Epic Bot Battles (Max Bots)**
   Tired of small skirmishes? Easily change the maximum number of bots in your singleplayer or co-op games. Supports up to **255 bots**!

4. 🚀 **Rapid-Fire AGM (Air-to-Ground Missiles)**
   Turns your aircraft into a destructive powerhouse. Sets the AGM fire rate to **9999 RPM** for dual-seat jets and helicopters (e.g., F-15, Su-34, Havoc).

5. 🛡️ **Built-in Auto Backup**
   Safety first! The tool automatically offers to back up your `Objects_server.zip` and `AIDefault.ai` files before making any changes. If anything goes wrong, you can easily restore your original files.

---

## 🛠️ How to Use

### Prerequisites
- Make sure you are running **Windows**.
- The script requires **PowerShell**, which is built into modern Windows systems.
- Ensure the script is placed inside your main **Battlefield 2 installation folder** (the same folder where `BF2.exe` is located).

### Step-by-Step Instructions

1. **Locate the Tool**  
   Open your Battlefield 2 main folder. You should see `BF2v1.5_Mod_Tool.ps1`.

2. **Run the Script**  
   Right-click on `BF2v1.5_Mod_Tool.ps1` and select **"Run with PowerShell"**.

3. **Backup Prompt**  
   Upon starting, the tool will ask if you want to create a backup of your `Objects_server.zip`.  
   *Highly Recommended:* Press **Y** and hit Enter.

4. **Select a Feature**  
   You will see an easy-to-use menu:
   ```text
   ===== BF2 MOD TOOL =====
   1. Unlimited Ammo - Handheld weapons
   2. Unlimited Ammo - Vehicles (Air/Land)
   3. Set Max Bots (edit AIDefault.ai)
   4. Set AGM Fire Rate to 9999 (Jet/Heli dual-seat)
   0. Exit
   ```
   Simply type the number of the mod you want to install and press **Enter**. Follow any on-screen prompts (like choosing Air or Land vehicles, or typing the number of bots).

5. **Enjoy!**  
   Once the tool finishes processing, close the window, launch Battlefield 2, and enjoy your customized experience!

---

## 🔧 Troubleshooting

- **Error: "Objects_server.zip tidak ditemukan" (File not found)**  
  *Fix:* Make sure `BF2v1.5_Mod_Tool.ps1` is located in the main Battlefield 2 directory, *not* inside the `mods` folder or on your desktop.
  
- **Error: PowerShell closes immediately / Cannot run scripts**  
  *Fix:* Windows might be blocking scripts for security. Open PowerShell as Administrator, type `Set-ExecutionPolicy RemoteSigned`, press Enter, and confirm with `Y`.

- **How do I undo the mods?**  
  The tool creates backups in the `mods/bf2/backup` folder (for the ZIP) and next to `AIDefault.ai`. Just rename or move those backup files to restore the original state.

---

*Made with ❤️ for the Battlefield 2 community.*
