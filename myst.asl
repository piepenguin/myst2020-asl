// vim: ts=4 sw=4 noexpandtab filetype=cs
// Please load LiveSplit after Myst has at least loaded to the title screen,
// for the time being. This ensures that the code that needs to be patched
// has actually been loaded.

// Current UE5 version. This is unsupported, but defined so that the splitter
// falls back gracefully to not removing loads if enabled on patches newer
// than v1.8.7.
state("Myst-Win64-Shipping", "v3.0.4")
{
}

// Latest UE4 version.
state("Myst-Win64-Shipping", "v1.8.7")
{
	bool isLoading : 0x503C910, 0x0, 0x08, 0x28, 0x2D;
	bool whitePagePickedUp : 0x5023D90, 0x490, 0x1E44;
	bool whitePageHandedIn : 0x5023D90, 0x490, 0x2d44;
}

startup {
	settings.Add("settings_skipIntro", true, "Skip the intro cutscene in the Star Fissure");
	settings.Add("settings_startOnMove", true, "Start timer on first move or teleport from the dock");
	settings.Add("settings_splitWhitePagePickup", false, "Split when picking up the White Page");
	settings.Add("settings_splitWhitePageHandIn", true, "Split when giving the White Page to Atrus");
}

init
{
	const int chunkSize = 64 * 1024; // In object entries
	const int entrySize = 0x18; // In bytes

	vars.posWatchers = null;

	vars.atSpawnCurrent = false;
	vars.atSpawnPrev = false;
	vars.justMovedFromSpawn = false;
	vars.isSupportedVersion = false;

	if (modules.First().ModuleMemorySize == 92225536) {
		version = "v1.8.7";
		vars.isSupportedVersion = true;
	}

	if (!vars.isSupportedVersion) {
		return;
	}

	var chunkHolder = modules.First().BaseAddress + 0x512E9F0;
	var numEntries = memory.ReadValue<Int32>(chunkHolder + 0x14);
	var numChunks = memory.ReadValue<Int32>(chunkHolder + 0x1C);
	var chunks = memory.ReadValue<IntPtr>(chunkHolder);

	//===
	// Apply patch to skip the intro
	//===

	var needIntroSkip = settings.ContainsKey("settings_skipIntro") && settings["settings_skipIntro"];
	bool patchedMenu = false;
	bool patchedIntro = false;

	for (int chunkIdx = 0, entryIdx = 0; chunkIdx < numChunks; ++chunkIdx) {
		bool doneWithIntroSkip = !needIntroSkip || (patchedMenu && patchedIntro);
		if (doneWithIntroSkip) break;

		var chunk = memory.ReadValue<IntPtr>(chunks + 0x08 * chunkIdx);
		for (int i = 0; entryIdx < numEntries; ++i, ++entryIdx) {
			var UObjectPtr = memory.ReadValue<IntPtr>(chunk + entrySize * i);
			// Check if the UObject is a UFunction, probably
			var UClassPtr = memory.ReadValue<IntPtr>(UObjectPtr + 0x10);
			var typeFlags = memory.ReadValue<Int64>(UClassPtr + 0xD0);
			if ((typeFlags & 0x80009) == 0) continue;

			var bytecodePtr = memory.ReadValue<IntPtr>(UObjectPtr + 0x60);
			if (bytecodePtr == IntPtr.Zero) continue;
			var bytecodeSize = memory.ReadValue<Int32>(UObjectPtr + 0x68);

			// Check for menu bytecode
			if (!patchedMenu && bytecodeSize == 12398)
			{
				var b = memory.ReadBytes(bytecodePtr, 17);
				if (b[0x00] == 0x4C &&
				    b[0x01] == 0x6B &&
				    b[0x02] == 0x30 &&
				    b[0x03] == 0x00 &&
				    b[0x04] == 0x00 &&
				    b[0x05] == 0x4E &&
				    b[0x06] == 0x00 &&
				    b[0x0F] == 0x5F &&
				    b[0x10] == 0x00)
				{
					// Replace the local variable storing "SF"
					game.WriteBytes(bytecodePtr + 892, new byte[]{
						0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B,
						0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B,
						0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B,
						0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B,
						0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B,
						0x0B, 0x0B, 0x0B,
					});
					// Inline the string "MYI" into the function call params
					game.WriteBytes(bytecodePtr + 948, new byte[]{
						0x1F, 0x4D, 0x59, 0x49, 0x00, 0x28, 0x16,
						0x0B, 0x0B, 0x0B, 0x0B,
					});

					patchedMenu = true;
					print("Myst: Patched menu");
					continue;
				}
			}

			// Check for intro bytecode
			if (!patchedIntro && bytecodeSize == 0xD9)
			{
				var b = memory.ReadBytes(bytecodePtr, 0xD9);

				if (b[0x00] == 0x5F &&
				    b[0x01] == 0x00 &&
				    b[0x0A] == 0x68 &&
				    b[0x13] == 0x17 &&
				    b[0x14] == 0x1D &&
				    b[0x15] == 0x00 &&
				    b[0x16] == 0x00 &&
				    b[0x17] == 0x00 &&
				    b[0x18] == 0x00 &&
				    b[0x19] == 0x16 &&
				    b[0x3F] == 0x5F &&
				    b[0xD6] == 0x04 &&
				    b[0xD7] == 0x0B &&
				    b[0xD8] == 0x53)
				{
					// Don't fully disable input in the intro so that the player
					// gets control as usual when starting a new game from the
					// title screen.
					game.WriteBytes(bytecodePtr + 61, new byte[]{ 0x28 });

					patchedIntro = true;
					print("Myst: Patched intro");
					continue;
				}
			}
		}
	}

	//===
	// Find player location information
	//===

	var targetVTable = modules.First().BaseAddress + 0x3F4B000;
	var needAutoSplitter = true;
	bool foundPlayer = false;
	vars.x = null;
	vars.y = null;
	vars.z = null;
	vars.posWatchers = null;

	for (int chunkIdx = 0, entryIdx = 0; chunkIdx < numChunks; ++chunkIdx) {
		bool doneWithAutoSplitter = !needAutoSplitter || foundPlayer;
		if (doneWithAutoSplitter) break;

		var chunk = memory.ReadValue<IntPtr>(chunks + 0x08 * chunkIdx);
		for (int i = 0; entryIdx < numEntries; ++i, ++entryIdx) {
			var UObjectPtr = memory.ReadValue<IntPtr>(chunk + entrySize * i);
			var vTable = memory.ReadValue<IntPtr>(UObjectPtr);
			if (vTable != targetVTable) continue;
			var flags = memory.ReadValue<Int32>(UObjectPtr + 0x08);
			if (flags != 0x48) continue;
			vars.x = new MemoryWatcher<float>(new DeepPointer(UObjectPtr + 0x5B8, 0x00, 0x320, 0x270));
			vars.y = new MemoryWatcher<float>(new DeepPointer(UObjectPtr + 0x5B8, 0x00, 0x320, 0x274));
			vars.z = new MemoryWatcher<float>(new DeepPointer(UObjectPtr + 0x5B8, 0x00, 0x320, 0x278));
			foundPlayer = true;
			break;
		}
	}


	if (vars.x != null) {
		vars.posWatchers = new MemoryWatcherList() {
			vars.x,
			vars.y,
			vars.z,
		};
	}
}


