{ system, ... }:
{
  imports = [
    # Import platform-specific configuration
    (if system == "aarch64-darwin" then ./darwin else ./linux)
  ];
}
