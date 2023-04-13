state("Myst-Win64-Shipping")
{
	bool isLoading : 0x503C910, 0x0, 0x08, 0x28, 0x2D;
}

startup {
	vars.scanTarget = new SigScanTarget(0,
		"4C 6B 30 00 00 4E 00 ?? ?? ?? ?? ?? ?? 00 00 5F 00"
	);

	settings.Add("settings_skipIntro", true, "Skip the intro cutscene in the Star Fissure");
}

init
{
	vars.threadScan = new Thread(() => {
		// Not sure how to tell when the BP has loaded, current
		// 'solution' is to load Myst up to at least the title screen
		// before opening LiveSplit.
		//Thread.Sleep(8000);

		// Can't early return because a return statement in a statement
		// lambda doesn't seem to be allowed?
		if (settings.ContainsKey("settings_skipIntro") && settings["settings_skipIntro"]) {
			var basePtr = IntPtr.Zero;
			foreach (var page in game.MemoryPages(true)) {
				var scanner = new SignatureScanner(game, page.BaseAddress, (int)page.RegionSize);
				basePtr = scanner.Scan(vars.scanTarget);
				if (basePtr != IntPtr.Zero) break;
			}
			if (basePtr == IntPtr.Zero) {
				print("Could not find bytecode");
			} else {
				// Replace the local variable storing "SF"
				game.WriteBytes(basePtr + 892, new byte[]{
					0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B,
					0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B,
					0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B,
					0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B,
					0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B,
					0x0B, 0x0B, 0x0B,
				});
				// Inline the string "MYI" into the function call params
				game.WriteBytes(basePtr + 948, new byte[]{
					0x1F, 0x4D, 0x59, 0x49, 0x00, 0x28, 0x16,
					0x0B, 0x0B, 0x0B, 0x0B,
				});
				print("Patched bytecode to remove intro");
			}
		}
	});
	vars.threadScan.Start();
}


isLoading
{
	return current.isLoading;
}