update {
	if (vars.posWatchers != null) {
		vars.posWatchers.UpdateAll(game);
		//print(vars.x.Current.ToString());

		var x = vars.x.Current;
		var y = vars.y.Current;
		var z = vars.z.Current;

		// This doesn't match what the console says because the player dips
		// slightly when they first get control.
		var spawnX = -511.12146f;
		var spawnY = 1730.0f;
		var spawnZ = 193.7677765f;
		const float eps = 1e-2f;
		vars.atSpawnCurrent = (spawnX - eps < x && x < spawnX + eps)
		    && (spawnY - eps < y && y < spawnY + eps)
		    && (spawnZ - eps < z && z < spawnZ + eps);
		vars.justMovedFromSpawn = vars.atSpawnPrev && !vars.atSpawnCurrent;
		vars.atSpawnPrev = vars.atSpawnCurrent;
	}
}

start {
	return settings.ContainsKey("settings_startOnMove")
	    && settings["settings_startOnMove"]
	    && vars.justMovedFromSpawn;
}

split {
	if (!vars.isSupportedVersion) {
		return false;
	}

	if (settings.ContainsKey("settings_splitWhitePagePickup")
	    && settings["settings_splitWhitePagePickup"]
	    && current.whitePagePickedUp
	    && !old.whitePagePickedUp) {
		return true;
	}

	if (settings.ContainsKey("settings_splitWhitePageHandIn")
	    && settings["settings_splitWhitePageHandIn"]
	    && current.whitePageHandedIn
	    && !old.whitePageHandedIn) {
		return true;
	}

	return false;
}

isLoading
{
	return vars.isSupportedVersion && current.isLoading;
}

