state("Myst-Win64-Shipping")
{
	bool isLoading : 0x503C910, 0x0, 0x08, 0x28, 0x2D;
}

startup {
	vars.menuTarget = new SigScanTarget(0,
		"4C 6B 30 00 00 4E 00 ?? ?? ?? ?? ?? ?? 00 00 5F 00"
	);

	// Have to scan for basically the entire function to guarantee that its
	// correct...
	vars.introSeqTarget = new SigScanTarget(0,
		"5F 00 ?? ?? ?? ?? ?? ?? ?? ?? 68 ?? ?? ?? ?? ?? ?? ?? ?? 17 1D 00 00 00 00 16",
		"19 00 ?? ?? ?? ?? ?? ?? ?? ?? 0F 00 00 00 ?? ?? ?? ?? ?? ?? ?? ?? 1B ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? 27 16",
		"5F 00 ?? ?? ?? ?? ?? ?? ?? ?? 68 ?? ?? ?? ?? ?? ?? ?? ?? 17 1D 00 00 00 00 16",
		"19 19 00 ?? ?? ?? ?? ?? ?? ?? ?? 09 00 00 00 ?? ?? ?? ?? ?? ?? ?? ?? 01 ?? ?? ?? ?? ?? ?? ?? ??",
		/*  */"12 00 00 00 ?? ?? ?? ?? ?? ?? ?? ?? 1B ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? 24 05 24 00 16",
		"5F 00 ?? ?? ?? ?? ?? ?? ?? ?? 68 ?? ?? ?? ?? ?? ?? ?? ?? 17 1D 00 00 00 00 16",
		"19 00 ?? ?? ?? ?? ?? ?? ?? ?? 0F 00 00 00 ?? ?? ?? ?? ?? ?? ?? ?? 1B ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? 28 16",
		"04"
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
			var menuPtr = IntPtr.Zero;
			var introPtr = IntPtr.Zero;
			foreach (var page in game.MemoryPages(true)) {
				// The bytecode being scanned for is located at
				// the start of an array, so its address will be
				// 8-byte aligned. Specifying the alignment is,
				// unsurprisingly, about 8 times faster.
				if (menuPtr == IntPtr.Zero) {
					var scanner = new SignatureScanner(game, page.BaseAddress, (int)page.RegionSize);
					menuPtr = scanner.Scan(vars.menuTarget, 8);
				}
				if (introPtr == IntPtr.Zero) {
					var scanner = new SignatureScanner(game, page.BaseAddress, (int)page.RegionSize);
					introPtr = scanner.Scan(vars.introSeqTarget, 8);
				}
				if (menuPtr != IntPtr.Zero && introPtr != IntPtr.Zero) break;
			}
			if (menuPtr == IntPtr.Zero || introPtr == IntPtr.Zero) {
				print("Could not find bytecode");
			} else {
				// Replace the local variable storing "SF"
				game.WriteBytes(menuPtr + 892, new byte[]{
					0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B,
					0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B,
					0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B,
					0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B,
					0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B,
					0x0B, 0x0B, 0x0B,
				});
				// Inline the string "MYI" into the function call params
				game.WriteBytes(menuPtr + 948, new byte[]{
					0x1F, 0x4D, 0x59, 0x49, 0x00, 0x28, 0x16,
					0x0B, 0x0B, 0x0B, 0x0B,
				});
				// Don't fully disable input in the intro so that the player
				// gets control as usual when starting a new game from the
				// title screen.
				game.WriteBytes(introPtr + 61, new byte[]{ 0x28 });

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

