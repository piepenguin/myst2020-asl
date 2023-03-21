state("Myst-Win64-Shipping")
{
	bool isLoading : 0x503C910, 0x0, 0x08, 0x28, 0x2D;
}

isLoading
{
	return current.isLoading;
}

