# box luas for mvm botting
---

## Features
- Comprehensive command library for bot management.
- Dynamic file path handling for compatibility with various environments.
- Supports Sandboxie+ and other virtualization methods (untested on alternatives).

---

## Installation Guide

Follow these steps to set up the system:

### Prerequisites
1. Install the required libraries and scripts:
   - [**lnxLib.lua**](https://github.com/lnx00/Lmaobox-Library)
   - [**sniperbuybot.lua**](lua/mboxsetup/sniperbuybot.lua)
   - [**multiboxhelper.lua**](lua/mboxsetup/multiboxhelper.lua)
   - [**vaccibucks.lua**](lua/mboxsetup/vaccibucks.lua)

  **Ensure you've kept the file names the same!**
  Changed file names will create issues during load, or cause other unexpected errors.
  
  These are typically installed to the `%localappdata%` directory.

### Setup
2. **Create an `autoload.lua` file** in the same directory as your scripts:
   - If you're using Sandboxie+, you can use the following repository as a reference:
     [**autoload.lua**](lua/mboxsetup/autoload.lua)
   - Preloading allows `os.getenv('localappdata')` to find the appropriate directory locations for the multibox script.

3. **Compatibility**:
   - This setup is designed to work with Sandboxie+.
   - It may also work with other virtualization methods, though this has not been tested.

### Usage
4. **Issuing Commands**:
   - Use **party chat** to send commands to bots.
   - Commands must be addressed to specific bot IDs (or `*` for all bots). See the [Commands Documentation](https://github.com/KyleIsDork/box-luas/wiki/Command-directory) for details.
