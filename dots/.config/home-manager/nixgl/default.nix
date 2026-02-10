{ ... }:
{
  # Enable generic Linux optimizations
  targets.genericLinux = {
    enable = true;
    gpu.enable = true;
    gpu.nvidia = {
      enable = true;
      version = "590.44.01";
      sha256 = "sha256-VbkVaKwElaazojfxkHnz/nN/5olk13ezkw/EQjhKPms=";
    };
    nixGL.vulkan.enable = true;
  };

}
