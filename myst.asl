// vim: ts=4 sw=4 noexpandtab filetype=cs
// Please load LiveSplit after Myst has at least loaded to the title screen,
// for the time being. This ensures that the code that needs to be patched
// has actually been loaded.

state("Myst-Win64-Shipping")
{
	bool isLoading : 0x503C910, 0x0, 0x08, 0x28, 0x2D;
}

startup {
	settings.Add("settings_skipIntro", true, "Skip the intro cutscene in the Star Fissure");
}

init
{
	if (settings.ContainsKey("settings_skipIntro") && settings["settings_skipIntro"]) {
		const int chunkSize = 64 * 1024; // In object entries
		const int entrySize = 0x18; // In bytes

		var chunkHolder = modules.First().BaseAddress + 0x512E9F0;
		var numEntries = memory.ReadValue<Int32>(chunkHolder + 0x14);
		var numChunks = memory.ReadValue<Int32>(chunkHolder + 0x1C);
		var chunks = memory.ReadValue<IntPtr>(chunkHolder);

		var bound = numEntries < chunkSize ? numEntries : chunkSize;

		bool patchedMenu = false;
		bool patchedIntro = false;

		for (int chunkIdx = 0, entryIdx = 0; chunkIdx < numChunks; ++chunkIdx) {
			if (patchedMenu && patchedIntro) break;
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
	}
}


isLoading
{
	return current.isLoading;
}

